import 'package:flutter/foundation.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';

@immutable
class X01Rules {
  static (int newScore, int actualScore, bool isBust, bool isCheckout, bool didOpen) calculateDart({
    required int currentScore,
    required bool hasOpened,
    required DartThrow dart,
    required GameConfig config,
    required bool isCheckoutBlocked,
  }) {
    final doubleIn = config.doubleIn ?? false;
    final doubleOut = config.doubleOut ?? true;
    final tripleOut = config.tripleOut ?? false;

    int actualScore = dart.score;
    bool didOpen = false;

    // Gestione Double In
    if (doubleIn && !hasOpened) {
      if (dart.multiplier == 2) {
        didOpen = true;
      } else {
        actualScore = 0;
      }
    }

    final newScore = currentScore - actualScore;

    // CHECKOUT - solo se NON bloccato E newScore == 0
    if (newScore == 0 && !isCheckoutBlocked) {
      bool valid = true;
      if (doubleOut && !tripleOut) valid = (dart.multiplier == 2);
      if (tripleOut) valid = (dart.multiplier == 2 || dart.multiplier == 3);

      if (valid) return (0, actualScore, false, true, didOpen);
      return (currentScore, actualScore, true, false, didOpen);
    }

    // BUST - cattura TUTTI i casi di bust
    // Include: newScore < 0, newScore == 0 (quando checkout è bloccato o non valido), newScore == 1
    if (newScore <= 0) return (currentScore, actualScore, true, false, didOpen);
    if (newScore == 1 && (doubleOut || tripleOut)) return (currentScore, actualScore, true, false, didOpen);

    // Lancio valido
    return (newScore, actualScore, false, false, didOpen);
  }

  /// Verifica se il checkout è bloccato per regole team
  static bool isCheckoutBlocked({
    required Map<String, int> allTeamScores,
    required String currentTeamId,
    required int currentPlayerScore,
  }) {
    final currentTeamScore = allTeamScores[currentTeamId] ?? 0;
    final opposingTeamScores = allTeamScores.entries
        .where((entry) => entry.key != currentTeamId)
        .map((entry) => entry.value);
    final lowestOpposingTeamScore = opposingTeamScores.isEmpty
        ? 0
        : opposingTeamScores.reduce((a, b) => a < b ? a : b);

    final teamScoreAfterPlayerCheckout = currentTeamScore - currentPlayerScore;
    final isBlocked = teamScoreAfterPlayerCheckout > lowestOpposingTeamScore;

    print('🔍 Checkout Blocked Check:');
    print('  - Current Team: $currentTeamId (Score: $currentTeamScore)');
    print('  - Current Player Score: $currentPlayerScore');
    print('  - Team Score After Checkout: $teamScoreAfterPlayerCheckout');
    print('  - Lowest Opposing Team Score: $lowestOpposingTeamScore');
    print('  - Is Blocked: $isBlocked');

    return isBlocked;
  }
}