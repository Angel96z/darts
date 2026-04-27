/// File: match_stats.dart
/// Statistiche aggregate del match per il database

import 'package:cloud_firestore/cloud_firestore.dart';

class MatchStats {
  final String id;
  final String matchId;
  final String winnerId;
  final String winnerName;
  final List<String> playerIds;
  final List<String> playerNames;
  final Map<String, int> finalScores;
  final Map<String, int> legsWon;
  final Map<String, int> setsWon;
  final DateTime startTime;
  final DateTime endTime;
  final int totalTurns;
  final int totalDarts;
  final Map<String, dynamic> gameConfig;
  final Map<String, dynamic> matchConfig;
  final int teamSize;
  final Map<String, String>? playerToTeam;

  const MatchStats({
    required this.id,
    required this.matchId,
    required this.winnerId,
    required this.winnerName,
    required this.playerIds,
    required this.playerNames,
    required this.finalScores,
    required this.legsWon,
    required this.setsWon,
    required this.startTime,
    required this.endTime,
    required this.totalTurns,
    required this.totalDarts,
    required this.gameConfig,
    required this.matchConfig,
    required this.teamSize,
    this.playerToTeam,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'playerIds': playerIds,
      'playerNames': playerNames,
      'finalScores': finalScores,
      'legsWon': legsWon,
      'setsWon': setsWon,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalTurns': totalTurns,
      'totalDarts': totalDarts,
      'gameConfig': gameConfig,
      'matchConfig': matchConfig,
      'teamSize': teamSize,
      'playerToTeam': playerToTeam,
      'status': 'complete',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory MatchStats.fromFirestore(String id, Map<String, dynamic> data) {
    return MatchStats(
      id: id,
      matchId: data['matchId'] ?? '',
      winnerId: data['winnerId'] ?? '',
      winnerName: data['winnerName'] ?? '',
      playerIds: List<String>.from(data['playerIds'] ?? []),
      playerNames: List<String>.from(data['playerNames'] ?? []),
      finalScores: Map<String, int>.from(data['finalScores'] ?? {}),
      legsWon: Map<String, int>.from(data['legsWon'] ?? {}),
      setsWon: Map<String, int>.from(data['setsWon'] ?? {}),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      totalTurns: data['totalTurns'] ?? 0,
      totalDarts: data['totalDarts'] ?? 0,
      gameConfig: Map<String, dynamic>.from(data['gameConfig'] ?? {}),
      matchConfig: Map<String, dynamic>.from(data['matchConfig'] ?? {}),
      teamSize: data['teamSize'] ?? 0,
      playerToTeam: data['playerToTeam'] != null
          ? Map<String, String>.from(data['playerToTeam'])
          : null,
    );
  }
}

class PlayerMatchStats {
  final String playerId;
  final String playerName;
  final int finalScore;
  final int totalTurns;
  final int totalDarts;
  final int totalScore;
  final double average;
  final int bestTurn;
  final int checkouts;
  final double checkoutPercentage;
  final int legsWon;
  final int setsWon;

  const PlayerMatchStats({
    required this.playerId,
    required this.playerName,
    required this.finalScore,
    required this.totalTurns,
    required this.totalDarts,
    required this.totalScore,
    required this.average,
    required this.bestTurn,
    required this.checkouts,
    required this.checkoutPercentage,
    required this.legsWon,
    required this.setsWon,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'finalScore': finalScore,
      'totalTurns': totalTurns,
      'totalDarts': totalDarts,
      'totalScore': totalScore,
      'average': average,
      'bestTurn': bestTurn,
      'checkouts': checkouts,
      'checkoutPercentage': checkoutPercentage,
      'legsWon': legsWon,
      'setsWon': setsWon,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}