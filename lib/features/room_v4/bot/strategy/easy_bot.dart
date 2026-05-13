import 'dart:math';
import 'bot_strategy.dart';
import '../../domain/models/game_state.dart';
import '../../domain/game_types/x01_rules.dart';
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
    final tripleOut = gameState.gameConfig.tripleOut ?? false;

    // Se il punteggio è basso, tenta checkout con probabilità realistica
    if (currentScore <= 100 && doubleOut) {
      final checkoutChance = level.getCheckoutChance(currentScore);
      if (_random.nextDouble() < checkoutChance) {
        final suggestion = _tryCheckout(currentScore, doubleOut, tripleOut);
        if (suggestion != null) return suggestion;
      }
    }

    // Scegli un target basato sulla media del livello
    return _targetForAverage(currentScore);
  }

  DartSuggestion _targetForAverage(int currentScore) {
    // Media target ≈ 35-45
    final targets = [
      (target: 20, multiplier: 1, value: 20),
      (target: 19, multiplier: 1, value: 19),
      (target: 18, multiplier: 1, value: 18),
      (target: 20, multiplier: 2, value: 40),
      (target: 16, multiplier: 2, value: 32),
      (target: 8, multiplier: 2, value: 16),
    ];

    // Filtra quelli che non superano il punteggio
    final valid = targets.where((t) => t.value <= currentScore).toList();
    if (valid.isEmpty) {
      return const DartSuggestion(target: 1, multiplier: 1, reason: 'Safe');
    }

    final selected = valid[_random.nextInt(valid.length)];

    // 20% probabilità di miss
    if (_random.nextDouble() < 0.2) {
      return const DartSuggestion(target: 0, multiplier: 0, reason: 'MISS');
    }

    return DartSuggestion(
      target: selected.target,
      multiplier: selected.multiplier,
      reason: 'Punteggio medio',
    );
  }

  DartSuggestion? _tryCheckout(int score, bool doubleOut, bool tripleOut) {
    final checkoutOptions = _getSimpleCheckout(score, doubleOut, tripleOut);
    if (checkoutOptions != null && _random.nextDouble() < 0.3) {
      return checkoutOptions;
    }
    return null;
  }

  DartSuggestion? _getSimpleCheckout(int score, bool doubleOut, bool tripleOut) {
    if (doubleOut && score <= 40 && score % 2 == 0) {
      return DartSuggestion(target: score ~/ 2, multiplier: 2, reason: 'Double checkout');
    }
    if (score == 50) {
      return const DartSuggestion(target: 25, multiplier: 2, reason: 'Bullseye');
    }
    return null;
  }
}