// lib/features/room_v4/bot/strategy/bot_strategy.dart
import '../../domain/models/game_state.dart';
import '../../domain/models/dart_throw.dart';

abstract class BotStrategy {
  const BotStrategy();

  /// Suggerisce il prossimo dardo da tirare
  DartSuggestion suggestDart(GameState gameState);

  /// Nome della strategia per debug
  String get name;
}

/// Risultato del suggerimento bot
class DartSuggestion {
  final int target;
  final int multiplier;
  final String reason;

  const DartSuggestion({
    required this.target,
    required this.multiplier,
    required this.reason,
  });

  DartThrow toDartThrow(int dartNumber) => DartThrow(
    dartNumber: dartNumber,
    target: target,
    multiplier: multiplier,
    score: target * multiplier,
    timestamp: DateTime.now(),
  );

  @override
  String toString() => '$multiplier×$target ($reason)';
}