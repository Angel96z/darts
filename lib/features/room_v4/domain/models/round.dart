// TARGET: Round di gioco (tutti i giocatori hanno giocato un turno)
// LOGIC GOAL: Raccogliere i turni di tutti i giocatori in un round
// REACTION: UI mostra progressione del round
// ANTI-REGRESSION: Mantenere ordine dei turni

import 'package:flutter/foundation.dart';
import 'player_turn.dart';

@immutable
class Round {
  final int roundNumber;
  final List<PlayerTurn> turns;
  final DateTime timestamp;

  const Round({
    required this.roundNumber,
    required this.turns,
    required this.timestamp,
  });

  bool get isComplete => turns.isNotEmpty;
  bool get isEmpty => turns.isEmpty;

  Round copyWith({
    int? roundNumber,
    List<PlayerTurn>? turns,
    DateTime? timestamp,
  }) {
    return Round(
      roundNumber: roundNumber ?? this.roundNumber,
      turns: turns ?? this.turns,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}