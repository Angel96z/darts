// lib/features/room_v4/bot/bot_controller.dart
import 'dart:async';

import '../application/room_notifier.dart';
import '../domain/models/game_state.dart';
import 'bot_level.dart';
import 'strategy/bot_strategy.dart';
import 'strategy/easy_bot.dart';
import 'strategy/medium_bot.dart';
import 'strategy/hard_bot.dart';
import 'strategy/expert_bot.dart';

class BotController {
  final RoomNotifier roomNotifier;
  Timer? _botTurnTimer;
  bool _isBotProcessing = false;

  BotController(this.roomNotifier);

  void startBotIfNeeded(GameState gameState) {
    // Annulla timer precedente
    _botTurnTimer?.cancel();

    final currentPlayerId = gameState.currentPlayerId;
    final isBot = currentPlayerId.startsWith('bot_');

    print('🤖 [BOT] startBotIfNeeded chiamato');
    print('   currentPlayerId: $currentPlayerId');
    print('   isBot: $isBot');
    print('   currentTurn.isComplete: ${gameState.currentTurn.isComplete}');

    if (!isBot) {
      print('🤖 [BOT] Non è un bot, esco');
      return;
    }

    // Se il turno è già completo, non fare nulla (aspetta il prossimo turno)
    if (gameState.currentTurn.isComplete) {
      print('🤖 [BOT] Turno già completo, attendo prossimo turno');
      return;
    }

    // Se stiamo già processando un bot, evita duplicati
    if (_isBotProcessing) {
      print('🤖 [BOT] Già processando un turno bot, esco');
      return;
    }

    // Estrai livello del bot dal playerId
    final botLevel = _extractBotLevel(currentPlayerId);
    print('🤖 [BOT] Bot level estratto: $botLevel');

    if (botLevel == null) {
      print('🤖 [BOT] Livello bot null, esco');
      return;
    }

    // Esegui il bot immediatamente (senza timer) se è il suo turno
    print('🤖 [BOT] Eseguo turno bot per ${botLevel.displayName}');
    _executeBotTurn(gameState, botLevel);
  }

  void _executeBotTurn(GameState gameState, BotLevel level) {
    if (_isBotProcessing) return;
    _isBotProcessing = true;

    // Delay tra i dardi per simulare il gioco reale
    _executeNextDart(gameState, level);
  }

  void _executeNextDart(GameState gameState, BotLevel level, {int dartIndex = 0}) {
    final currentTurn = gameState.currentTurn;

    print('🤖 [BOT] _executeNextDart - dartIndex: $dartIndex');
    print('   currentTurn.isComplete: ${currentTurn.isComplete}');
    print('   currentTurn.throws.length: ${currentTurn.throws.length}');

    // Se il turno è completo, esci
    if (currentTurn.isComplete) {
      print('🤖 [BOT] Turno completo, esco');
      _isBotProcessing = false;
      return;
    }

    // Se abbiamo già 3 dardi ma non è segnato come completo, esci comunque
    if (currentTurn.throws.length >= 3) {
      print('🤖 [BOT] 3 dardi tirati, attendo completion');
      _isBotProcessing = false;
      return;
    }

    // Ottieni suggerimento dal bot
    final strategy = _getStrategy(level);
    final suggestion = strategy.suggestDart(gameState);

    print('🤖 Bot ${level.displayName} (${strategy.name}): ${suggestion.target}×${suggestion.multiplier} - ${suggestion.reason}');

    // Esegui il dardo - usa roomNotifier direttamente
    roomNotifier.throwDart(suggestion.target, suggestion.multiplier);

    // Dopo un breve delay, esegui il prossimo dardo se il turno non è completo
    Future.delayed(const Duration(milliseconds: 500), () {
      final newState = roomNotifier.state.gameState;
      if (newState != null &&
          newState.currentPlayerId == gameState.currentPlayerId &&
          !newState.currentTurn.isComplete &&
          newState.currentTurn.throws.length < 3) {
        print('🤖 [BOT] Continuo con prossimo dardo');
        _executeNextDart(newState, level, dartIndex: dartIndex + 1);
      } else {
        print('🤖 [BOT] Turno finito o cambio giocatore');
        _isBotProcessing = false;
      }
    });
  }

// lib/features/room_v4/bot/bot_controller.dart
// Modifica il metodo _getStrategy:

  BotStrategy _getStrategy(BotLevel level) {
    switch (level) {
      case BotLevel.beginner:
        return EasyBotStrategy(level);
      case BotLevel.casual:
        return MediumBotStrategy(level);
      case BotLevel.intermediate:
        return HardBotStrategy(level);
      case BotLevel.advanced:
        return ExpertBotStrategy(level);
      case BotLevel.expert:
        return ExpertBotStrategy(level);
    }
  }

// Modifica il metodo _extractBotLevel per supportare i nuovi nomi
  BotLevel? _extractBotLevel(String playerId) {
    if (!playerId.startsWith('bot_')) return null;

    if (playerId.contains('beginner')) return BotLevel.beginner;
    if (playerId.contains('casual')) return BotLevel.casual;
    if (playerId.contains('intermediate')) return BotLevel.intermediate;
    if (playerId.contains('advanced')) return BotLevel.advanced;
    if (playerId.contains('expert')) return BotLevel.expert;

    return BotLevel.intermediate;
  }

  void dispose() {
    _botTurnTimer?.cancel();
  }
}