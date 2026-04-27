// TARGET: Set (gruppo di leg)
// LOGIC GOAL: Raccogliere i leg di un set e tracciare il vincitore
// REACTION: UI mostra vincitore del set
// ANTI-REGRESSION: Mantenere winnerId

import 'package:flutter/foundation.dart';
import 'leg.dart';

@immutable
class Set {
  final int setNumber;
  final List<Leg> legs;
  final String? winnerId;
  final DateTime startTime;
  final DateTime? endTime;

  const Set({
    required this.setNumber,
    required this.legs,
    this.winnerId,
    required this.startTime,
    this.endTime,
  });

  bool get isFinished => winnerId != null;
  bool get isEmpty => legs.isEmpty;
  List<Leg> get setLegs => legs;
  String? get setWinnerId => winnerId;

  Set copyWith({
    int? setNumber,
    List<Leg>? legs,
    String? winnerId,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return Set(
      setNumber: setNumber ?? this.setNumber,
      legs: legs ?? this.legs,
      winnerId: winnerId ?? this.winnerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}