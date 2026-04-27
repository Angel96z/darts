/// File: match_firestore_model.dart
/// Modello per il salvataggio dei turni su Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../room_v4/domain/models/dart_throw.dart';
import '../../../room_v4/domain/models/player_turn.dart';

class MatchTurnFirestoreModel {
  static Map<String, dynamic> toMap(PlayerTurn turn, String matchId, String playerId) {
    return {
      'matchId': matchId,
      'playerId': playerId,
      'turnNumber': turn.turnNumber,
      'roundNumber': turn.roundNumber,
      'legNumber': turn.legNumber,
      'throws': turn.throws.map((d) => _dartToMap(d)).toList(),
      'total': turn.total,
      'totalMarks': turn.totalMarks,
      'initialScore': turn.initialScore,
      'score': turn.score,
      'isBust': turn.isBust,
      'isCheckout': turn.isCheckout,
      'timestamp': Timestamp.fromDate(turn.timestamp),
    };
  }

  static Map<String, dynamic> _dartToMap(DartThrow dart) {
    return {
      'dartNumber': dart.dartNumber,
      'target': dart.target,
      'multiplier': dart.multiplier,
      'score': dart.score,
      'timestamp': Timestamp.fromDate(dart.timestamp),
    };
  }

  static PlayerTurn fromMap(Map<String, dynamic> map) {
    return PlayerTurn(
      playerId: map['playerId'],
      turnNumber: map['turnNumber'],
      roundNumber: map['roundNumber'] ?? 1,
      legNumber: map['legNumber'] ?? 1,
      throws: (map['throws'] as List)
          .map((d) => DartThrow(
        dartNumber: d['dartNumber'],
        target: d['target'],
        multiplier: d['multiplier'],
        score: d['score'],
        timestamp: (d['timestamp'] as Timestamp).toDate(),
      ))
          .toList(),
      total: map['total'],
      totalMarks: map['totalMarks'] ?? 0,
      initialScore: map['initialScore'],
      score: map['score'],
      isBust: map['isBust'],
      isCheckout: map['isCheckout'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}