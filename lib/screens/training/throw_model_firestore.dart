import 'package:cloud_firestore/cloud_firestore.dart';

import '../../logic/dart_throw_logic.dart';

class ThrowFirestoreModel {
  static Map<String, dynamic> toMap(
      DartThrow t,
      String trainingId, {
        String? trainingTarget,
      }) {
    return {
      "trainingId": trainingId,
      "trainingTarget": trainingTarget,
      "timestamp": Timestamp.fromDate(t.timestamp),
      "sector": t.sector,
      "score": t.score,
      "distanceMm": t.distanceMm,
      "quadrant": t.targetQuadrant,
      "boardX": t.position.dx,
      "boardY": t.position.dy,
      "round": t.roundNumber,
      "turn": t.turnNumber,
      "dart": t.dartInTurn,
      "playerId": t.playerId,
      "playerName": t.playerName,
      "teamId": t.teamId,
      "teamName": t.teamName,
      "isPass": t.isPass,
    };
  }
}