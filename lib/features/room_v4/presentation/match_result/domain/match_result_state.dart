// TARGET: Modello risultati match immutabile con supporto team e gerarchia completa del match
// LOGIC GOAL: Centralizzare calcolo statistiche, risoluzione winner/team e struttura locale leggibile per la UI
// REACTION: UI reagisce a loading/success/error e può renderizzare dati completi senza logica nel build
// ERROR STRATEGY: Failure class per errori tipizzati e reset esplicito dei nullable
// ANTI-REGRESSION: Mantenere PlayerStatistics, sorting statistiche, supporto team e aggiungere match completo/dump locale

import 'package:flutter/material.dart';
import '../../../../match_sync/domain/entities/local_match_record.dart';
import '../../../domain/models/match.dart';
import '../../../domain/models/player_info.dart';
import '../../../domain/models/player_turn.dart';

enum AppStatus { idle, loading, success, error }

const Object _matchResultUnset = Object();

@immutable
class MatchResultState {
  final String matchId;
  final Match? match;
  final Map<String, PlayerStatistics> playerStats;
  final String? winnerId;
  final bool isTeamMode;
  final Map<String, String> playerToTeam;
  final AppStatus status;
  final Failure? failure;

  const MatchResultState({
    required this.matchId,
    this.match,
    this.playerStats = const {},
    this.winnerId,
    this.isTeamMode = false,
    this.playerToTeam = const {},
    this.status = AppStatus.idle,
    this.failure,
  });

  String? get winnerTeamId {
    if (!isTeamMode || winnerId == null) return null;
    if (winnerId!.startsWith('T')) return winnerId;
    return playerToTeam[winnerId];
  }

  String getWinnerDisplayName(List<PlayerInfo> players) {
    if (winnerId == null) return 'Sconosciuto';
    if (!isTeamMode) {
      return players.firstWhere(
            (p) => p.id == winnerId,
        orElse: () => PlayerInfo(
          id: winnerId!,
          name: winnerId!,
          isGuest: false,
          order: 0,
        ),
      ).name;
    }
    return winnerTeamId ?? winnerId!;
  }

  List<MapEntry<String, PlayerStatistics>> get sortedStats {
    final entries = playerStats.entries.toList();
    entries.sort((a, b) {
      final winnerCompare = (b.value.isWinner ? 1 : 0) - (a.value.isWinner ? 1 : 0);
      if (winnerCompare != 0) return winnerCompare;
      final avgCompare = b.value.average.compareTo(a.value.average);
      if (avgCompare != 0) return avgCompare;
      return b.value.totalScore.compareTo(a.value.totalScore);
    });
    return entries;
  }

  List<PlayerTurn> get allTurns {
    final currentMatch = match;
    if (currentMatch == null) return const [];
    final turns = <PlayerTurn>[];
    for (final set in currentMatch.sets) {
      for (final leg in set.legs) {
        for (final round in leg.rounds) {
          turns.addAll(round.turns);
        }
      }
    }
    return turns;
  }

  List<PlayerTurn> getPlayerTurns(String playerId) {
    return allTurns.where((turn) => turn.playerId == playerId).toList();
  }

