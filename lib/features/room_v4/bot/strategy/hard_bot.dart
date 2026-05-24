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

    // --- CHECKOUT (intermediate chiude ~35-45% delle volte) ---
    if (doubleOut && currentScore <= level.maxCheckout) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      if (_random.nextDouble() < checkoutChance * 0.7) {
        final suggestion = _tryCheckout(currentScore);
        if (suggestion != null) return suggestion;
      }
    }

    return _normalDart(currentScore);
  }

  DartSuggestion _normalDart(int currentScore) {
    // Intermediate: media ~21 punti/dardo
    // - 35% T (triple) bassi/medi (45-60 punti)
    // - 35% single alti (15-20 punti)
    // - 20% double medi (30-40 punti)
    // - 10% miss/errore

    final r = _random.nextDouble();

    // Miss/errore (10%)
    if (r < 0.10) {
      final missOptions = [0, 1, 2, 5, 7];
      return DartSuggestion(target: missOptions[_random.nextInt(missOptions.length)], multiplier: 1, reason: 'Errore');
    }

    // Single alto (35%)
    if (r < 0.45) {
      final targets = [20, 19, 18];
      final target = targets[_random.nextInt(targets.length)];
      return DartSuggestion(target: target, multiplier: 1, reason: 'Single');
    }

    // Double (20%)
    if (r < 0.65) {
      final targets = [20, 16, 10, 8];
      final target = targets[_random.nextInt(targets.length)];
      final accuracy = level.getDoubleAccuracyForScore(target * 2);
      if (_random.nextDouble() < accuracy) {
        return DartSuggestion(target: target, multiplier: 2, reason: 'Double');
      }
      return DartSuggestion(target: target, multiplier: 1, reason: 'Double mancato');
    }

    // Triple (35%) - MAI T20 per intermediate, solo T19, T18, T17
    final triples = [19, 18, 17, 16, 15];
    final target = triples[_random.nextInt(triples.length)];

    // Raro errore sulla triple
    if (_random.nextDouble() < 0.2) {
      return DartSuggestion(target: target, multiplier: 1, reason: 'Triple mancata');
    }

    return DartSuggestion(target: target, multiplier: 3, reason: 'Triple');
  }

  DartSuggestion? _tryCheckout(int score) {
    // Usa CheckoutSuggestion ma con filtro
    final suggestions = CheckoutSuggestion.getSuggestions(
      score: score,
      dartsLeft: 3,
      outMode: 'double',
    );

    if (suggestions.isNotEmpty && _random.nextDouble() < 0.6) {
      final (target, multiplier) = _parseDartLabel(suggestions.first);
      if (target != null && multiplier != null) {
        if (multiplier == 2) {
          final accuracy = level.getDoubleAccuracyForScore(target * multiplier);
          if (_random.nextDouble() < accuracy) {
            return DartSuggestion(target: target, multiplier: multiplier, reason: 'Checkout');
          }
        } else {
          return DartSuggestion(target: target, multiplier: multiplier, reason: 'Setup checkout');
        }
      }
    }
    return null;
  }

  (int?, int?) _parseDartLabel(String label) {
    if (label == 'MISS') return (0, 0);
    try {
      if (label.startsWith('D')) return (int.parse(label.substring(1)), 2);
      if (label.startsWith('T')) return (int.parse(label.substring(1)), 3);
      if (label.startsWith('S')) return (int.parse(label.substring(1)), 1);
    } catch (_) {}
    return (null, null);
  }
}