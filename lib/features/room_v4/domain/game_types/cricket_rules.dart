import 'package:flutter/foundation.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';

@immutable
class CricketRules {
  // Numeri validi per il Cricket (15-20 + Bull)
  static const List<int> cricketNumbers = [20, 19, 18, 17, 16, 15, 25];

  static bool isValidCricketNumber(int target) => cricketNumbers.contains(target);

  static int getNumberValue(int target) => target == 25 ? 25 : target;

  static (int newScore, int actualScore, bool isBust, bool isCheckout, bool didOpen) calculateDart({
    required int currentScore,
    required bool hasOpened,
    required DartThrow dart,
    required GameConfig config,
    required bool isCheckoutBlocked,
    required Map<String, Map<int, int>> allMarks,
    required Map<String, int> allPoints,
    required String currentPlayerId,
    required List<String> allPlayerIds,
  }) {
    final target = dart.target;
    final multiplier = dart.multiplier;
    final isCutThroat = config.cutThroat ?? false;

    // MISS o numero non valido
    if (target == 0 || multiplier == 0 || !isValidCricketNumber(target)) {
      return (currentScore, 0, false, false, true);
    }

    final marks = allMarks[currentPlayerId] ?? {};
    final currentMarksOnTarget = marks[target] ?? 0;

    // Numero è già chiuso dal giocatore (3+ marks) - niente nuovi marks
    if (currentMarksOnTarget >= 3) {
      return (currentScore, 0, false, false, true);
    }

    // Calcola nuovi marks (max 3)
    final newMarks = (currentMarksOnTarget + multiplier).clamp(0, 3);
    final marksAdded = newMarks - currentMarksOnTarget;

    // PUNTEGGIO: solo se il giocatore ha aperto il numero (3 marks totali)
    // E l'avversario NON lo ha ancora chiuso
    final bool playerHasNumber = (currentMarksOnTarget + marksAdded) >= 3;
    final bool opponentHasClosed = _isNumberClosedByOpponent(
        allMarks,
        target,
        currentPlayerId
    );

    int pointsScored = 0;
    if (playerHasNumber && !opponentHasClosed && !isCutThroat) {
      // Standard Cricket: punti al giocatore
      pointsScored = getNumberValue(target) * multiplier;
    } else if (playerHasNumber && !opponentHasClosed && isCutThroat) {
      // Cut Throat: punti agli avversari!
      // In questo caso il dardo non aggiunge punti AL GIOCATORE
      // I punti verranno distribuiti agli avversari separatamente
      pointsScored = 0;
    }

    final int newScore = currentScore + pointsScored;

    // Verifica vittoria (immediata - regole ufficiali)
    final bool isCheckout = _checkVictory(
      allMarks,
      allPoints,
      currentPlayerId,
      isCutThroat,
    );

    return (newScore, pointsScored, false, isCheckout, true);
  }

  /// Verifica se un numero è chiuso da TUTTI gli altri giocatori
  static bool _isNumberClosedByOpponent(
      Map<String, Map<int, int>> allMarks,
      int target,
      String currentPlayerId
      ) {
    for (final entry in allMarks.entries) {
      if (entry.key == currentPlayerId) continue;
      final playerMarks = entry.value[target] ?? 0;
      if (playerMarks < 3) return false; // Almeno un avversario NON ha chiuso
    }
    return true;
  }

  /// Verifica vittoria secondo le regole ufficiali:
  /// - Tutti i numeri devono essere chiusi (3+ marks)
  /// - Standard Cricket: nessun avversario deve avere PUNTEGGIO SUPERIORE
  /// - Cut Throat: nessun avversario deve avere PUNTEGGIO INFERIORE
  /// - In caso di parità, vince chi ha chiuso per primo (quindi il giocatore corrente)
  static bool _checkVictory(
      Map<String, Map<int, int>> allMarks,
      Map<String, int> allPoints,
      String playerId,
      bool isCutThroat,
      ) {
    final myMarks = allMarks[playerId] ?? {};

    // 1. Verifica se TUTTI i numeri sono chiusi (3+ marks)
    for (final number in cricketNumbers) {
      if ((myMarks[number] ?? 0) < 3) return false;
    }

    // 2. Tutti i numeri chiusi - verifica punteggio
    final myPoints = allPoints[playerId] ?? 0;

    for (final entry in allPoints.entries) {
      if (entry.key == playerId) continue;

      if (isCutThroat) {
        // Cut Throat: perdi se un avversario ha MENO punti di te
        // Il pareggio è a favore di chi ha chiuso per primo
        if (entry.value < myPoints) return false;
      } else {
        // Standard Cricket: perdi se un avversario ha PIÙ punti di te
        // Il pareggio è a favore di chi ha chiuso per primo
        if (entry.value > myPoints) return false;
      }
    }

    return true;
  }

  static Map<String, Map<int, int>> initializeMarks(List<String> playerIds) {
    final marks = <String, Map<int, int>>{};
    for (final playerId in playerIds) {
      marks[playerId] = {for (final n in cricketNumbers) n: 0};
    }
    return marks;
  }

  static Map<String, int> initializePoints(List<String> playerIds) {
    return {for (final playerId in playerIds) playerId: 0};
  }

  /// Calcola punti per Cut Throat (da aggiungere agli avversari)
  static int calculateCutThroatPoints(int target, int multiplier) {
    return getNumberValue(target) * multiplier;
  }
}