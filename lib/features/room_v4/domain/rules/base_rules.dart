// TARGET: Regole base del gioco delle freccette (comuni a X01 e Cricket)
// LOGIC GOAL: Gestire turni, round, leg, set in modo deterministico
// REACTION: Fornisce dati puri per la UI
// ERROR STRATEGY: Restituisce null se operazione impossibile
// ANTI-REGRESSION: Mantenere calcolo ordine turni, progresso leg/set

import 'package:flutter/foundation.dart';

import '../models/leg.dart';
import '../models/player_turn.dart';
import '../models/set.dart';      // 🆕 Aggiunto
import '../models/match.dart';    // 🆕 Aggiunto


@immutable
class BaseRules {
  /// Calcola l'ordine dei turni (supporta team)
  static List<String> calculateTurnOrder(List<String> playerIds, int teamSize) {
    if (teamSize <= 1) return List.from(playerIds);

    final teams = <List<String>>[];
    for (int i = 0; i < playerIds.length; i += teamSize) {
      teams.add(playerIds.sublist(i, i + teamSize.clamp(0, playerIds.length - i)));
    }

    final order = <String>[];
    for (int i = 0; i < teamSize; i++) {
      for (final team in teams) {
        if (i < team.length) {
          order.add(team[i]);
        }
      }
    }
    return order;
  }
  /// Restituisce il giocatore che deve iniziare il leg
  static String getStartingPlayerForLeg(int legNumber, List<String> playerIds, int teamSize) {
    final order = calculateTurnOrder(playerIds, teamSize);
    // legNumber parte da 1
    // leg 1 → order[0], leg 2 → order[1], leg 3 → order[2], leg 4 → order[0], ...
    final index = (legNumber - 1) % order.length;
    return order[index];
  }

  /// Ottiene il prossimo giocatore nell'ordine dei turni
  static String? getNextPlayer(String currentPlayerId, List<String> playerIds, int teamSize) {
    final order = calculateTurnOrder(playerIds, teamSize);
    final currentIndex = order.indexOf(currentPlayerId);
    if (currentIndex == -1) return null;
    final nextIndex = (currentIndex + 1) % order.length;
    return order[nextIndex];
  }

  /// Calcola il numero del prossimo turno (GLOBALE)
  static int getNextTurnNumber(List<PlayerTurn> allTurns) {
    // Il prossimo turno è semplicemente la lunghezza + 1
    return allTurns.length + 1;
  }

  /// Verifica se un leg è completo (qualcuno ha vinto)
  static bool isLegComplete(Leg leg, int legsToWin) {
    if (leg.winnerId != null) return true;

    // Conta quanti leg ha vinto ogni giocatore in questo set
    // (implementazione nel contesto del set)
    return false;
  }

  /// Verifica se un set è completo
  static bool isSetComplete(Set set, int setsToWin) {
    if (set.winnerId != null) return true;
    return false;
  }

  /// Verifica se il match è completo
  static bool isMatchComplete(Match match, int setsToWin) {
    if (match.winnerId != null) return true;
    return false;
  }

  /// Calcola il round corrente in base al turnNumber globale
  /// Round = ((turnNumber - 1) ~/ numeroGiocatori) + 1
  static int calculateCurrentRound(int currentTurnNumber, int playerCount) {
    if (playerCount == 0) return 1;
    return ((currentTurnNumber - 1) ~/ playerCount) + 1;
  }

}