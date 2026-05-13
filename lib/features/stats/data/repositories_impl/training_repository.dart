/// training_repository.dart - VERSIONE SEMPLIFICATA
/// Solo salvataggio, niente aggregati pre-calcolati

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../game/domain/entities/dart_models.dart';

class TrainingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _batchLimit = 400;
  static const Duration _timeout = Duration(seconds: 12);

  /// Salva training con struttura PIATTA (solo trainings + subcollection throws)
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

    // Verifica se esiste già
    final existing = await trainingRef.get().timeout(_timeout);
    if (existing.exists && existing.data()?['status'] == 'complete') {
      return trainingId;
    }

    // Calcola stats base (solo per il documento principale)
    final durationSeconds = endTime.difference(startTime).inSeconds.clamp(0, 31536000);
    final totalThrows = throwsList.length;
    final hits = throwsList.where((t) => t.sector == target).length;
    final hitPercent = totalThrows == 0 ? 0 : ((hits / totalThrows) * 100).round();

    final totalDistance = throwsList.fold<double>(0, (sum, t) => sum + t.distanceMm);
    final avgDistanceMm = totalThrows == 0 ? 0 : totalDistance / totalThrows;

    // Salva documento principale
    await trainingRef.set({
      'mode': mode,
      'target': target,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'totalThrows': totalThrows,
      'status': 'complete',
      'stats': {
        'hits': hits,
        'miss': totalThrows - hits,
        'hitPercent': hitPercent,
        'avgDistanceMm': avgDistanceMm,
      },
      'focus': focus,
      'stress': stress,
      'energia': energia,
      'fiducia': fiducia,
      'distrazioni': distrazioni,
      'commento': commento,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);

    // Salva i tiri in subcollection (UNICA COPIA)
    final throwsCollection = trainingRef.collection('throws');

    int index = 0;
    int throwIndex = 0;

    while (index < throwsList.length) {
      final batch = _db.batch();
      final chunk = throwsList.skip(index).take(_batchLimit).toList();

      for (final t in chunk) {
        final throwDoc = throwsCollection.doc('throw_$throwIndex');

        batch.set(throwDoc, {
          'timestamp': Timestamp.fromDate(t.timestamp),
          'sector': t.sector,
          'score': t.score,
          'distanceMm': t.distanceMm,
          'quadrant': t.targetQuadrant,
          'boardX': t.position.dx,
          'boardY': t.position.dy,
          'round': t.roundNumber,
          'turn': t.turnNumber,
          'dart': t.dartInTurn,
          'playerId': t.playerId,
          'playerName': t.playerName,
          'teamId': t.teamId,
          'teamName': t.teamName,
          'isPass': t.isPass,
        });

        throwIndex++;
      }

      await batch.commit().timeout(_timeout);
      index += _batchLimit;
    }

    return trainingId;
  }

  /// Verifica se un training esiste
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