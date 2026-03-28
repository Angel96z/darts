import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../game/domain/entities/dart_models.dart';
import '../../domain/entities/training_stats.dart';
import '../datasources/throw_model_firestore.dart';

class TrainingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _batchLimit = 400;
  static const Duration _timeout = Duration(seconds: 12);

  Future<String> saveTraining({
    required String mode,
    required String target,
    required DateTime startTime,
    required DateTime endTime,
    required List<DartThrow> throwsList,
    int? focus,
    int? stress,
    int? energia,
    int? fiducia,
    int? distrazioni,
    String? commento,
    String? trainingIdOverride,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    final uid = user.uid;
    final trainingId = trainingIdOverride ??
        _db.collection('users').doc(uid).collection('trainings').doc().id;

    final trainingRef = _db
        .collection('users')
        .doc(uid)
        .collection('trainings')
        .doc(trainingId);

    final existing = await trainingRef.get().timeout(_timeout);

    if (existing.exists) {
      final data = existing.data();
      if (data != null && data['status'] == 'complete') {
        return trainingRef.id;
      }
    }

    final stats = TrainingStats(throwsList);
    final durationSeconds = endTime.difference(startTime).inSeconds.clamp(0, 31536000);

    final trainingData = {
      'mode': mode,
      'target': target,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'totalThrows': stats.totalThrows,
      'totalTurns': stats.totalTurns,
      'status': 'saving',
      'createdAt': existing.exists ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp()) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'stats': {
        'hits': stats.targetHits(target),
        'miss': stats.targetMiss(target),
        'hitPercent': stats.totalThrows == 0
            ? 0
            : ((stats.targetHits(target) / stats.totalThrows) * 100).round(),
        'avgDistanceMm': stats.averageDistanceMm,
        'bestStreak': stats.bestStreak(target),
      },
      'focus': focus,
      'stress': stress,
      'energia': energia,
      'fiducia': fiducia,
      'distrazioni': distrazioni,
      'commento': commento,
    };

    await trainingRef.set(trainingData, SetOptions(merge: true)).timeout(_timeout);

    final throwsCollection = trainingRef.collection('throws');
    final globalThrowsCollection = _db.collection('users').doc(uid).collection('throws');

    int index = 0;
    int throwIndex = 0;

    while (index < throwsList.length) {
      final batch = _db.batch();
      final chunk = throwsList.skip(index).take(_batchLimit).toList();

      for (final t in chunk) {
        final throwDoc = throwsCollection.doc('throw_$throwIndex');
        final globalDoc = globalThrowsCollection.doc('${trainingRef.id}_$throwIndex');

        final map = ThrowFirestoreModel.toMap(
          t,
          trainingRef.id,
          trainingTarget: target,
        );

        batch.set(throwDoc, map, SetOptions(merge: true));
        batch.set(globalDoc, map, SetOptions(merge: true));
        throwIndex++;
      }

      await batch.commit().timeout(_timeout);
      index += _batchLimit;
    }

    final alreadyCounted = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(trainingRef);
      final data = snap.data() ?? {};

      if (data['aggregatesApplied'] == true) {
        return true;
      }

      // lock immediato (prima degli update)
      tx.set(trainingRef, {
        'aggregatesApplied': true,
      }, SetOptions(merge: true));

      return false;
    }).timeout(_timeout);
    if (!alreadyCounted) {
      await _updateDailyAggregate(
        uid: uid,
        date: startTime,
        throwsList: throwsList,
        target: target,
      );

      await _updateTargetSessionAggregate(
        uid: uid,
        trainingId: trainingRef.id,
        target: target,
        startTime: startTime,
        endTime: endTime,
        throwsList: throwsList,
        stats: stats,
      );

      await _updateTargetDailyAggregate(
        uid: uid,
        date: startTime,
        target: target,
        throwsList: throwsList,
      );

      await _updateTargetGlobalAggregate(
        uid: uid,
        target: target,
        throwsList: throwsList,
      );
    }

    await trainingRef.set({
      'status': 'complete',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);

    return trainingRef.id;
  }

  Future<bool> _markAggregatesApplied(DocumentReference<Map<String, dynamic>> trainingRef) async {
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(trainingRef);
      final data = snap.data() ?? {};
      final applied = data['aggregatesApplied'] == true;

      if (applied) {
        return true;
      }

      tx.set(trainingRef, {
        'aggregatesApplied': true,
      }, SetOptions(merge: true));

      return false;
    }).timeout(_timeout);
  }

  Future<void> _updateTargetSessionAggregate({
    required String uid,
    required String trainingId,
    required String target,
    required DateTime startTime,
    required DateTime endTime,
    required List<DartThrow> throwsList,
    required TrainingStats stats,
  }) async {
    final centroid = stats.centroid();
    final dispersion = stats.dispersionStats();
    final dartStats = stats.dartStats(target);

    final durationSeconds = endTime.difference(startTime).inSeconds.clamp(0, 31536000);

    final targetRef = _db
        .collection('users')
        .doc(uid)
        .collection('target_stats')
        .doc(target)
        .collection('sessions')
        .doc(trainingId);

    final hits = throwsList.where((t) => t.sector == target).length;
    final total = throwsList.length;

    await targetRef.set({
      'trainingId': trainingId,
      'target': target,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'totalThrows': total,
      'hits': hits,
      'miss': total - hits,
      'hitPercent': total == 0 ? 0 : ((hits / total) * 100).round(),
      'avgDistanceMm': stats.averageDistanceMm,
      'centroidX': centroid['x'],
      'centroidY': centroid['y'],
      'meanRadiusMm': dispersion['meanRadiusMm'],
      'stdRadiusMm': dispersion['stdRadiusMm'],
      'dart1': dartStats['dart1'],
      'dart2': dartStats['dart2'],
      'dart3': dartStats['dart3'],
      'quadrants': stats.quadrantHits(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);
  }

  Future<void> _updateTargetDailyAggregate({
    required String uid,
    required DateTime date,
    required String target,
    required List<DartThrow> throwsList,
  }) async {
    final dayKey = _dayKey(date);

    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('target_stats')
        .doc(target)
        .collection('days')
        .doc(dayKey);

    final hits = throwsList.where((t) => t.sector == target).length;
    final total = throwsList.length;
    final avgDistance = _averageDistance(throwsList);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists) {
        tx.set(ref, {
          'date': dayKey,
          'target': target,
          'sessions': 1,
          'throws': total,
          'hits': hits,
          'avgDistanceMm': avgDistance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() ?? {};
      final sessions = ((data['sessions'] ?? 0) as num).toInt() + 1;
      final newThrows = ((data['throws'] ?? 0) as num).toInt() + total;
      final newHits = ((data['hits'] ?? 0) as num).toInt() + hits;
      final prevDistance = ((data['avgDistanceMm'] ?? 0) as num).toDouble();
      final newDistance = ((prevDistance * (sessions - 1)) + avgDistance) / sessions;

      tx.update(ref, {
        'sessions': sessions,
        'throws': newThrows,
        'hits': newHits,
        'avgDistanceMm': newDistance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(_timeout);
  }

  Future<void> _updateTargetGlobalAggregate({
    required String uid,
    required String target,
    required List<DartThrow> throwsList,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('target_stats')
        .doc(target);

    final hits = throwsList.where((t) => t.sector == target).length;
    final total = throwsList.length;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists) {
        tx.set(ref, {
          'target': target,
          'totalSessions': 1,
          'totalThrows': total,
          'totalHits': hits,
          'overallHitPercent': total == 0 ? 0 : ((hits / total) * 100).round(),
          'lastTrainingAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() ?? {};
      final sessions = ((data['totalSessions'] ?? 0) as num).toInt() + 1;
      final throwsTotal = ((data['totalThrows'] ?? 0) as num).toInt() + total;
      final hitsTotal = ((data['totalHits'] ?? 0) as num).toInt() + hits;
      final percent = throwsTotal == 0 ? 0 : ((hitsTotal / throwsTotal) * 100).round();

      tx.update(ref, {
        'totalSessions': sessions,
        'totalThrows': throwsTotal,
        'totalHits': hitsTotal,
        'overallHitPercent': percent,
        'lastTrainingAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(_timeout);
  }

  Future<void> _updateDailyAggregate({
    required String uid,
    required DateTime date,
    required List<DartThrow> throwsList,
    required String target,
  }) async {
    final dayKey = _dayKey(date);

    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('aggregates')
        .doc('daily')
        .collection('days')
        .doc(dayKey);

    final hits = throwsList.where((t) => t.sector == target).length;
    final total = throwsList.length;
    final avgDistance = _averageDistance(throwsList);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists) {
        tx.set(ref, {
          'date': dayKey,
          'throws': total,
          'hits': hits,
          'avgDistanceMm': avgDistance,
          'sessions': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() ?? {};
      final newThrows = ((data['throws'] ?? 0) as num).toInt() + total;
      final newHits = ((data['hits'] ?? 0) as num).toInt() + hits;
      final sessions = ((data['sessions'] ?? 0) as num).toInt() + 1;
      final prevDistance = ((data['avgDistanceMm'] ?? 0) as num).toDouble();
      final newDistance = ((prevDistance * (sessions - 1)) + avgDistance) / sessions;

      tx.update(ref, {
        'throws': newThrows,
        'hits': newHits,
        'sessions': sessions,
        'avgDistanceMm': newDistance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).timeout(_timeout);
  }

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double _averageDistance(List<DartThrow> throwsList) {
    if (throwsList.isEmpty) return 0;
    final sum = throwsList
        .map((e) => e.distanceMm)
        .fold<double>(0, (a, b) => a + b);
    return sum / throwsList.length;
  }
  Future<bool> existsTraining(String trainingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .doc(trainingId)
        .get();

    return snap.exists;
  }
}
