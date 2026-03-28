import 'package:flutter/material.dart';

class DartScore {
  final String label;
  final int score;

  const DartScore(this.label, this.score);
}

class ScoreController extends ChangeNotifier {

  final List<DartScore> _scores = [];
  final List<double> _distances = [];

  List<DartScore> get scores => List.unmodifiable(_scores);

  String _target = "T20";
  int _hitsOnTarget = 0;

  String get target => _target;

  int get totalThrows => _scores.length;

  int get hitsOnTarget => _hitsOnTarget;

  int get hitPercent {
    final total = _scores.length;
    if (total == 0) return 0;

    final value = (_hitsOnTarget / total) * 100;

    if (value.isNaN || value.isInfinite) return 0;

    return value.round();
  }

  double get avgDistanceMm {
    if (_distances.isEmpty) return 0;

    final sum = _distances.reduce((a, b) => a + b);
    final value = sum / _distances.length;

    if (value.isNaN || value.isInfinite) return 0;

    return value;
  }

  void setTarget(String sector) {
    _target = sector;
    _recalculate();
    notifyListeners();
  }

  void registerHit(String label, int score) {
    _scores.add(DartScore(label, score));

    if (label == _target) {
      _hitsOnTarget++;
    }

    notifyListeners();
  }

  void registerDistance(double mm) {
    if (mm.isNaN || mm.isInfinite) return;

    _distances.add(mm);
    notifyListeners();
  }

  void registerTurn(int score) {
    _scores.add(DartScore("TURN", score));
    _recalculate();
    notifyListeners();
  }

  void undoLast() {
    if (_scores.isEmpty) return;

    _scores.removeLast();

    if (_distances.isNotEmpty) {
      _distances.removeLast();
    }

    _recalculate();
    notifyListeners();
  }

  void clear() {
    _scores.clear();
    _distances.clear();
    _recalculate();
    notifyListeners();
  }

  int get total => _scores.fold(0, (p, e) => p + e.score);

  void _recalculate() {
    _hitsOnTarget = 0;

    for (final s in _scores) {
      if (s.label == _target) {
        _hitsOnTarget++;
      }
    }
  }
}

