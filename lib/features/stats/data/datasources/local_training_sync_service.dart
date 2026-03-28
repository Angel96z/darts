/// File: local_training_sync_service.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
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

class LocalTrainingSaveResult {
  final String localId;
  final LocalTrainingSyncStatus status;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const LocalTrainingSaveResult({
    required this.localId,
    required this.status,
  });
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
  final int? focus;
  final int? stress;
  final int? energia;
  final int? fiducia;
  final int? distrazioni;
  final String? commento;

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
    this.focus,
    this.stress,
    this.energia,
    this.fiducia,
    this.distrazioni,
    this.commento,
  });

  /// Funzione: descrive in modo semplice questo blocco di logica.
  LocalTrainingRecord copyWith({
    String? remoteId,
    LocalTrainingSyncStatus? syncStatus,
    int? retryCount,
    DateTime? lastSyncAttempt,
    int? focus,
    int? stress,
    int? energia,
    int? fiducia,
    int? distrazioni,
    String? commento,
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
      focus: focus ?? this.focus,
      stress: stress ?? this.stress,
      energia: energia ?? this.energia,
      fiducia: fiducia ?? this.fiducia,
      distrazioni: distrazioni ?? this.distrazioni,
      commento: commento ?? this.commento,
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
      'focus': focus,
      'stress': stress,
      'energia': energia,
      'fiducia': fiducia,
      'distrazioni': distrazioni,
      'commento': commento,
    };
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static LocalTrainingRecord fromMap(Map<String, dynamic> map) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
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
      focus: map['focus'] as int?,
      stress: map['stress'] as int?,
      energia: map['energia'] as int?,
      fiducia: map['fiducia'] as int?,
      distrazioni: map['distrazioni'] as int?,
      commento: map['commento']?.toString(),
    );
  }
}

class LocalTrainingSyncService {
  static const _key = 'training_queue_v2';

// Singleton instance
  static late final LocalTrainingSyncService instance;

  final TrainingRepository _repo;
  final _uuid = const Uuid();

  bool _running = false;

// Factory per inizializzare il singleton
  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Future<void> initialize(TrainingRepository repo) async {
    instance = LocalTrainingSyncService._internal(repo);
    await instance.start();
  }

// Costruttore privato
  LocalTrainingSyncService._internal(this._repo);

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<LocalTrainingSaveResult> saveSession({
    required String mode,
    required String target,
    required DateTime start,
    required DateTime end,
    required List<DartThrow> throwsList,
    int? focus,
    int? stress,
    int? energia,
    int? fiducia,
    int? distrazioni,
    String? commento,
  }) async {
    final localId = await saveLocal(
      mode: mode,
      target: target,
      start: start,
      end: end,
      throwsList: throwsList,
      focus: focus,
      stress: stress,
      energia: energia,
      fiducia: fiducia,
      distrazioni: distrazioni,
      commento: commento,
    );

    if (!await _checkBackendConnection()) {
      return LocalTrainingSaveResult(
        localId: localId,
        status: LocalTrainingSyncStatus.pending,
      );
    }

    await syncAll();
    final updated = await getById(localId);

    return LocalTrainingSaveResult(
      localId: localId,
      status: updated?.syncStatus ?? LocalTrainingSyncStatus.failed,
    );
  }

  // SAVE LOCALE
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<String> saveLocal({
    required String mode,
    required String target,
    required DateTime start,
    required DateTime end,
    required List<DartThrow> throwsList,
    int? focus,
    int? stress,
    int? energia,
    int? fiducia,
    int? distrazioni,
    String? commento,
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
      focus: focus,
      stress: stress,
      energia: energia,
      fiducia: fiducia,
      distrazioni: distrazioni,
      commento: commento,
    );
    final all = await _getAll();
    all.add(record);
    await _saveAll(all);

    return record.localId;
  }

  // START
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> start() async {
    await syncAll();
  }

  // SYNC BIDIREZIONALE
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> syncAll() async {
    if (_running) return;
    if (!await _checkBackendConnection()) return;
    _running = true;

    await _pushLocalToRemote();
    await _pullRemoteToLocal();

    _running = false;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<bool> _checkBackendConnection() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  // LOCALE → DB
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
          focus: r.focus,
          stress: r.stress,
          energia: r.energia,
          fiducia: r.fiducia,
          distrazioni: r.distrazioni,
          commento: r.commento,
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
        focus: data['focus'] as int?,
        stress: data['stress'] as int?,
        energia: data['energia'] as int?,
        fiducia: data['fiducia'] as int?,
        distrazioni: data['distrazioni'] as int?,
        commento: data['commento']?.toString(),
      );

      local.add(record);
    }

    await _saveAll(local);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<LocalTrainingRecord?> getById(String id) async {
    final all = await _getAll();
    for (final r in all) {
      if (r.localId == id || r.remoteId == id) return r;
    }
    return null;
  }
// Ottieni tutti i record locali
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<List<LocalTrainingRecord>> getAllRecords() async {
    return await _getAll();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> updateSessionReview({
    required String id,
    int? focus,
    int? stress,
    int? energia,
    int? fiducia,
    int? distrazioni,
    String? commento,
  }) async {
    final all = await _getAll();
    final index = all.indexWhere((r) => r.localId == id || r.remoteId == id);
    if (index == -1) return;

    final updated = all[index].copyWith(
      focus: focus,
      stress: stress,
      energia: energia,
      fiducia: fiducia,
      distrazioni: distrazioni,
      commento: commento,
    );
    all[index] = updated;
    await _saveAll(all);

    if (updated.remoteId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('trainings')
            .doc(updated.remoteId)
            .set({
          'focus': focus,
          'stress': stress,
          'energia': energia,
          'fiducia': fiducia,
          'distrazioni': distrazioni,
          'commento': commento,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
  // Metodo di debug per vedere tutti i record
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> debugPrintAllRecords() async {
    final all = await _getAll();
    /// Funzione: descrive in modo semplice questo blocco di logica.
    debugPrint('=== RECORD LOCALI (${all.length}) ===');
    for (var i = 0; i < all.length; i++) {
      final r = all[i];
      debugPrint('[$i] ${r.localId} | ${r.mode} | ${r.target} | ${r.syncStatus} | ${r.throwsList.length} tiri');
    }
    debugPrint('===================================');
  }


  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<List<LocalTrainingRecord>> _getAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];

    return (jsonDecode(raw) as List)
        .map((e) => LocalTrainingRecord.fromMap(e))
        .toList();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _saveAll(List<LocalTrainingRecord> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((e) => e.toMap()).toList()));
  }
}
