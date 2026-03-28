/// File: bull_training_engine.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'dart:async';
import '../entities/dart_models.dart';
import '../../../score/presentation/state/score_controller.dart';

class BullTrainingEngine implements DartGameEngine {

  final ScoreController score;

  BullTrainingEngine(this.score);

  final List<String> _currentTurn = [];

  Timer? _turnTimer;

  List<String> get currentTurnThrows => List.unmodifiable(_currentTurn);

  bool get isTurnComplete => _currentTurn.length == 3;

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void onThrow(String sector, int scoreValue, double distanceMm) {

    _turnTimer?.cancel();

    score.registerHit(sector, scoreValue);
    score.registerDistance(distanceMm);

    _currentTurn.add(sector);

    if (_currentTurn.length == 3) {
      _turnTimer = Timer(const Duration(seconds: 2), () {
        _currentTurn.clear();
      });
    }
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void undo() {

    _turnTimer?.cancel();

    score.undoLast();

    if (_currentTurn.isNotEmpty) {
      _currentTurn.removeLast();
      return;
    }

    final history = score.scores;

    if (history.isEmpty) return;

    final rebuild = <String>[];

    for (int i = history.length - 1; i >= 0 && rebuild.length < 3; i--) {
      rebuild.insert(0, history[i].label);
      if (rebuild.length == 3) break;
    }

    _currentTurn
      ..clear()
      ..addAll(rebuild);
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void clear() {

    _turnTimer?.cancel();

    _currentTurn.clear();

    score.clear();
  }
}