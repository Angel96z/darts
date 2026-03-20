import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../game/domain/entities/dart_models.dart';
import '../repositories_impl/training_repository.dart';

enum LocalTrainingSyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

class LocalTrainingRecord {
  final String localId;
  final String? remoteId;
  final String mode;
  final String target;
  final DateTime startTime;
  final DateTime endTime;
  final List<DartThrow> throwsList;
  final LocalTrainingSyncStatus syncStatus;
  final int retryCount;
  final DateTime? lastSyncAttempt;

  const LocalTrainingRecord({
    required this.localId,
    required this.remoteId,
    required this.mode,
    required this.target,
    required this.startTime,
    required this.endTime,
    required this.throwsList,
    required this.syncStatus,
    this.retryCount = 0,
    this.lastSyncAttempt,
  });

  LocalTrainingRecord copyWith({
    String? remoteId,
    LocalTrainingSyncStatus? syncStatus,
    int? retryCount,
    DateTime? lastSyncAttempt,
  }) {
    return LocalTrainingRecord(
      localId: localId,
      remoteId: remoteId ?? this.remoteId,
      mode: mode,
      target: target,
      startTime: startTime,
      endTime: endTime,
      throwsList: throwsList,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'remoteId': remoteId,
      'mode': mode,
      'target': target,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'throwsList': throwsList.map((t) => {
        'dx': t.position.dx,
        'dy': t.position.dy,
        'sector': t.sector,
        'score': t.score,
        'timestamp': t.timestamp.toIso8601String(),
        'distanceMm': t.distanceMm,
        'targetQuadrant': t.targetQuadrant,
        'playerId': t.playerId,
        'playerName': t.playerName,
        'teamId': t.teamId,
        'teamName': t.teamName,
        'roundNumber': t.roundNumber,
        'turnNumber': t.turnNumber,
        'dartInTurn': t.dartInTurn,
        'isPass': t.isPass,
      }).toList(),
      'syncStatus': syncStatus.name,
      'retryCount': retryCount,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
    };
  }

  static LocalTrainingRecord fromMap(Map<String, dynamic> map) {
    return LocalTrainingRecord(
      localId: map['localId'],
      remoteId: map['remoteId'],
      mode: map['mode'],
      target: map['target'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      throwsList: (map['throwsList'] as List).map((e) {
        return DartThrow(
          position: Offset(e['dx'], e['dy']),
          sector: e['sector'],
          score: e['score'],
          timestamp: DateTime.parse(e['timestamp']),
          distanceMm: (e['distanceMm'] ?? 0).toDouble(),
          targetQuadrant: e['targetQuadrant'],
          playerId: e['playerId'] ?? '',
          playerName: e['playerName'] ?? '',
          teamId: e['teamId'] ?? '',
          teamName: e['teamName'] ?? '',
          roundNumber: e['roundNumber'] ?? 0,
          turnNumber: e['turnNumber'] ?? 0,
          dartInTurn: e['dartInTurn'] ?? 0,
          isPass: e['isPass'] == true,
        );
      }).toList(),
      syncStatus: LocalTrainingSyncStatus.values.firstWhere(
            (e) => e.name == map['syncStatus'],
        orElse: () => LocalTrainingSyncStatus.pending,
      ),
      retryCount: map['retryCount'] ?? 0,
      lastSyncAttempt: map['lastSyncAttempt'] != null
          ? DateTime.parse(map['lastSyncAttempt'])
          : null,
    );
  }
}

class LocalTrainingSyncService {
  static const _key = 'training_queue_v2';

// Singleton instance
  static late final LocalTrainingSyncService instance;

  final TrainingRepository _repo;
  final _uuid = const Uuid();

