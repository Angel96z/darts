/// File: local_match_record.dart
/// Modello per salvare i match in locale (cache) prima della sincronizzazione

import 'dart:ui';
import '../../../room_v4/domain/models/player_turn.dart';
import 'match_stats.dart';

enum LocalMatchSyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

class LocalMatchRecord {
  final String localId;
  final String? remoteId;
  final String mode;           // 'x01' o 'cricket'
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
  final LocalMatchSyncStatus syncStatus;
  final int retryCount;
  final DateTime? lastSyncAttempt;
  final List<Map<String, dynamic>> matchSets;

  /// Per ogni giocatore (SOLO Firebase ID), lista dei suoi turni (con dardi)
  final Map<String, List<PlayerTurn>> playerTurns;

  const LocalMatchRecord({
    required this.localId,
    required this.remoteId,
    required this.mode,
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
    required this.playerToTeam,
    required this.playerTurns,
    required this.syncStatus,
    this.retryCount = 0,
    this.lastSyncAttempt,
    required this.matchSets,

  });

  Map<String, dynamic> toMap() {
    // Serializza playerTurns in Map
    final turnsMap = <String, dynamic>{};
    for (final entry in playerTurns.entries) {
      turnsMap[entry.key] = entry.value.map((t) => t.toMap()).toList();
    }

    return {
      'localId': localId,
      'remoteId': remoteId,
      'mode': mode,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'playerIds': playerIds,
      'playerNames': playerNames,
      'finalScores': finalScores,
      'legsWon': legsWon,
      'setsWon': setsWon,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'totalTurns': totalTurns,
      'totalDarts': totalDarts,
      'gameConfig': gameConfig,
      'matchConfig': matchConfig,
      'teamSize': teamSize,
      'playerToTeam': playerToTeam,
      'playerTurns': turnsMap,
      'syncStatus': syncStatus.name,
      'retryCount': retryCount,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
      'matchSets': matchSets,

    };
  }

  factory LocalMatchRecord.fromMap(Map<String, dynamic> map) {
    // Deserializza playerTurns
    final turnsMap = <String, List<PlayerTurn>>{};
    final rawTurns = map['playerTurns'] as Map<String, dynamic>? ?? {};
    for (final entry in rawTurns.entries) {
      final turns = (entry.value as List)
          .map((t) => PlayerTurn.fromMap(t as Map<String, dynamic>))
          .toList();
      turnsMap[entry.key] = turns;
    }

    return LocalMatchRecord(
      localId: map['localId'],
      remoteId: map['remoteId'],
      mode: map['mode'],
      winnerId: map['winnerId'],
      winnerName: map['winnerName'],
      playerIds: List<String>.from(map['playerIds']),
      playerNames: List<String>.from(map['playerNames']),
      finalScores: Map<String, int>.from(map['finalScores']),
      legsWon: Map<String, int>.from(map['legsWon']),
      setsWon: Map<String, int>.from(map['setsWon']),
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      totalTurns: map['totalTurns'],
      totalDarts: map['totalDarts'],
      gameConfig: Map<String, dynamic>.from(map['gameConfig']),
      matchConfig: Map<String, dynamic>.from(map['matchConfig']),
      teamSize: map['teamSize'],
      playerToTeam: map['playerToTeam'] != null
          ? Map<String, String>.from(map['playerToTeam'])
          : null,
      playerTurns: turnsMap,
      syncStatus: LocalMatchSyncStatus.values.firstWhere(
            (e) => e.name == map['syncStatus'],
        orElse: () => LocalMatchSyncStatus.pending,
      ),
      retryCount: map['retryCount'] ?? 0,
      lastSyncAttempt: map['lastSyncAttempt'] != null
          ? DateTime.parse(map['lastSyncAttempt'])
          : null,
      matchSets: List<Map<String, dynamic>>.from(map['matchSets'] ?? []),

    );
  }

  LocalMatchRecord copyWith({
    String? remoteId,
    LocalMatchSyncStatus? syncStatus,
    int? retryCount,
    DateTime? lastSyncAttempt,
    Map<String, List<PlayerTurn>>? playerTurns,
    List<Map<String, dynamic>>? matchSets,

  }) {
    return LocalMatchRecord(
      localId: localId,
      remoteId: remoteId ?? this.remoteId,
      mode: mode,
      winnerId: winnerId,
      winnerName: winnerName,
      playerIds: playerIds,
      playerNames: playerNames,
      finalScores: finalScores,
      legsWon: legsWon,
      setsWon: setsWon,
      startTime: startTime,
      endTime: endTime,
      totalTurns: totalTurns,
      totalDarts: totalDarts,
      gameConfig: gameConfig,
      matchConfig: matchConfig,
      teamSize: teamSize,
      playerToTeam: playerToTeam,
      playerTurns: playerTurns ?? this.playerTurns,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      matchSets: matchSets ?? this.matchSets,

    );
  }
}

class LocalMatchSaveResult {
  final String localId;
  final LocalMatchSyncStatus status;

  const LocalMatchSaveResult({
    required this.localId,
    required this.status,
  });
}