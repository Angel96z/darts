// lib/features/room_v4/bot/strategy/cricket_bot_strategy.dart
import 'dart:math';

import '../domain/game_types/cricket_rules.dart';
import '../domain/models/game_state.dart';
import 'bot_level.dart';
import 'strategy/bot_strategy.dart';

class CricketBotStrategy extends BotStrategy {
  final BotLevel level;
  final Random _random = Random();

  CricketBotStrategy(this.level);

  @override
  String get name => 'Cricket Bot (${level.displayName})';

  @override
  DartSuggestion suggestDart(GameState gameState) {
    final currentPlayerId = gameState.currentPlayerId;
    final myMarks = gameState.cricketMarks[currentPlayerId] ?? {};
    final myPoints = gameState.getCricketPoints(currentPlayerId);
    final isCutThroat = gameState.gameConfig.cutThroat == true;

    // Trova i numeri prioritari (non ancora chiusi dal giocatore)
    final openNumbers = CricketRules.cricketNumbers
        .where((n) => (myMarks[n] ?? 0) < 3)
        .toList();

    // Numeri chiusi dagli avversari (per Cut Throat)
    final opponentClosedNumbers = <int>[];
    if (isCutThroat) {
      for (final number in CricketRules.cricketNumbers) {
        bool allOpponentsClosed = true;
        for (final player in gameState.players) {
          if (player.id == currentPlayerId) continue;
          if ((gameState.cricketMarks[player.id]?[number] ?? 0) >= 3) {
            // Opponent ha chiuso
          } else {
            allOpponentsClosed = false;
            break;
          }
        }
        if (allOpponentsClosed) opponentClosedNumbers.add(number);
      }
    }

    // Se abbiamo punti, in modalità standard dobbiamo difendere i numeri aperti
    final defendingNumbers = <int>[];
    if (!isCutThroat && myPoints > 0) {
      for (final number in CricketRules.cricketNumbers) {
        final myMarksOnNumber = myMarks[number] ?? 0;
        if (myMarksOnNumber >= 3) continue;

        // Verifica se qualche avversario ha chiuso questo numero
        bool anyOpponentClosed = false;
        for (final player in gameState.players) {
          if (player.id == currentPlayerId) continue;
          if ((gameState.cricketMarks[player.id]?[number] ?? 0) >= 3) {
            anyOpponentClosed = true;
            break;
          }
        }
        if (!anyOpponentClosed) defendingNumbers.add(number);
      }
    }

    // Priorità 1: Segnare punti (se possibile)
    // Priorità 2: Chiudere numeri aperti
    // Priorità 3: Difendere numeri (in standard)

    // Scegli target basato sul livello
    return _chooseTarget(
      openNumbers: openNumbers,
      defendingNumbers: defendingNumbers,
      opponentClosedNumbers: opponentClosedNumbers,
      myPoints: myPoints,
      isCutThroat: isCutThroat,
    );
  }

  DartSuggestion _chooseTarget({
    required List<int> openNumbers,
    required List<int> defendingNumbers,
    required List<int> opponentClosedNumbers,
    required int myPoints,
    required bool isCutThroat,
  }) {
    // Beginner/Casual: approccio base
    if (level == BotLevel.beginner || level == BotLevel.casual) {
      if (openNumbers.isNotEmpty && _random.nextDouble() < 0.6) {
        final target = openNumbers[_random.nextInt(openNumbers.length)];
        final multiplier = _randomMultiplier();
        return DartSuggestion(
          target: target,
          multiplier: multiplier,
          reason: 'Apri numero',
        );
      }
      return const DartSuggestion(target: 20, multiplier: 1, reason: 'Random');
    }

    // Intermediate: priorità base
    if (level == BotLevel.intermediate) {
      final priorityNumbers = isCutThroat
          ? [...openNumbers, ...opponentClosedNumbers]
          : (myPoints > 0 ? [...openNumbers, ...defendingNumbers] : openNumbers);

      if (priorityNumbers.isNotEmpty) {
        priorityNumbers.sort((a, b) => b.compareTo(a));
        final target = priorityNumbers.first;
        final multiplier = _preferredMultiplier(target, level);
        return DartSuggestion(
          target: target,
          multiplier: multiplier,
          reason: isCutThroat
              ? 'Cut Throat: chiudi/segna'
              : (myPoints > 0 ? 'Difendi' : 'Apri'),
        );
      }
    }

    // Advanced/Expert: logica ottimale
    if (openNumbers.isNotEmpty) {
      final target = openNumbers.reduce((a, b) => a > b ? a : b);
      final multiplier = _preferredMultiplier(target, level);
      return DartSuggestion(
        target: target,
        multiplier: multiplier,
        reason: 'Chiudi numero alto',
      );
    }

    // Tutti i numeri chiusi - punta al bull
    return const DartSuggestion(target: 25, multiplier: 2, reason: 'Bullseye');
  }

  int _randomMultiplier() {
    final r = _random.nextDouble();
    if (r < 0.6) return 1;
    if (r < 0.85) return 2;
    return 3;
  }

  int _preferredMultiplier(int target, BotLevel level) {
    if (level == BotLevel.expert || level == BotLevel.advanced) {
      return target == 25 ? 2 : 3;
    }
    if (level == BotLevel.intermediate) {
      const highPreference = [20, 19, 18, 17, 16];
      if (highPreference.contains(target)) return 3;
      return 2;
    }
    return 2;
  }

}