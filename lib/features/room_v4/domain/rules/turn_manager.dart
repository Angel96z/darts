// TARGET: Gestione deterministico dello stato del turno
// LOGIC GOAL: Determinare se un turno è completo, se può continuare
// REACTION: Fornisce getter puri per la UI
// ERROR STRATEGY: Restituisce false se dati inconsistenti
// ANTI-REGRESSION: Mantenere logica isComplete, remainingThrows

import 'package:flutter/foundation.dart';
import '../models/player_turn.dart';
import '../models/dart_throw.dart';
import 'scoring_rules.dart';

@immutable
class TurnManager {
  /// Verifica se il turno è completo (3 dardi O checkout O bust)
  static bool isTurnComplete(PlayerTurn turn) {
    return turn.throws.length >= 3 || turn.isCheckout || turn.isBust;
  }

  /// Dardi rimanenti in questo turno
  static int getRemainingThrows(PlayerTurn turn) {
    if (isTurnComplete(turn)) return 0;
    return 3 - turn.throws.length;
  }

  /// Crea un nuovo turno vuoto per un giocatore
  static PlayerTurn createEmptyTurn({
    required String playerId,
    required int turnNumber,
    required int roundNumber,
    required int legNumber,
    required int currentScore,
  }) {
    return PlayerTurn(
      playerId: playerId,
      turnNumber: turnNumber,
      roundNumber: roundNumber,
      legNumber: legNumber,
      throws: [],
      total: 0,
      totalMarks: 0,
      initialScore: currentScore,
      score: currentScore,
      isBust: false,
      isCheckout: false,
      timestamp: DateTime.now(),
    );
  }

  /// Crea un turno completato (utile per test/restore)
  static PlayerTurn createCompletedTurn({
    required String playerId,
    required int turnNumber,
    required int roundNumber,
    required int legNumber,
    required List<DartThrow> throws,
    required int initialScore,
    required int finalScore,
    required bool isBust,
    required bool isCheckout,
  }) {
    return PlayerTurn(
      playerId: playerId,
      turnNumber: turnNumber,
      roundNumber: roundNumber,
      legNumber: legNumber,
      throws: throws,
      total: ScoringRules.calculateTotal(throws),
      totalMarks: 0,
      initialScore: initialScore,
      score: finalScore,
      isBust: isBust,
      isCheckout: isCheckout,
      timestamp: DateTime.now(),
    );
  }
}