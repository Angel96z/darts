/// File: dart_models.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'package:flutter/material.dart';

class DartHitData {
  final Offset boardPosition;
  final String sector;
  final int score;
  final double distanceMm;
  final String? targetQuadrant;

  const DartHitData({
    required this.boardPosition,
    required this.sector,
    required this.score,
    required this.distanceMm,
    this.targetQuadrant,
  });
}

class DartPlayer {
  final String id;
  final String name;

  const DartPlayer({
    required this.id,
    required this.name,
  });
}

class DartTeam {
  final String id;
  final String name;
  final List<DartPlayer> players;

  const DartTeam({
    required this.id,
    required this.name,
    required this.players,
  });
}

class DartThrow {
  final Offset position;
  final String sector;
  final int score;
  final DateTime timestamp;
  final double distanceMm;
  final String? targetQuadrant;

  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;

  final int roundNumber;
  final int turnNumber;
  final int dartInTurn;
  final bool isPass;

  const DartThrow({
    required this.position,
    required this.sector,
    required this.score,
    required this.timestamp,
    required this.distanceMm,
    this.targetQuadrant,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.roundNumber,
    required this.turnNumber,
    required this.dartInTurn,
    this.isPass = false,
  });

  /// 🔥 NUOVO: Factory per creare DartThrow da Map (usato nel sync service)
  factory DartThrow.fromMap(Map<String, dynamic> map) {
    return DartThrow(
      position: Offset(
        (map['boardX'] ?? 0.0).toDouble(),
        (map['boardY'] ?? 0.0).toDouble(),
      ),
      sector: map['sector']?.toString() ?? 'MISS',
      score: (map['score'] ?? 0).toInt(),
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp']
          : DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      distanceMm: (map['distanceMm'] ?? 0.0).toDouble(),
      targetQuadrant: map['quadrant']?.toString(),
      playerId: map['playerId']?.toString() ?? '',
      playerName: map['playerName']?.toString() ?? '',
      teamId: map['teamId']?.toString() ?? '',
      teamName: map['teamName']?.toString() ?? '',
      roundNumber: (map['round'] ?? 0).toInt(),
      turnNumber: (map['turn'] ?? 0).toInt(),
      dartInTurn: (map['dart'] ?? 0).toInt(),
      isPass: map['isPass'] == true,
    );
  }

  /// 🔥 NUOVO: Metodo per convertire DartThrow in Map (usato nel save)
  Map<String, dynamic> toMap() {
    return {
      'boardX': position.dx,
      'boardY': position.dy,
      'sector': sector,
      'score': score,
      'timestamp': timestamp.toIso8601String(),
      'distanceMm': distanceMm,
      'quadrant': targetQuadrant,
      'playerId': playerId,
      'playerName': playerName,
      'teamId': teamId,
      'teamName': teamName,
      'round': roundNumber,
      'turn': turnNumber,
      'dart': dartInTurn,
      'isPass': isPass,
    };
  }
}

abstract class DartGameEngine {
  void onThrow(String sector, int score, double distanceMm);
  void undo();
  void clear();
}

class DartTurnPlayer {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;

  const DartTurnPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
  });
}

class DartThrowManagerController extends ChangeNotifier {
  DartGameEngine? _engine;

  final List<DartThrow> _throws = [];
  final List<DartThrow> _currentTurn = [];
  final List<DartTurnPlayer> _turnOrder = [];

  int _currentOrderIndex = 0;
  int _currentDartInTurn = 0;
  int _roundNumber = 1;
  int _turnNumber = 1;
  bool _waitingNextTurn = false;

  List<DartThrow> get throws => List.unmodifiable(_throws);
  List<DartThrow> get currentTurnThrows => List.unmodifiable(_currentTurn);

  bool get isWaitingNextTurn => _waitingNextTurn;

  DartTurnPlayer? get currentPlayer {
    if (_turnOrder.isEmpty) return null;
    return _turnOrder[_currentOrderIndex];
  }

  void setEngine(DartGameEngine engine) {
    _engine = engine;
  }

  void configureSingles({
    required List<DartPlayer> players,
  }) {
    _turnOrder.clear();

    for (final p in players) {
      _turnOrder.add(
        DartTurnPlayer(
          playerId: p.id,
          playerName: p.name,
          teamId: p.id,
          teamName: p.name,
        ),
      );
    }
  }

  void registerHit(DartHitData hit) {
    if (_waitingNextTurn) return;

    final player = currentPlayer;
    if (player == null) return;

    final throwData = DartThrow(
      position: hit.boardPosition,
      sector: hit.sector,
      score: hit.score,
      timestamp: DateTime.now(),
      distanceMm: hit.distanceMm,
      targetQuadrant: hit.targetQuadrant,
      playerId: player.playerId,
      playerName: player.playerName,
      teamId: player.teamId,
      teamName: player.teamName,
      roundNumber: _roundNumber,
      turnNumber: _turnNumber,
      dartInTurn: _currentDartInTurn + 1,
    );

    _throws.add(throwData);
    _currentTurn.add(throwData);

    _engine?.onThrow(hit.sector, hit.score, hit.distanceMm);

    _currentDartInTurn++;

    if (_currentDartInTurn >= 3) {
      _waitingNextTurn = true;
    }

    notifyListeners();
  }

  void finishVisualTurn() {
    if (!_waitingNextTurn) return;

    _currentTurn.clear();
    _currentDartInTurn = 0;
    _waitingNextTurn = false;

    _currentOrderIndex++;

    if (_currentOrderIndex >= _turnOrder.length) {
      _currentOrderIndex = 0;
      _roundNumber++;
    }

    _turnNumber++;

    notifyListeners();
  }

  void undoLastThrow() {
    if (_throws.isEmpty) return;

    final removed = _throws.removeLast();

    _engine?.undo();

    final playerId = removed.playerId;
    final round = removed.roundNumber;
    final turn = removed.turnNumber;

    final playerIndex = _turnOrder.indexWhere((p) => p.playerId == playerId);

    if (playerIndex != -1) {
      _currentOrderIndex = playerIndex;
    }

    _roundNumber = round;
    _turnNumber = turn;

    _currentTurn
      ..clear()
      ..addAll(
        _throws.where(
              (t) =>
          t.playerId == playerId &&
              t.roundNumber == round &&
              t.turnNumber == turn,
        ),
      );

    _currentDartInTurn = _currentTurn.length;

    _waitingNextTurn = false;

    notifyListeners();
  }

  void clearAll() {
    _throws.clear();
    _currentTurn.clear();
    _currentDartInTurn = 0;
    _waitingNextTurn = false;

    _engine?.clear();

    notifyListeners();
  }
}