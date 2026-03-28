/// File: stats_aggregators.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';
import '../policies/input_fidelity_policy.dart';

class StatsSnapshot {
  const StatsSnapshot({required this.players, required this.highestScore});

  final List<PlayerMatchStats> players;
  final int highestScore;
}

class X01Stats {
  const X01Stats({required this.average, required this.highestCheckout, required this.maxTurn});

  final double average;
  final int highestCheckout;
  final int maxTurn;
}

class InputFidelityAwareStats {
  const InputFidelityAwareStats();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  X01Stats build(List<TurnCommitted> turns, StatsFidelity fidelity) {
    final totals = turns.map((t) => t.draft.total).toList();
    final avg = totals.isEmpty ? 0.0 : totals.reduce((a, b) => a + b) / totals.length;
    final maxTurn = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);
    return X01Stats(
      average: avg,
      highestCheckout: fidelity == StatsFidelity.full ? maxTurn : 0,
      maxTurn: maxTurn,
    );
  }
}

class MatchStatsAggregator {
  MatchStatsAggregator(this._fidelityAwareStats);
  final InputFidelityAwareStats _fidelityAwareStats;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  StatsSnapshot aggregate(Match match) {
    final players = <PlayerMatchStats>[];
    for (final player in match.roster.players) {
      final turns = match.snapshot.lastTurns.where((t) => t.draft.playerId == player.playerId).toList();
      final fidelity = match.config.inputSnapshot[player.playerId]?.fidelity ?? StatsFidelity.limited;
      final x01 = _fidelityAwareStats.build(turns, fidelity);
      players.add(
        PlayerMatchStats(
          playerId: player.playerId,
          average: x01.average,
          highestCheckout: x01.highestCheckout,
          maxTurn: x01.maxTurn,
          inputFidelity: fidelity,
        ),
      );
    }
    final highest = players.fold<int>(0, (prev, p) => p.maxTurn > prev ? p.maxTurn : prev);
    return StatsSnapshot(players: players, highestScore: highest);
  }
}

class LifetimeStatsAggregator {
  const LifetimeStatsAggregator();

  Map<String, num> merge(Map<String, num> current, X01Stats incoming) {
    return {
      'matches': (current['matches'] ?? 0) + 1,
      'average': ((current['average'] ?? 0) + incoming.average) / 2,
      'highestCheckout': (incoming.highestCheckout > (current['highestCheckout'] ?? 0))
          ? incoming.highestCheckout
          : (current['highestCheckout'] ?? 0),
    };
  }
}