  StreamSubscription? _connSub;
  bool _running = false;

// Factory per inizializzare il singleton
  static Future<void> initialize(TrainingRepository repo) async {
    instance = LocalTrainingSyncService._internal(repo);
    await instance.start();
  }

// Costruttore privato
  LocalTrainingSyncService._internal(this._repo);
  // ✅ NUOVO: Transaction locale per salvataggio atomico
  Future<String> saveLocalTransactional({
    required String mode,
    required String target,
    required DateTime start,
    required DateTime end,
    required List<DartThrow> throwsList,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lockKey = '${_key}_lock';
    debugPrint('🔄 saveLocalTransactional: INIZIO');
    debugPrint(' mode: $mode, target: $target');
    debugPrint(' throws: ${throwsList.length}');
    debugPrint(' start: $start, end: $end');
// Acquisisci lock per evitare race conditions
    while (prefs.getBool(lockKey) == true) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await prefs.setBool(lockKey, true);

    try {

      final record = LocalTrainingRecord(
        localId: 'local_${_uuid.v4()}',
        remoteId: null,
        mode: mode,
        target: target,
        startTime: start,
        endTime: end,
        throwsList: List.from(throwsList),
        syncStatus: LocalTrainingSyncStatus.pending,
        retryCount: 0,
        lastSyncAttempt: null,
      );

      final all = await _getAll();
      debugPrint('📋 Record prima: ${all.length}');

      all.add(record);
      await _saveAll(all);

      debugPrint('📋 Record dopo: ${all.length + 1}');
      debugPrint('✅ SALVATO IN LOCALE: ${record.localId}');

// Verifica immediata
      final verify = await _getAll();
      debugPrint('🔍 Verifica: trovati ${verify.length} record');
      final saved = verify.any((r) => r.localId == record.localId);
      debugPrint('🔍 Record salvato verificato: $saved');

      return record.localId;
    } finally {
// Rilascia il lock
      await prefs.setBool(lockKey, false);
    }
  }

// ✅ NUOVO: Marca record per sync ritardato
  Future<void> markPendingSync(String localId) async {
    final all = await _getAll();
    final index = all.indexWhere((r) => r.localId == localId);
    if (index == -1) return;

    all[index] = all[index].copyWith(
      syncStatus: LocalTrainingSyncStatus.pending,
      lastSyncAttempt: null,
    );
    await _saveAll(all);
  }

// ✅ NUOVO: Sync con retry
// ✅ Sync con retry e verifica connettività
  Future<void> syncAllWithRetry({int maxRetries = 3}) async {
// Verifica se siamo online prima di iniziare
    final connectivity = Connectivity();
    final status = await connectivity.checkConnectivity();

    if (status == ConnectivityResult.none) {
      debugPrint('📡 Offline rilevato - salto sync e salvo solo locale');
      return; // Esci subito senza tentativi
    }

    for (var i = 0; i < maxRetries; i++) {
      try {
        await syncAll();
        debugPrint('✅ Sync completato con successo');
        return;
      } catch (e) {
        debugPrint('❌ Tentativo ${i + 1} fallito: $e');

// Controlla se siamo ancora offline
        final currentStatus = await connectivity.checkConnectivity();
        if (currentStatus == ConnectivityResult.none) {
          debugPrint('📡 Connessione persa durante sync - interrompo');
          return; // Esci se la connessione è stata persa
        }

        if (i == maxRetries - 1) {
          debugPrint('⚠️ Sync fallito dopo $maxRetries tentativi');
          rethrow;
        }

        debugPrint('⏳ Attendo ${2 * (i + 1)} secondi...');
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
  }
  // SAVE LOCALE
  Future<String> saveLocal({
    required String mode,
    required String target,
    required DateTime start,
    required DateTime end,
    required List<DartThrow> throwsList,
  }) async {
    final record = LocalTrainingRecord(
      localId: 'local_${_uuid.v4()}',
      remoteId: null,
      mode: mode,
      target: target,
      startTime: start,
      endTime: end,
      throwsList: List.from(throwsList),
      syncStatus: LocalTrainingSyncStatus.pending,
      retryCount: 0,
      lastSyncAttempt: null,
    );
    final all = await _getAll();
    all.add(record);
    await _saveAll(all);

    return record.localId;
  }

  // START
  Future<void> start() async {
    await syncAll();

    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      if (r != ConnectivityResult.none) {
        syncAll();
      }
    });
  }

  // SYNC BIDIREZIONALE
  Future<void> syncAll() async {
    if (_running) return;
    _running = true;

    await _pushLocalToRemote();
    await _pullRemoteToLocal();

    _running = false;
  }

  // LOCALE → DB
  Future<void> _pushLocalToRemote() async {
    final all = await _getAll();

    for (int i = 0; i < all.length; i++) {
      final r = all[i];

// Salta se già sincronizzato
      if (r.syncStatus == LocalTrainingSyncStatus.synced) continue;

// Controlla retry per quelli falliti
      if (r.syncStatus == LocalTrainingSyncStatus.failed) {
        if (r.retryCount >= 3) continue; // Troppi tentativi, salta
        if (r.lastSyncAttempt != null) {
          final hoursSinceLastAttempt = DateTime.now().difference(r.lastSyncAttempt!).inHours;
          if (hoursSinceLastAttempt < 1) continue; // Aspetta almeno 1 ora tra retry
        }
      }

      all[i] = r.copyWith(
        syncStatus: LocalTrainingSyncStatus.syncing,
        retryCount: r.retryCount + 1,
        lastSyncAttempt: DateTime.now(),
      );
      await _saveAll(all);

      try {
        final id = await _repo.saveTraining(
          mode: r.mode,
          target: r.target,
          startTime: r.startTime,
          endTime: r.endTime,
          throwsList: r.throwsList,
          trainingIdOverride: r.localId,
        );

        all[i] = r.copyWith(
          remoteId: id,
          syncStatus: LocalTrainingSyncStatus.synced,
          retryCount: 0, // Reset retry count on success
        );
      } catch (e) {
        all[i] = r.copyWith(
          syncStatus: LocalTrainingSyncStatus.failed,
// retryCount già incrementato sopra
        );
      }

      await _saveAll(all);
    }
  }

  // DB → LOCALE
  Future<void> _pullRemoteToLocal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;

    final snap = await db
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .get();

    final local = await _getAll();

    for (final doc in snap.docs) {
      final exists = local.any((e) => e.remoteId == doc.id);
      if (exists) continue;

      final data = doc.data();
// ignora record non completati (evita dati sporchi)
      if (data['status'] != 'complete') continue;
      final record = LocalTrainingRecord(
        localId: data['id'] ?? doc.id,
        remoteId: doc.id,
        mode: data['mode'],
        target: data['target'],
        startTime: (data['startTime'] as Timestamp).toDate(),
        endTime: (data['endTime'] as Timestamp).toDate(),
        throwsList: [], // opzionale: puoi ricostruirli
        syncStatus: LocalTrainingSyncStatus.synced,
      );

      local.add(record);
    }

    await _saveAll(local);
  }

  Future<LocalTrainingRecord?> getById(String id) async {
    final all = await _getAll();
    for (final r in all) {
      if (r.localId == id || r.remoteId == id) return r;
    }
    return null;
  }
// Ottieni tutti i record locali
  Future<List<LocalTrainingRecord>> getAllRecords() async {
    return await _getAll();
  }
  // Metodo di debug per vedere tutti i record
  Future<void> debugPrintAllRecords() async {
    final all = await _getAll();
    debugPrint('=== RECORD LOCALI (${all.length}) ===');
    for (var i = 0; i < all.length; i++) {
      final r = all[i];
      debugPrint('[$i] ${r.localId} | ${r.mode} | ${r.target} | ${r.syncStatus} | ${r.throwsList.length} tiri');
    }
    debugPrint('===================================');
  }


  Future<List<LocalTrainingRecord>> _getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];

    return (jsonDecode(raw) as List)
        .map((e) => LocalTrainingRecord.fromMap(e))
        .toList();
  }

  Future<void> _saveAll(List<LocalTrainingRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toMap()).toList()));
  }
}