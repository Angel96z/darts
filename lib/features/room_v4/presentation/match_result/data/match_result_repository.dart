// TARGET: Interfacciamento dati risultati match
// LOGIC GOAL: Calcolare statistiche e recuperare dati remoti

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/match.dart';
import '../../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../domain/models/player_info.dart';
import '../domain/match_result_state.dart';

class MatchResultRepository {
  Future<Map<String, PlayerStatistics>> calculateStatistics(
      Match match,
      List<PlayerInfo> players,
      bool isTeamMode,
      bool isCricket,
      ) async {
    final stats = <String, PlayerStatistics>{};

    for (final player in players) {
      stats[player.id] = PlayerStatistics(playerId: player.id);
    }

    for (final set in match.sets) {
      for (final leg in set.legs) {
        final legWinnerId = leg.winnerId;
        if (legWinnerId != null && stats.containsKey(legWinnerId)) {
          final current = stats[legWinnerId]!;
          stats[legWinnerId] = current.copyWith(legsWon: current.legsWon + 1);
        }

        for (final round in leg.rounds) {
          for (final turn in round.turns) {
            final current = stats[turn.playerId]!;

            final turnValue = isCricket
                ? turn.totalMarks
                : turn.isBust
                ? 0
                : turn.initialScore - turn.score;

            stats[turn.playerId] = current.copyWith(
              totalTurns: current.totalTurns + 1,
              totalScore: current.totalScore + turnValue,  // ← ORA CORRETTO
              totalDarts: current.totalDarts + turn.throws.length,
              checkouts: current.checkouts + (turn.isCheckout ? 1 : 0),
              bestTurn: current.bestTurn > turnValue ? current.bestTurn : turnValue,
            );
          }
        }
      }
    }

    if (!isTeamMode) {
      for (final set in match.sets) {
        if (set.winnerId != null && stats.containsKey(set.winnerId)) {
          stats[set.winnerId!] = stats[set.winnerId!]!.copyWith(
              setsWon: stats[set.winnerId!]!.setsWon + 1
          );
        }
      }
    }

    for (final entry in stats.entries) {
      final avg = entry.value.totalDarts > 0
          ? (entry.value.totalScore / entry.value.totalDarts) * 3
          : 0.0;
      final checkoutPct = entry.value.totalTurns > 0
          ? (entry.value.checkouts / entry.value.totalTurns) * 100
          : 0.0;
      final isWinner = !isTeamMode && match.winnerId == entry.key;

      stats[entry.key] = entry.value.copyWith(
        average: avg,
        checkoutPercentage: checkoutPct,
        isWinner: isWinner,
      );
    }

    final matchRecord = await LocalMatchSyncService.instance.getById(match.id);
    for (final entry in stats.entries) {
      final player = players.firstWhere((p) => p.id == entry.key);
      if (!player.isGuest && matchRecord != null) {
        stats[entry.key] = entry.value.copyWith(syncStatus: matchRecord.syncStatus);
      }
    }

    return stats;
  }

