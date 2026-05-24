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

    // --- CHECKOUT (advanced/expert chiude 50-75% delle volte) ---
    if (doubleOut && currentScore <= level.maxCheckout) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      if (_random.nextDouble() < checkoutChance) {
        final suggestion = _tryCheckout(currentScore);
        if (suggestion != null) return suggestion;
      }
    }

    return _normalDart(currentScore);
  }

  DartSuggestion _normalDart(int currentScore) {
    // Expert: media ~26-31 punti/dardo
    // Distribuzione basata sul livello

    if (level == BotLevel.advanced) {
      // Advanced: ~26 punti/dardo
      // - 45% triple (T19, T18, T20 moderato)
      // - 25% single alto
      // - 20% double
      // - 10% miss
      return _advancedDart(currentScore);
    } else {
      // Expert: ~31 punti/dardo
      // - 55% triple (T20 frequente)
      // - 20% single alto
      // - 20% double
      // - 5% miss
      return _expertDart(currentScore);
    }
  }

  DartSuggestion _advancedDart(int currentScore) {
    final r = _random.nextDouble();

    // Miss (10%)
    if (r < 0.10) {
      return DartSuggestion(target: _random.nextInt(10), multiplier: 1, reason: 'Raro errore');
    }

    // Single (25%)
    if (r < 0.35) {
      final targets = [20, 19];
      return DartSuggestion(target: targets[_random.nextInt(targets.length)], multiplier: 1, reason: 'Single');
    }

    // Double (20%)
    if (r < 0.55) {
      final targets = [20, 16, 10];
      final target = targets[_random.nextInt(targets.length)];
      final accuracy = level.getDoubleAccuracyForScore(target * 2);
      if (_random.nextDouble() < accuracy) {
        return DartSuggestion(target: target, multiplier: 2, reason: 'Double');
      }
      return DartSuggestion(target: target, multiplier: 1, reason: 'Double mancato');
    }

    // Triple (45%) - advanced fa T20 ma non sempre
    final r2 = _random.nextDouble();
    if (r2 < 0.5) {
      // T20 la metà delle triple
      return const DartSuggestion(target: 20, multiplier: 3, reason: 'T20');
    } else {
      final triples = [19, 18];
      return DartSuggestion(target: triples[_random.nextInt(triples.length)], multiplier: 3, reason: 'Triple');
    }
  }

  DartSuggestion _expertDart(int currentScore) {
    final r = _random.nextDouble();

    // Miss raro (5%)
    if (r < 0.05) {
      return DartSuggestion(target: _random.nextInt(5), multiplier: 1, reason: 'Errore raro');
    }

    // Single (20%)
    if (r < 0.25) {
      return const DartSuggestion(target: 20, multiplier: 1, reason: 'Single 20');
    }

    // Double (20%)
    if (r < 0.45) {
      final targets = [20, 16];
      final target = targets[_random.nextInt(targets.length)];
      final accuracy = level.getDoubleAccuracyForScore(target * 2);
      if (_random.nextDouble() < accuracy) {
        return DartSuggestion(target: target, multiplier: 2, reason: 'Double');
      }
      return DartSuggestion(target: target, multiplier: 1, reason: 'Double mancato');
    }

    // Triple (55%) - expert fa tanto T20
    final r2 = _random.nextDouble();
    if (r2 < 0.7) {
      return const DartSuggestion(target: 20, multiplier: 3, reason: 'T20');
    } else {
      return const DartSuggestion(target: 19, multiplier: 3, reason: 'T19');
    }
  }

  DartSuggestion? _tryCheckout(int score) {
    final suggestions = CheckoutSuggestion.getSuggestions(
      score: score,
      dartsLeft: 3,
      outMode: 'double',
    );

    if (suggestions.isNotEmpty) {
      final (target, multiplier) = _parseDartLabel(suggestions.first);
      if (target != null && multiplier != null) {
        if (multiplier == 2) {
          final accuracy = level.getDoubleAccuracyForScore(target * multiplier);
          if (_random.nextDouble() < accuracy) {
            return DartSuggestion(target: target, multiplier: multiplier, reason: 'Checkout perfetto');
          }
          // Se manca il double, prova a lasciare un setup
          return DartSuggestion(target: target, multiplier: 1, reason: 'Checkout fallito');
        }
        return DartSuggestion(target: target, multiplier: multiplier, reason: 'Setup checkout');
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