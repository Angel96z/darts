// TARGET: Modello immutabile del singolo dardo
// LOGIC GOAL: Solo dati grezzi e getter per etichetta/punteggio
// REACTION: UI mostra label e score
// ERROR STRATEGY: N/A - modello puro
// ANTI-REGRESSION: Mantenere getter label e score

import 'package:flutter/foundation.dart';

@immutable
class DartThrow {
  final int dartNumber;
  final int target;
  final int multiplier;
  final int score;
  final DateTime timestamp;

  const DartThrow({
    required this.dartNumber,
    required this.target,
    required this.multiplier,
    required this.score,
    required this.timestamp,
  });

  // GETTER - LOGICA PURA
  String get label {
    if (multiplier == 0) return "MISS";
    if (target == 25) return multiplier == 2 ? "D25" : "S25";
    final prefix = multiplier == 3 ? "T" : (multiplier == 2 ? "D" : "S");
    return "$prefix$target";
  }

  DartThrow copyWith({
    int? dartNumber,
    int? target,
    int? multiplier,
    int? score,
    DateTime? timestamp,
  }) {
    return DartThrow(
      dartNumber: dartNumber ?? this.dartNumber,
      target: target ?? this.target,
      multiplier: multiplier ?? this.multiplier,
      score: score ?? this.score,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'dartNumber': dartNumber,
      'target': target,
      'multiplier': multiplier,
      'score': score,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DartThrow.fromMap(Map<String, dynamic> map) {
    return DartThrow(
      dartNumber: map['dartNumber'],
      target: map['target'],
      multiplier: map['multiplier'],
      score: map['score'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}