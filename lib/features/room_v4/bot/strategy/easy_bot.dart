import 'dart:math';
import 'bot_strategy.dart';
import '../../domain/models/game_state.dart';
import '../bot_level.dart';

class EasyBotStrategy extends BotStrategy {
  final Random _random = Random();
  final BotLevel level;

  EasyBotStrategy(this.level);

  @override
  String get name => 'Bot ${level.displayName}';

  @override
  DartSuggestion suggestDart(GameState gameState) {
    final currentScore = gameState.currentTurn.score;
    final doubleOut = gameState.gameConfig.doubleOut ?? true;

    // Punti rimasti per questo turno (3 dardi)
    final remainingThisTurn = gameState.remainingThrows;
    final isLastDart = remainingThisTurn == 1;

    // --- CHECKOUT (solo se possibile e realistico) ---
    if (doubleOut && currentScore <= level.maxCheckout) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      // Beginner chiude solo il 10-15% delle volte quando ha chance
      if (_random.nextDouble() < checkoutChance * 0.3) {
        final suggestion = _tryCheckout(currentScore);
        if (suggestion != null) return suggestion;
      }
    }

    // --- TIRO NORMALE (rispetta la media) ---
    return _normalDart(currentScore, isLastDart);
  }

  DartSuggestion _normalDart(int currentScore, bool isLastDart) {
    // Beginner: media ~11 punti/dardo
    // Distribuzione realistica:
    // - 60% single (media ~15)
    // - 30% miss/small (media ~5)
    // - 10% double piccolo (media ~20)

    final r = _random.nextDouble();

    // MISS o punteggio molto basso (30%)
    if (r < 0.30) {
      final missOptions = [0, 1, 2, 3, 5, 8];
      final target = missOptions[_random.nextInt(missOptions.length)];
      return DartSuggestion(
        target: target,
        multiplier: 1,
        reason: 'Tiro impreciso',
      );
    }

    // Single medio (50%)
    if (r < 0.80) {
      // Target comuni per beginner: 20, 19, 18, 16, 14, 12
      final targets = [20, 19, 18, 16, 14, 12, 10, 8];
      final target = targets[_random.nextInt(targets.length)];

      // A volte colpisce il single sbagliato (vicino)
      if (_random.nextDouble() < 0.2) {
        final offTarget = [5, 1, 3, 2, 7];
        return DartSuggestion(
          target: offTarget[_random.nextInt(offTarget.length)],
          multiplier: 1,
          reason: 'Tiro deviato',
        );
      }

      return DartSuggestion(
        target: target,
        multiplier: 1,
        reason: 'Single',
      );
    }

    // Double piccolo (20% dei tiri non-miss, quindi ~14% totale)
    // Beginner può colpire qualche double ma raramente
    final doubles = [16, 8, 10, 12, 14, 18, 20];
    final target = doubles[_random.nextInt(doubles.length)];

    // 70% di probabilità di mancare il double e fare single
    if (_random.nextDouble() < 0.7) {
      return DartSuggestion(
        target: target,
        multiplier: 1,
        reason: 'Double mancato',
      );
    }

    return DartSuggestion(
      target: target,
      multiplier: 2,
      reason: 'Double!',
    );
  }

  DartSuggestion? _tryCheckout(int score) {
    // Solo checkout molto semplici per beginner
    if (score == 40) {
      return const DartSuggestion(target: 20, multiplier: 2, reason: 'D20 checkout');
    }
    if (score == 32) {
      return const DartSuggestion(target: 16, multiplier: 2, reason: 'D16 checkout');
    }
    if (score == 24) {
      return const DartSuggestion(target: 12, multiplier: 2, reason: 'D12 checkout');
    }
    if (score == 20) {
      return const DartSuggestion(target: 10, multiplier: 2, reason: 'D10 checkout');
    }
    if (score == 16) {
      return const DartSuggestion(target: 8, multiplier: 2, reason: 'D8 checkout');
    }
    return null;
  }
}