  Future<Map<String, dynamic>?> fetchRemoteMatchStructure(
      String remoteMatchId,
      String playerId,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Prova prima in x01_matches
      var matchRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('x01_matches')
          .doc(remoteMatchId);

      var matchDoc = await matchRef.get();

      // Se non trovato, prova in cricket_matches
      if (!matchDoc.exists) {
        matchRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cricket_matches')
            .doc(remoteMatchId);
        matchDoc = await matchRef.get();
      }

      if (!matchDoc.exists) return null;


      final matchData = matchDoc.data()!;
      final matchSets = await _fetchFirestoreHierarchy(matchRef);

      return {
        'match': {
          'id': remoteMatchId,
          'localId': matchData['matchId'],
          'source': 'DATABASE REMOTO (FIRESTORE)',
          'winnerId': matchData['winnerId'],
          'winnerName': matchData['winnerName'],
          'startTime': matchData['startTime']?.toString(),
          'endTime': matchData['endTime']?.toString(),
          'sets': matchSets.map((setMap) {
            return {
              'setNumber': setMap['setNumber'],
              'winnerId': setMap['winnerId'],
              'startTime': setMap['startTime']?.toString(),
              'endTime': setMap['endTime']?.toString(),
              'legs': (setMap['legs'] as List).map((legMap) {
                return {
                  'legNumber': legMap['legNumber'],
                  'winnerId': legMap['winnerId'],
                  'winningScore': legMap['winningScore'],
                  'startTime': legMap['startTime']?.toString(),
                  'endTime': legMap['endTime']?.toString(),
                  'rounds': (legMap['rounds'] as List).map((roundMap) {
                    return {
                      'roundNumber': roundMap['roundNumber'],
                      'timestamp': roundMap['timestamp']?.toString(),
                      'turns': (roundMap['turns'] as List)
                          .where((turn) => turn['playerId'] == playerId)
                          .map((turnMap) {
                        return {
                          'playerId': turnMap['playerId'],
                          'turnNumber': turnMap['turnNumber'],
                          'throws': (turnMap['throws'] as List).map((dartMap) {
                            return {
                              'dartNumber': dartMap['dartNumber'],
                              'target': dartMap['target'],
                              'multiplier': dartMap['multiplier'],
                              'score': dartMap['score'],
                              'label': _dartToLabel(dartMap),
                              'timestamp': dartMap['timestamp']?.toString(),
                            };
                          }).toList(),
                          'total': turnMap['total'],
                          'initialScore': turnMap['initialScore'],
                          'score': turnMap['score'],
                          'isBust': turnMap['isBust'],
                          'isCheckout': turnMap['isCheckout'],
                        };
                      }).toList(),
                    };
                  }).toList(),
                };
              }).toList(),
            };
          }).toList(),
        },
      };
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFirestoreHierarchy(DocumentReference matchRef) async {
    final matchSets = <Map<String, dynamic>>[];
    final setsSnapshot = await matchRef.collection('sets').orderBy('setNumber').get();
    for (final setDoc in setsSnapshot.docs) {
      final setData = setDoc.data();
      final legs = <Map<String, dynamic>>[];
      final legsSnapshot = await setDoc.reference.collection('legs').orderBy('legNumber').get();
      for (final legDoc in legsSnapshot.docs) {
        final legData = legDoc.data();
        final rounds = <Map<String, dynamic>>[];
        final roundsSnapshot = await legDoc.reference.collection('rounds').orderBy('roundNumber').get();
        for (final roundDoc in roundsSnapshot.docs) {
          final roundData = roundDoc.data();
          final turns = <Map<String, dynamic>>[];
          final turnsSnapshot = await roundDoc.reference.collection('turns').orderBy('turnNumber').get();
          for (final turnDoc in turnsSnapshot.docs) {
            turns.add(turnDoc.data());
          }
          rounds.add({
            'roundNumber': roundData['roundNumber'],
            'timestamp': roundData['timestamp'],
            'turns': turns,
          });
        }
        legs.add({
          'legNumber': legData['legNumber'],
          'winnerId': legData['winnerId'],
          'winningScore': legData['winningScore'] ?? 0,
          'startTime': legData['startTime'],
          'endTime': legData['endTime'],
          'cricketMarks': legData['cricketMarks'] ?? {},
          'cricketPoints': legData['cricketPoints'] ?? {},
          'rounds': rounds,
        });
      }
      matchSets.add({
        'setNumber': setData['setNumber'],
        'winnerId': setData['winnerId'],
        'startTime': setData['startTime'],
        'endTime': setData['endTime'],
        'legs': legs,
      });
    }
    return matchSets;
  }

  String _dartToLabel(Map<String, dynamic> dartMap) {
    final multiplier = dartMap['multiplier'];
    final target = dartMap['target'];
    if (multiplier == 1) return target.toString();
    if (multiplier == 2) return 'D$target';
    if (multiplier == 3) return 'T$target';
    return 'Miss';
  }
}

final matchResultRepositoryProvider = Provider((ref) => MatchResultRepository());