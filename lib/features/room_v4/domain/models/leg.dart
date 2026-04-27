// TARGET: Leg (partita singola)
// LOGIC GOAL: Raccogliere i round di un leg e tracciare il vincitore
// REACTION: UI mostra vincitore del leg e resetta score
// ANTI-REGRESSION: Mantenere winnerId e winningScore
// 🆕 CRICKET: Salva marks e points permanentemente nel leg

import 'package:flutter/foundation.dart';
import 'round.dart';

@immutable
class Leg {
  final int legNumber;
  final List<Round> rounds;
  final String? winnerId;
  final int winningScore;
  final DateTime startTime;
  final DateTime? endTime;

  // 🆕 CRICKET DATA - Permanent storage per questo leg
  final Map<String, Map<int, int>> cricketMarks;
  final Map<String, int> cricketPoints;

  const Leg({
    required this.legNumber,
    required this.rounds,
    this.winnerId,
    required this.winningScore,
    required this.startTime,
    this.endTime,
    this.cricketMarks = const {},
    this.cricketPoints = const {},
  });

  bool get isFinished => winnerId != null;
  bool get isEmpty => rounds.isEmpty;
  int get totalTurns => rounds.fold(0, (sum, r) => sum + r.turns.length);
  int get totalDarts => rounds.fold(0, (sum, r) => sum + r.turns.fold(0, (s, t) => s + t.throws.length));
  List<Round> get legRounds => rounds;
  String? get legWinnerId => winnerId;

  Leg copyWith({
    int? legNumber,
    List<Round>? rounds,
    String? winnerId,
    int? winningScore,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, Map<int, int>>? cricketMarks,
    Map<String, int>? cricketPoints,
  }) {
    return Leg(
      legNumber: legNumber ?? this.legNumber,
      rounds: rounds ?? this.rounds,
      winnerId: winnerId ?? this.winnerId,
      winningScore: winningScore ?? this.winningScore,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      cricketMarks: cricketMarks ?? this.cricketMarks,
      cricketPoints: cricketPoints ?? this.cricketPoints,
    );
  }
}