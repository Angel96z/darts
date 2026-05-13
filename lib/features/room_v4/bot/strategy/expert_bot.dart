import 'dart:math';
import '../../domain/models/checkout_suggestion.dart';
import 'bot_strategy.dart';
import '../../domain/models/game_state.dart';
import '../bot_level.dart';

class ExpertBotStrategy extends BotStrategy {
  final Random _random = Random();
  final BotLevel level;

  ExpertBotStrategy(this.level);

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

    // Checkout quasi sempre tentato
    if (currentScore <= 170) {
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

    // Setup ottimale professionale
    return _optimalSetup(currentScore);
  }

  DartSuggestion _optimalSetup(int currentScore) {
    const optimalSetups = [
      (score: 170, target: 20, mult: 3, value: 60),
      (score: 167, target: 20, mult: 3, value: 60),
      (score: 164, target: 20, mult: 3, value: 60),
      (score: 161, target: 20, mult: 3, value: 60),
      (score: 160, target: 20, mult: 3, value: 60),
      (score: 158, target: 20, mult: 3, value: 60),
      (score: 157, target: 20, mult: 3, value: 60),
      (score: 156, target: 20, mult: 3, value: 60),
      (score: 155, target: 20, mult: 3, value: 60),
      (score: 154, target: 20, mult: 3, value: 60),
      (score: 153, target: 20, mult: 3, value: 60),
      (score: 152, target: 20, mult: 3, value: 60),
      (score: 151, target: 20, mult: 3, value: 60),
      (score: 150, target: 20, mult: 3, value: 60),
      (score: 149, target: 20, mult: 3, value: 60),
      (score: 148, target: 20, mult: 3, value: 60),
      (score: 147, target: 20, mult: 3, value: 60),
      (score: 146, target: 20, mult: 3, value: 60),
    ];

    for (final setup in optimalSetups) {
      if (currentScore >= setup.score && setup.value <= currentScore) {
        if (_random.nextDouble() < 0.02) {
          return DartSuggestion(target: setup.target, multiplier: 1, reason: 'MISS');
        }
        return DartSuggestion(
          target: setup.target,
          multiplier: setup.mult,
          reason: 'Setup ottimale',
        );
      }
    }

    // Default T20 con raro errore
    if (_random.nextDouble() < 0.03) {
      return const DartSuggestion(target: 1, multiplier: 1, reason: 'ERRORE RARO');
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