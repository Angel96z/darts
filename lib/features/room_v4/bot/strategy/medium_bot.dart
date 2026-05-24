import 'dart:math';
import '../../domain/models/checkout_suggestion.dart';
import 'bot_strategy.dart';
import '../../domain/models/game_state.dart';
import '../bot_level.dart';

class MediumBotStrategy extends BotStrategy {
  final Random _random = Random();
  final BotLevel level;

  MediumBotStrategy(this.level);

  @override
  String get name => 'Bot ${level.displayName}';

  @override
  DartSuggestion suggestDart(GameState gameState) {
    final currentScore = gameState.currentTurn.score;
    final doubleOut = gameState.gameConfig.doubleOut ?? true;

    // --- CHECKOUT (casual chiude ~20-30% delle volte) ---
    if (doubleOut && currentScore <= level.maxCheckout) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      if (_random.nextDouble() < checkoutChance * 0.5) {
        final suggestion = _tryCheckout(currentScore);
        if (suggestion != null) return suggestion;
      }
    }

    return _normalDart(currentScore);
  }

  DartSuggestion _normalDart(int currentScore) {
    // Casual: media ~16 punti/dardo
    // - 40% single alto (15-20 punti)
    // - 25% double medio (20-40 punti)
    // - 20% single basso (5-14 punti)
    // - 15% miss/small

    final r = _random.nextDouble();

    // MISS (15%)
    if (r < 0.15) {
      final missOptions = [0, 1, 2, 5, 8, 10];
      final target = missOptions[_random.nextInt(missOptions.length)];
      return DartSuggestion(target: target, multiplier: 1, reason: 'MISS');
    }

    // Single basso (20%)
    if (r < 0.35) {
      final targets = [12, 10, 8, 6, 4];
      final target = targets[_random.nextInt(targets.length)];
      return DartSuggestion(target: target, multiplier: 1, reason: 'Single basso');
    }

    // Single alto (40%)
    if (r < 0.75) {
      final targets = [20, 19, 18, 17, 16];
      final target = targets[_random.nextInt(targets.length)];
      return DartSuggestion(target: target, multiplier: 1, reason: 'Single alto');
    }

    // Double (25%)
    final doubles = [20, 16, 10, 8, 12, 14, 18];
    final target = doubles[_random.nextInt(doubles.length)];
    final doubleAccuracy = level.getDoubleAccuracyForScore(target * 2);

    if (_random.nextDouble() > doubleAccuracy) {
      // Mancato il double -> fa single
      return DartSuggestion(target: target, multiplier: 1, reason: 'Double mancato');
    }

    return DartSuggestion(target: target, multiplier: 2, reason: 'Double');
  }

  DartSuggestion? _tryCheckout(int score) {
    // Checkout semplici per casual
    final easyCheckouts = {
      40: (20, 2), 32: (16, 2), 24: (12, 2), 20: (10, 2),
      16: (8, 2), 48: (16, 3), 60: (20, 3), 57: (19, 3),
      54: (18, 3), 51: (17, 3),
    };

    if (easyCheckouts.containsKey(score)) {
      final (target, mult) = easyCheckouts[score]!;
      final accuracy = level.getDoubleAccuracyForScore(target * mult);
      if (_random.nextDouble() < accuracy) {
        return DartSuggestion(target: target, multiplier: mult, reason: 'Checkout!');
      }
    }
    return null;
  }
}