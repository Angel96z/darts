// TARGET: Match (partita completa)
// LOGIC GOAL: Raccogliere tutti i set del match
// REACTION: UI mostra vincitore finale
// ANTI-REGRESSION: Mantenere id e winnerId

import 'package:flutter/foundation.dart';
import 'set.dart';

@immutable
class Match {
  final String id;
  final List<Set> sets;
  final String? winnerId;
  final DateTime startTime;
  final DateTime? endTime;

  const Match({
    required this.id,
    required this.sets,
    this.winnerId,
    required this.startTime,
    this.endTime,
  });

  bool get isFinished => winnerId != null;
  bool get isEmpty => sets.isEmpty;
  String get matchId => id;
  List<Set> get matchSets => sets;
  String? get matchWinnerId => winnerId;
  DateTime get matchStartTime => startTime;
  DateTime? get matchEndTime => endTime;

  Match copyWith({
    String? id,
    List<Set>? sets,
    String? winnerId,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return Match(
      id: id ?? this.id,
      sets: sets ?? this.sets,
      winnerId: winnerId ?? this.winnerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}