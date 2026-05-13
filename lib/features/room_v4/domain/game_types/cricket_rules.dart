// lib/features/game/domain/game_types/cricket_rules.dart

import 'package:flutter/foundation.dart';
import '../models/dart_throw.dart';
import '../models/game_config.dart';

@immutable
class CricketRules {
  static const List<int> cricketNumbers = [20, 19, 18, 17, 16, 15, 25];

  static bool isValidCricketNumber(int target) => cricketNumbers.contains(target);

  static int getNumberValue(int target) => target == 25 ? 25 : target;

  /// Calcola dardo per Cricket - supporta sia single che team
  static ({int pointsToAssign, List<String> targetsForPoints, int newTotalMarks}) calculateDart({
    required int currentPlayerMarks,
    required int multiplier,
    required int target,
    required Map<String, Map<int, int>> allMarks,
    required String currentPlayerId,
    required List<String> allPlayerIds,
    required bool isCutThroat,
    required bool isTeamMode,
    required Map<String, String> playerToTeam,
  }) {
    // Calcolo marks (max 3)
    final wouldBe = currentPlayerMarks + multiplier;
    final newTotalMarks = wouldBe.clamp(0, 3);
    final excessMarks = wouldBe > 3 ? wouldBe - 3 : 0;

    if (excessMarks == 0) {
      return (pointsToAssign: 0, targetsForPoints: [], newTotalMarks: newTotalMarks);
    }

    final pointsValue = getNumberValue(target);
    final totalPoints = pointsValue * excessMarks;

    // Verifica se TUTTI i giocatori hanno chiuso il numero (globalmente)
    // Verifica se tutti gli AVVERSARI hanno chiuso il numero.
    // ANTI-REGRESSION:
    // - In solo mode non ci sono avversari, quindi il giocatore deve poter segnare punti.
    // - In multiplayer, se tutti gli avversari hanno già chiuso il numero, non si segna.
    final opponentIds = allPlayerIds.where((id) => id != currentPlayerId).toList();

    if (opponentIds.isNotEmpty) {
      bool allOpponentsClosed = true;

      for (final opponentId in opponentIds) {
        if ((allMarks[opponentId]?[target] ?? 0) < 3) {
          allOpponentsClosed = false;
          break;
        }
      }

      if (allOpponentsClosed) {
        return (pointsToAssign: 0, targetsForPoints: [], newTotalMarks: newTotalMarks);
      }
    }

    int pointsToAssign = 0;
    List<String> targetsForPoints = [];

    if (isTeamMode) {
      final currentTeamId = playerToTeam[currentPlayerId]!;

      // Verifica se TUTTI i membri del team corrente hanno chiuso il numero
      bool teamHasNumber = true;
      for (final entry in playerToTeam.entries) {
        if (entry.value == currentTeamId && entry.key != currentPlayerId) {
          if ((allMarks[entry.key]?[target] ?? 0) < 3) {
            teamHasNumber = false;
            break;
          }
        }
      }
      // Anche il giocatore corrente deve avere il numero chiuso (con newTotalMarks)
      if (newTotalMarks < 3) teamHasNumber = false;

      if (teamHasNumber) {
        pointsToAssign = totalPoints;

        if (isCutThroat) {
          // 🔥 TEAM CUT THROAT: punti a tutti gli avversari che NON hanno chiuso
          for (final entry in playerToTeam.entries) {
            if (entry.value != currentTeamId) {
              if ((allMarks[entry.key]?[target] ?? 0) < 3) {
                targetsForPoints.add(entry.key);
              }
            }
          }
        } else {
          // 🔥 TEAM STANDARD: punti al giocatore corrente
          targetsForPoints = [currentPlayerId];
        }
      }
    } else {
      // SINGLE MODE
      final playerHasNumber = newTotalMarks >= 3;

      if (playerHasNumber) {
        pointsToAssign = totalPoints;

        if (isCutThroat) {
          // 🔥 SINGLE CUT THROAT: punti a tutti gli avversari che NON hanno chiuso
          for (final playerId in allPlayerIds) {
            if (playerId != currentPlayerId && (allMarks[playerId]?[target] ?? 0) < 3) {
              targetsForPoints.add(playerId);
            }
          }
        } else {
          // 🔥 SINGLE STANDARD: punti al giocatore corrente
          targetsForPoints = [currentPlayerId];
        }
      }
    }

    return (
    pointsToAssign: pointsToAssign,
    targetsForPoints: targetsForPoints,
    newTotalMarks: newTotalMarks,
    );
  }

  /// Verifica vittoria SINGOLO
  static bool checkVictorySingle({
    required String playerId,
    required Map<String, Map<int, int>> allMarks,
    required Map<String, int> allPoints,
    required bool isCutThroat,
  }) {
    // Verifica che tutti i numeri siano chiusi dal giocatore
    for (final number in cricketNumbers) {
      if ((allMarks[playerId]?[number] ?? 0) < 3) return false;
    }

    final myPoints = allPoints[playerId] ?? 0;

    for (final entry in allPoints.entries) {
      if (entry.key == playerId) continue;
      if (isCutThroat) {
        if (entry.value < myPoints) return false;
      } else {
        if (entry.value > myPoints) return false;
      }
    }
    return true;
  }

  /// Verifica vittoria TEAM
  static bool checkVictoryTeam({
    required String teamId,
    required Map<String, Map<int, int>> allMarks,
    required Map<String, int> teamPoints,
    required Map<String, String> playerToTeam,
    required List<String> allPlayerIds,
    required bool isCutThroat,
  }) {
    // Trova tutti i giocatori del team
    final teamPlayers = playerToTeam.entries
        .where((e) => e.value == teamId)
        .map((e) => e.key)
        .toList();

    // Verifica che TUTTI i giocatori del team abbiano TUTTI i numeri chiusi
    for (final number in cricketNumbers) {
      for (final playerId in teamPlayers) {
        if ((allMarks[playerId]?[number] ?? 0) < 3) return false;
      }
    }

    final myPoints = teamPoints[teamId] ?? 0;
    final allTeamIds = playerToTeam.values.toSet().toList();

    for (final opposingTeamId in allTeamIds) {
      if (opposingTeamId == teamId) continue;
      final opposingPoints = teamPoints[opposingTeamId] ?? 0;

      if (isCutThroat) {
        if (opposingPoints <= myPoints) return false;
      } else {
        if (opposingPoints >= myPoints) return false;
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
}