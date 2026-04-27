// TARGET: Regole di calcolo punteggio base
// LOGIC GOAL: Calcolare totali, medie, statistiche in modo deterministico
// REACTION: Fornisce getter puri per la UI
// ERROR STRATEGY: Restituisce 0 se dati mancanti
// ANTI-REGRESSION: Mantenere calcolo average, checkout percentage

import 'package:flutter/foundation.dart';
import '../models/dart_throw.dart';
import '../models/player_turn.dart';

@immutable
class ScoringRules {
  /// Calcola il totale di una lista di dardi
  static int calculateTotal(List<DartThrow> throws) {
    return throws.fold(0, (sum, dart) => sum + dart.score);
  }

  /// Calcola la media per turno (3 dardi)
  static double calculateTurnAverage(PlayerTurn turn) {
    if (turn.throws.isEmpty) return 0.0;
    // La media è su 3 dardi, anche se il turno è finito prima
    final dartsThrown = turn.throws.length;
    final normalizedScore = (turn.total / dartsThrown) * 3;
    return normalizedScore;
  }

  /// Calcola la media complessiva di un giocatore
  /// Calcola la media complessiva di un giocatore
  /// Per Cricket usa totalMarks (somma moltiplicatori), per X01 usa total (somma punteggi)
  static double calculateOverallAverage(List<PlayerTurn> playerTurns, {bool isCricket = false}) {
    if (playerTurns.isEmpty) return 0.0;

    int totalValue = 0;
    int totalDarts = 0;

    for (final turn in playerTurns) {
      if (isCricket) {
        totalValue += turn.totalMarks;
      } else {
        totalValue += turn.total;
      }
      totalDarts += turn.throws.length;
    }

    if (totalDarts == 0) return 0.0;
    return (totalValue / totalDarts) * 3;
  }

  /// Calcola la percentuale di checkout
  static double calculateCheckoutPercentage(List<PlayerTurn> turns) {
    final checkoutTurns = turns.where((t) => t.isCheckout).length;
    if (turns.isEmpty) return 0.0;
    return (checkoutTurns / turns.length) * 100;
  }

  /// Calcola il miglior turno di un giocatore
  static int calculateBestTurn(List<PlayerTurn> turns) {
    if (turns.isEmpty) return 0;
    return turns.map((t) => t.total).reduce((a, b) => a > b ? a : b);
  }
}