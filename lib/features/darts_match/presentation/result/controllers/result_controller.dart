/// File: result_controller.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/match.dart';

class ResultVm {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const ResultVm({
    required this.winnerId,
    required this.highestScore,
    required this.average,
  });

  final String winnerId;
  final int highestScore;
  final int average;
}

class ResultController extends StateNotifier<ResultVm?> {
  ResultController() : super(null);

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void setFromMatch(Match match) {
    final winner = _winnerId(match);
    final turns = match.snapshot.lastTurns;
    final highest = turns.isEmpty
        ? 0
        : turns.map((turn) => turn.draft.total).reduce((a, b) => a > b ? a : b);

    final avg = turns.isEmpty
        ? 0
        : (turns.map((turn) => turn.draft.total).reduce((a, b) => a + b) / turns.length).round();

    state = ResultVm(
      winnerId: winner,
      highestScore: highest,
      average: avg,
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  String _winnerId(Match match) {
    final winner = match.result?.winnerPlayerId;
    if (winner != null) {
      return winner.value;
    }

    // fallback robusto: usa ultimo checkout reale
    final turns = match.snapshot.lastTurns;

    for (final turn in turns.reversed) {
      if (turn.resolution.isCheckout) {
        return turn.draft.playerId.value;
      }
    }

    // fallback finale: miglior score
    final scores = match.snapshot.scoreboard.playerScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (scores.isNotEmpty) {
      return scores.first.key.value;
    }

    return '-';
  }
}

final resultControllerProvider = StateNotifierProvider<ResultController, ResultVm?>((ref) => ResultController());
