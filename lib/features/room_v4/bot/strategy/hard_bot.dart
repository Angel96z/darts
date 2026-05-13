import 'dart:math';
import '../../domain/models/checkout_suggestion.dart';
import 'bot_strategy.dart';
import '../../domain/models/game_state.dart';
import '../bot_level.dart';

class HardBotStrategy extends BotStrategy {
  final Random _random = Random();
  final BotLevel level;

  HardBotStrategy(this.level);

  @override
  String get name => 'Bot ${level.displayName}';

  @override
  DartSuggestion suggestDart(GameState gameState) {
    final currentScore = gameState.currentTurn.score;
    final doubleOut = gameState.gameConfig.doubleOut ?? true;
    final tripleOut = gameState.gameConfig.tripleOut ?? false;

    String outMode;
    if (tripleOut) outMode = 'triple';
    else if (doubleOut) outMode = 'double';
    else outMode = 'single';

    // Checkout intelligente
    if (currentScore <= 140) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      if (_random.nextDouble() < checkoutChance) {
        final suggestions = CheckoutSuggestion.getSuggestions(
          score: currentScore,
          dartsLeft: gameState.remainingThrows,
          outMode: outMode,
        );
        if (suggestions.isNotEmpty) {
          final (target, multiplier) = _parseDartLabel(suggestions.first);
          if (target != null && multiplier != null) {
            if (multiplier == 2 && _random.nextDouble() > level.doublesAccuracy) {
              return DartSuggestion(target: target, multiplier: 1, reason: 'MISSED DOUBLE');
            }
            return DartSuggestion(target: target, multiplier: multiplier, reason: 'Checkout');
          }
        }
      }
    }

    // Setup strategico
    return _strategicSetup(currentScore);
  }

  DartSuggestion _strategicSetup(int currentScore) {
    // Strategie per lasciare checkout
    const setups = [
      (score: 100, target: 20, mult: 3, value: 60),
      (score: 98, target: 20, mult: 3, value: 60),
      (score: 96, target: 20, mult: 3, value: 60),
      (score: 94, target: 18, mult: 3, value: 54),
      (score: 92, target: 20, mult: 3, value: 60),
      (score: 90, target: 18, mult: 3, value: 54),
      (score: 88, target: 20, mult: 3, value: 60),
      (score: 86, target: 18, mult: 3, value: 54),
    ];

    for (final setup in setups) {
      if (currentScore >= setup.score && setup.value <= currentScore) {
        if (_random.nextDouble() < 0.08) {
          return const DartSuggestion(target: 0, multiplier: 0, reason: 'MISS');
        }
        return DartSuggestion(
          target: setup.target,
          multiplier: setup.mult,
          reason: 'Setup strategico',
        );
      }
    }

    // Default: T20 ma con possibilità di errore
    if (_random.nextDouble() < 0.05) {
      return const DartSuggestion(target: 5, multiplier: 1, reason: 'ERRORE');
    }
    return const DartSuggestion(target: 20, multiplier: 3, reason: 'T20');
  }

  (int?, int?) _parseDartLabel(String label) {
    if (label == 'MISS') return (0, 0);
    try {
      final prefix = label.substring(0, 1);
      final number = int.parse(label.substring(1));
      if (prefix == 'S') return (number, 1);
      if (prefix == 'D') return (number, 2);
      if (prefix == 'T') return (number, 3);
    } catch (_) {}
    return (null, null);
  }
}