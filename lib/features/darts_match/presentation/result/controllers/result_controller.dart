import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/match.dart';

class ResultVm {
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

  String _winnerId(Match match) {
    if (match.result?.winnerPlayerId != null) {
      return match.result!.winnerPlayerId!.value;
    }

    final ordered = match.snapshot.scoreboard.playerScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return ordered.isEmpty ? '-' : ordered.first.key.value;
  }
}

final resultControllerProvider = StateNotifierProvider<ResultController, ResultVm?>((ref) => ResultController());
