/// File: local_training_sync_service.dart
/// Sincronizzazione bidirezionale COMPLETA per sessioni di training

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
    List<DartThrow>? throwsList,
  }) {
    return LocalTrainingRecord(
      localId: localId,
      remoteId: remoteId ?? this.remoteId,
      mode: mode,
      target: target,
      startTime: startTime,
      endTime: endTime,
      throwsList: throwsList ?? this.throwsList,
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
  static const String _key = 'training_queue_v2';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(hours: 1);

  static late final LocalTrainingSyncService instance;

  final TrainingRepository _repo;
  final Uuid _uuid = const Uuid();

  bool _running = false;

  static Future<void> initialize(TrainingRepository repo) async {
    instance = LocalTrainingSyncService._internal(repo);
    await instance.start();
  }

  LocalTrainingSyncService._internal(this._repo);

  // ==================== PUBLIC API ====================

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

  Future<void> start() async {
    await syncAll();
  }

  Future<void> syncAll() async {
    if (_running) return;
    if (!await _checkBackendConnection()) return;

    _running = true;
    await _pushLocalToRemote();
    await _pullRemoteToLocal();
    _running = false;
  }

  Future<LocalTrainingRecord?> getById(String id) async {
    final all = await _getAll();
    for (final r in all) {
      if (r.localId == id || r.remoteId == id) return r;
    }
    return null;
  }

  Future<List<LocalTrainingRecord>> getAllRecords() async {
    return await _getAll();
  }

  Future<void> deleteRecord(String id) async {
    final all = await _getAll();
    final index = all.indexWhere((r) => r.localId == id || r.remoteId == id);
    if (index == -1) return;

    final record = all[index];

    // Elimina dal backend se esiste remoteId
    if (record.remoteId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final db = FirebaseFirestore.instance;
        final trainingRef = db
            .collection('users')
            .doc(user.uid)
            .collection('trainings')
            .doc(record.remoteId);

        // Elimina il training
        await trainingRef.delete();

        // Elimina i throws associati
        final throwsSnapshot = await trainingRef.collection('throws').get();
        final batch = db.batch();
        for (final throwDoc in throwsSnapshot.docs) {
          batch.delete(throwDoc.reference);
        }
        await batch.commit();
      }
    }

    // Elimina dal locale
    all.removeAt(index);
    await _saveAll(all);
  }

  Future<void> deleteRecords(List<String> ids) async {
    if (ids.isEmpty) return;

    final all = await _getAll();
    final toDelete = <LocalTrainingRecord>[];
    final toKeep = <LocalTrainingRecord>[];

    for (final record in all) {
      if (ids.contains(record.localId) || ids.contains(record.remoteId)) {
        toDelete.add(record);
      } else {
        toKeep.add(record);
      }
    }

    if (toDelete.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final db = FirebaseFirestore.instance;

      for (final record in toDelete) {
        if (record.remoteId != null) {
          final trainingRef = db
              .collection('users')
              .doc(user.uid)
              .collection('trainings')
              .doc(record.remoteId);

          final throwsSnapshot = await trainingRef.collection('throws').get();
          final batch = db.batch();
          batch.delete(trainingRef);
          for (final throwDoc in throwsSnapshot.docs) {
            batch.delete(throwDoc.reference);
          }
          await batch.commit();
        }
      }
    }

    await _saveAll(toKeep);
  }
  Future<int> deleteAllRecords() async {
    final all = await _getAll();
    if (all.isEmpty) return 0;

    final ids = all.map((record) => record.localId).toList();
    await deleteRecords(ids);

    return all.length;
  }

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
            .update({
          'focus': focus,
          'stress': stress,
          'energia': energia,
          'fiducia': fiducia,
          'distrazioni': distrazioni,
          'commento': commento,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> debugPrintAllRecords() async {
    final all = await _getAll();
    debugPrint('=== RECORD LOCALI (${all.length}) ===');
    for (var i = 0; i < all.length; i++) {
      final r = all[i];
      debugPrint('[$i] ${r.localId} | ${r.mode} | ${r.target} | ${r.syncStatus} | ${r.throwsList.length} tiri');
    }
    debugPrint('===================================');
  }

  // ==================== PRIVATE METHODS ====================

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

  Future<void> _pushLocalToRemote() async {
    final all = await _getAll();

    for (int i = 0; i < all.length; i++) {
      final r = all[i];

      if (r.syncStatus == LocalTrainingSyncStatus.synced) continue;

      if (r.syncStatus == LocalTrainingSyncStatus.failed) {
        if (r.retryCount >= _maxRetries) continue;
        if (r.lastSyncAttempt != null) {
          final hoursSinceLastAttempt = DateTime.now().difference(r.lastSyncAttempt!).inHours;
          if (hoursSinceLastAttempt < 1) continue;
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
          retryCount: 0,
        );
      } catch (e) {
        debugPrint('❌ Push fallito per ${r.localId}: $e');
        all[i] = r.copyWith(
          syncStatus: LocalTrainingSyncStatus.failed,
        );
      }

      await _saveAll(all);
    }
  }

  /// 🔥 METODO CORRETTO: PULL COMPLETO CON THROWS
  Future<void> _pullRemoteToLocal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final localRecords = await _getAll();
    final existingRemoteIds = localRecords
        .where((r) => r.remoteId != null)
        .map((r) => r.remoteId!)
        .toSet();

    // Ottieni tutti i training completati dal backend
    final trainingsSnapshot = await db
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('status', isEqualTo: 'complete')
        .get();

    final newRecords = <LocalTrainingRecord>[];

    for (final trainingDoc in trainingsSnapshot.docs) {
      final remoteId = trainingDoc.id;

      // Salta se già presente in locale
      if (existingRemoteIds.contains(remoteId)) continue;

      final data = trainingDoc.data();

      // 🔥 LEGGI I THROWS DALLA SUBCOLLECTION
      final throwsSnapshot = await trainingDoc.reference
          .collection('throws')
          .orderBy('timestamp')
          .get();

      final throwsList = <DartThrow>[];

      for (final throwDoc in throwsSnapshot.docs) {
        final throwData = throwDoc.data();
        throwsList.add(DartThrow(
          position: Offset(
            _toDouble(throwData['boardX']),
            _toDouble(throwData['boardY']),
          ),
          sector: throwData['sector']?.toString() ?? 'MISS',
          score: _toInt(throwData['score']),
          timestamp: (throwData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          distanceMm: _toDouble(throwData['distanceMm']),
          targetQuadrant: throwData['quadrant']?.toString(),
          playerId: throwData['playerId']?.toString() ?? '',
          playerName: throwData['playerName']?.toString() ?? '',
          teamId: throwData['teamId']?.toString() ?? '',
          teamName: throwData['teamName']?.toString() ?? '',
          roundNumber: _toInt(throwData['round']),
          turnNumber: _toInt(throwData['turn']),
          dartInTurn: _toInt(throwData['dart']),
          isPass: throwData['isPass'] == true,
        ));
      }

      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      final record = LocalTrainingRecord(
        localId: remoteId, // Usa remoteId come localId per consistenza
        remoteId: remoteId,
        mode: data['mode']?.toString() ?? 'bull',
        target: data['target']?.toString() ?? 'T20',
        startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        throwsList: throwsList, // 🔥 ORA PIENO!
        syncStatus: LocalTrainingSyncStatus.synced,
        retryCount: 0,
        lastSyncAttempt: null,
        focus: _toNullableInt(data['focus']),
        stress: _toNullableInt(data['stress']),
        energia: _toNullableInt(data['energia']),
        fiducia: _toNullableInt(data['fiducia']),
        distrazioni: _toNullableInt(data['distrazioni']),
        commento: data['commento']?.toString(),
      );

      newRecords.add(record);
    }

    if (newRecords.isNotEmpty) {
      final all = await _getAll();
      all.addAll(newRecords);
      await _saveAll(all);
      debugPrint('✅ Pull completato: ${newRecords.length} nuove sessioni con ${newRecords.fold<int>(0, (sum, r) => sum + r.throwsList.length)} tiri');
    }
  }

  Future<List<LocalTrainingRecord>> _getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => LocalTrainingRecord.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('❌ Errore decode JSON: $e');
      return [];
    }
  }

  Future<void> _saveAll(List<LocalTrainingRecord> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_key, json);
  }
}

// ==================== HELPER FUNCTIONS ====================

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is num) return value.toInt();
  return 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  return 0.0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}