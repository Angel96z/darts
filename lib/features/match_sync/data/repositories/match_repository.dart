/// File: match_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../room_v4/domain/models/player_turn.dart';
import '../../domain/entities/local_match_record.dart';
import '../../domain/entities/match_stats.dart';
import '../../domain/repositories/match_repository_interface.dart';
import '../datasources/match_firestore_model.dart';

class MatchRepository implements MatchRepositoryInterface {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _timeout = Duration(seconds: 12);

  @override
// Nel metodo saveMatch di MatchRepository

  @override
  Future<String> saveMatch(LocalMatchRecord record) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    final uid = user.uid;
    final matchRef = _db
        .collection('users')
        .doc(uid)
        .collection('matches')
        .doc(record.remoteId ?? _db.collection('matches').doc().id);

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

    return matchRef.id;
  }


  @override
  Future<void> updateMatchStatus(String matchId, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('matches')
        .doc(matchId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(_timeout);
  }

  @override
  Future<bool> existsMatch(String matchId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('matches')
        .doc(matchId)
        .get();

    return snap.exists;
  }
}