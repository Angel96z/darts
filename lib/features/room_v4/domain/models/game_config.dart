// TARGET: Configurazione del gioco
// LOGIC GOAL: Solo dati di configurazione
// REACTION: UI mostra regole attive
// ERROR STRATEGY: N/A

import 'package:flutter/foundation.dart';

enum GameType { x01, cricket }
enum MatchMode { firstTo, bestOf }

@immutable
class GameConfig {
  final GameType type;
  final int? startingScore;
  final bool? tripleOut;
  final bool? doubleOut;
  final bool? doubleIn;
  final bool? cutThroat;

  const GameConfig({
    required this.type,
    this.startingScore,
    this.tripleOut,
    this.doubleOut,
    this.doubleIn,
    this.cutThroat,
  });

  factory GameConfig.x01({
    int startingScore = 501,
    bool tripleOut = false,
    bool doubleOut = true,
    bool doubleIn = false,
  }) {
    return GameConfig(
      type: GameType.x01,
      startingScore: startingScore,
      tripleOut: tripleOut,
      doubleOut: doubleOut,
      doubleIn: doubleIn,
    );
  }

  factory GameConfig.cricket({bool cutThroat = false}) {
    return GameConfig(
      type: GameType.cricket,
      startingScore: 0,
      cutThroat: cutThroat,
    );
  }

  GameConfig copyWith({
    GameType? type,
    int? startingScore,
    bool? tripleOut,
    bool? doubleOut,
    bool? doubleIn,
    bool? cutThroat,
  }) {
    return GameConfig(
      type: type ?? this.type,
      startingScore: startingScore ?? this.startingScore,
      tripleOut: tripleOut ?? this.tripleOut,
      doubleOut: doubleOut ?? this.doubleOut,
      doubleIn: doubleIn ?? this.doubleIn,
      cutThroat: cutThroat ?? this.cutThroat,
    );
  }
}

@immutable
class MatchConfig {
  final MatchMode mode;
  final int setCount;
  final int legCount;

  const MatchConfig({
    required this.mode,
    this.setCount = 1,
    this.legCount = 2,
  });

  int get setsToWin => mode == MatchMode.firstTo ? setCount : (setCount ~/ 2) + 1;
  int get legsToWin => mode == MatchMode.firstTo ? legCount : (legCount ~/ 2) + 1;

  MatchConfig copyWith({
    MatchMode? mode,
    int? setCount,
    int? legCount,
  }) {
    return MatchConfig(
      mode: mode ?? this.mode,
      setCount: setCount ?? this.setCount,
      legCount: legCount ?? this.legCount,
    );
  }
}