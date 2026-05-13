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
    final tripleOut = gameState.gameConfig.tripleOut ?? false;

    String outMode;
    if (tripleOut) outMode = 'triple';
    else if (doubleOut) outMode = 'double';
    else outMode = 'single';

    // Checkout con probabilità realistica
    if (currentScore <= 120) {
      final checkoutChance = level.getCheckoutChance(currentScore) * 1.2;
      if (_random.nextDouble() < checkoutChance) {
        final suggestions = CheckoutSuggestion.getSuggestions(
          score: currentScore,
          dartsLeft: gameState.remainingThrows,
          outMode: outMode,
        );
        if (suggestions.isNotEmpty && _random.nextDouble() < 0.6) {
          final (target, multiplier) = _parseDartLabel(suggestions.first);
          if (target != null && multiplier != null) {
            // Probabilità di sbagliare il double
            if (multiplier == 2 && _random.nextDouble() > level.doublesAccuracy) {
              return DartSuggestion(target: 1, multiplier: 1, reason: 'MISSED DOUBLE');
            }
            return DartSuggestion(target: target, multiplier: multiplier, reason: 'Checkout');
          }
        }
      }
    }

    // Cerca di avvicinarsi al checkout
    return _targetForAverage(currentScore);
  }

  DartSuggestion _targetForAverage(int currentScore) {
    // Media target ≈ 45-55
    final targets = [
      (target: 20, multiplier: 1, value: 20),
      (target: 19, multiplier: 1, value: 19),
      (target: 20, multiplier: 2, value: 40),
      (target: 19, multiplier: 2, value: 38),
      (target: 18, multiplier: 2, value: 36),
      (target: 16, multiplier: 2, value: 32),
      (target: 20, multiplier: 3, value: 60), // raro
    ];

    final valid = targets.where((t) => t.value <= currentScore).toList();
    if (valid.isEmpty) {
      return const DartSuggestion(target: 1, multiplier: 1, reason: 'Safe');
    }

    // Scegli in base alla media (più probabili i valori medi)
    valid.sort((a, b) => (a.value - 45).abs().compareTo((b.value - 45).abs()));
    final selected = valid.first;

    // 10% miss
    if (_random.nextDouble() < 0.1) {
      return const DartSuggestion(target: 0, multiplier: 0, reason: 'MISS');
    }

    // Probabilità di colpire single invece di double/triple
    if (selected.multiplier > 1 && _random.nextDouble() < 0.3) {
      return DartSuggestion(
        target: selected.target,
        multiplier: 1,
        reason: 'Sbagliato moltiplicatore',
      );
    }

    return DartSuggestion(
      target: selected.target,
      multiplier: selected.multiplier,
      reason: 'Setup',
    );
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