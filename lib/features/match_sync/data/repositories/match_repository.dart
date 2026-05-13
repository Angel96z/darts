/// File: match_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../room_v4/domain/models/player_turn.dart';
import '../../../stats/domain/services/stats_aggregator_service.dart';
import '../../domain/entities/local_match_record.dart';
import '../../domain/entities/match_stats.dart';
import '../../domain/repositories/match_repository_interface.dart';
import '../datasources/match_firestore_model.dart';

class MatchRepository implements MatchRepositoryInterface {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _timeout = Duration(seconds: 12);

  @override
// Nel metodo saveMatch di MatchRepository
  Future<String> saveMatch(LocalMatchRecord record) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    final uid = user.uid;
    // Determina la collezione in base alla modalità
    final collectionName = record.mode == 'x01' ? 'x01_matches' : 'cricket_matches';
    final matchRef = _db
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(record.remoteId ?? _db.collection(collectionName).doc().id);

    // 1. Salva le info del match
    final matchInfo = {
      'matchId': record.localId,
      'mode': record.mode,
      'winnerId': record.winnerId,
      'winnerName': record.winnerName,
      'playerIds': record.playerIds,
      'playerNames': record.playerNames,
      'finalScores': record.finalScores,
      'legsWon': record.legsWon,
      'setsWon': record.setsWon,
      'startTime': Timestamp.fromDate(record.startTime),
      'endTime': Timestamp.fromDate(record.endTime),
      'totalTurns': record.totalTurns,
      'totalDarts': record.totalDarts,
      'gameConfig': record.gameConfig,
      'matchConfig': record.matchConfig,
      'teamSize': record.teamSize,
      'playerToTeam': record.playerToTeam,
      'status': 'complete',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await matchRef.set(matchInfo).timeout(_timeout);

    // 2. Salva la struttura gerarchica (solo per i turni di QUESTO giocatore)
    for (int setIdx = 0; setIdx < record.matchSets.length; setIdx++) {
      final setData = record.matchSets[setIdx];
      final setRef = matchRef.collection('sets').doc('set_${setData['setNumber']}');

      await setRef.set({
        'setNumber': setData['setNumber'],
        'winnerId': setData['winnerId'],
        'startTime': setData['startTime'],
        'endTime': setData['endTime'],
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);

      final legs = setData['legs'] as List;
      for (int legIdx = 0; legIdx < legs.length; legIdx++) {
        final legData = legs[legIdx];
        final legRef = setRef.collection('legs').doc('leg_${legData['legNumber']}');

        await legRef.set({
          'legNumber': legData['legNumber'],
          'winnerId': legData['winnerId'],
          'winningScore': legData['winningScore'],
          'startTime': legData['startTime'],
          'endTime': legData['endTime'],
          'cricketMarks': legData['cricketMarks'] ?? {},
          'cricketPoints': legData['cricketPoints'] ?? {},
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_timeout);

        final rounds = legData['rounds'] as List;
        for (int roundIdx = 0; roundIdx < rounds.length; roundIdx++) {
          final roundData = rounds[roundIdx];
          final roundRef = legRef.collection('rounds').doc('round_${roundData['roundNumber']}');

          await roundRef.set({
            'roundNumber': roundData['roundNumber'],
            'timestamp': roundData['timestamp'],
            'createdAt': FieldValue.serverTimestamp(),
          }).timeout(_timeout);

          final turns = roundData['turns'] as List;
          for (int turnIdx = 0; turnIdx < turns.length; turnIdx++) {
            final turnData = turns[turnIdx];
            final turnRef = roundRef.collection('turns').doc('turn_${turnData['turnNumber']}');

            await turnRef.set(turnData).timeout(_timeout);
          }
        }
      }
    }

    // 🔥 Aggiorna statistiche carriera DOPO il salvataggio del match
    await StatsAggregatorService.instance.updateUserStats();

    return matchRef.id;
  }

  @override
  Future<void> updateMatchStatus(String matchId, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Determina la collezione (cerchiamo in entrambe o salviamo il mode?
    // Per update usiamo lo stesso approccio - cerchiamo prima in x01_matches)
    final x01Ref = _db
        .collection('users')
        .doc(user.uid)
        .collection('x01_matches')
        .doc(matchId);

    final cricketRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('cricket_matches')
        .doc(matchId);

    final x01Doc = await x01Ref.get();
    if (x01Doc.exists) {
      await x01Ref.update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}).timeout(_timeout);
    } else {
      await cricketRef.update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}).timeout(_timeout);
    }
  }

  @override
  Future<bool> existsMatch(String matchId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final x01Snap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('x01_matches')
        .doc(matchId)
        .get();

    if (x01Snap.exists) {
      return true;
    }

    final cricketSnap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('cricket_matches')
        .doc(matchId)
        .get();

    return cricketSnap.exists;
  }
}