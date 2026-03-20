import 'dart:async';
import '../logic/dart_throw_logic.dart';
import '../logic/score_controller.dart';

class BullTrainingEngine implements DartGameEngine {

  final ScoreController score;

  BullTrainingEngine(this.score);

  final List<String> _currentTurn = [];

  Timer? _turnTimer;

  List<String> get currentTurnThrows => List.unmodifiable(_currentTurn);

  bool get isTurnComplete => _currentTurn.length == 3;

  @override
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
  void clear() {

    _turnTimer?.cancel();

    _currentTurn.clear();

    score.clear();
  }
}