  Map<String, dynamic> buildLocalStructure(String playerId) {
    final currentMatch = match;
    if (currentMatch == null) {
      return {
        'match': null,
        'source': 'DATABASE LOCALE (IN-MEMORY)',
      };
    }

    return {
      'match': {
        'id': currentMatch.id,
        'source': 'DATABASE LOCALE (IN-MEMORY)',
        'winnerId': currentMatch.winnerId,
        'startTime': currentMatch.startTime.toIso8601String(),
        'endTime': currentMatch.endTime?.toIso8601String(),
        'sets': currentMatch.sets.map((set) {
          return {
            'setNumber': set.setNumber,
            'winnerId': set.winnerId,
            'startTime': set.startTime.toIso8601String(),
            'endTime': set.endTime?.toIso8601String(),
            'legs': set.legs.map((leg) {
              return {
                'legNumber': leg.legNumber,
                'winnerId': leg.winnerId,
                'winningScore': leg.winningScore,
                'startTime': leg.startTime.toIso8601String(),
                'endTime': leg.endTime?.toIso8601String(),
                'cricketMarks': leg.cricketMarks.map((k, v) => MapEntry(k, v.map((ik, iv) => MapEntry(ik.toString(), iv)))),
                'cricketPoints': leg.cricketPoints,
                'rounds': leg.rounds.map((round) {
                  return {
                    'roundNumber': round.roundNumber,
                    'timestamp': round.timestamp.toIso8601String(),
                    'turns': round.turns.where((turn) => turn.playerId == playerId).map((turn) {
                      return {
                        'playerId': turn.playerId,
                        'turnNumber': turn.turnNumber,
                        'throws': turn.throws.map((dart) {
                          return {
                            'dartNumber': dart.dartNumber,
                            'target': dart.target,
                            'multiplier': dart.multiplier,
                            'score': dart.score,
                            'label': dart.label,
                            'timestamp': dart.timestamp.toIso8601String(),
                          };
                        }).toList(),
                        'total': turn.total,
                        'initialScore': turn.initialScore,
                        'score': turn.score,
                        'isBust': turn.isBust,
                        'isCheckout': turn.isCheckout,
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
  }

  bool get hasError => status == AppStatus.error;
  bool get isLoading => status == AppStatus.loading;

  MatchResultState copyWith({
    String? matchId,
    Object? match = _matchResultUnset,
    Map<String, PlayerStatistics>? playerStats,
    Object? winnerId = _matchResultUnset,
    bool? isTeamMode,
    Map<String, String>? playerToTeam,
    AppStatus? status,
    Object? failure = _matchResultUnset,
  }) {
    return MatchResultState(
      matchId: matchId ?? this.matchId,
      match: identical(match, _matchResultUnset) ? this.match : match as Match?,
      playerStats: playerStats ?? this.playerStats,
      winnerId: identical(winnerId, _matchResultUnset) ? this.winnerId : winnerId as String?,
      isTeamMode: isTeamMode ?? this.isTeamMode,
      playerToTeam: playerToTeam ?? this.playerToTeam,
      status: status ?? this.status,
      failure: identical(failure, _matchResultUnset) ? this.failure : failure as Failure?,
    );
  }
}

@immutable
class PlayerStatistics {
  final String playerId;
  final int totalTurns;
  final int totalScore;
  final int totalDarts;
  final int checkouts;
  final int bestTurn;
  final int legsWon;
  final int setsWon;
  final double average;
  final double checkoutPercentage;
  final bool isWinner;
  final LocalMatchSyncStatus? syncStatus;

  const PlayerStatistics({
    required this.playerId,
    this.totalTurns = 0,
    this.totalScore = 0,
    this.totalDarts = 0,
    this.checkouts = 0,
    this.bestTurn = 0,
    this.legsWon = 0,
    this.setsWon = 0,
    this.average = 0.0,
    this.checkoutPercentage = 0.0,
    this.isWinner = false,
    this.syncStatus,
  });

  String get formattedAverage => average.toStringAsFixed(1);
  String get formattedCheckout => '${checkoutPercentage.toStringAsFixed(0)}%';
  String get formattedBestTurn => bestTurn.toString();
  String get formattedTotalTurns => totalTurns.toString();
  String get formattedTotalDarts => totalDarts.toString();
  String get formattedLegsWon => legsWon.toString();
  String get formattedSetsWon => setsWon.toString();

  PlayerStatistics copyWith({
    int? totalTurns,
    int? totalScore,
    int? totalDarts,
    int? checkouts,
    int? bestTurn,
    int? legsWon,
    int? setsWon,
    double? average,
    double? checkoutPercentage,
    bool? isWinner,
    LocalMatchSyncStatus? syncStatus,
  }) {
    return PlayerStatistics(
      playerId: playerId,
      totalTurns: totalTurns ?? this.totalTurns,
      totalScore: totalScore ?? this.totalScore,
      totalDarts: totalDarts ?? this.totalDarts,
      checkouts: checkouts ?? this.checkouts,
      bestTurn: bestTurn ?? this.bestTurn,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
      average: average ?? this.average,
      checkoutPercentage: checkoutPercentage ?? this.checkoutPercentage,
      isWinner: isWinner ?? this.isWinner,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Failure {
  final String message;
  final Object? originalError;

  const Failure(this.message, [this.originalError]);

  @override
  String toString() => 'Failure: $message';
}