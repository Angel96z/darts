// TARGET: Logica pura del gioco (calcolo turni)
// LOGIC GOAL: Determinare ordine e prossimo giocatore
// REACTION: UI chiama queste funzioni
// ERROR STRATEGY: Restituisce null se errore
// ANTI-REGRESSION: Mantenere calculateTurnOrder e getNextPlayer

import '../domain/models/player_turn.dart';

// TARGET: Logica pura del gioco (calcolo turni)
// LOGIC GOAL: Determinare ordine e prossimo giocatore
// REACTION: UI chiama queste funzioni
// ERROR STRATEGY: Restituisce null se errore
// ANTI-REGRESSION: Mantenere calculateTurnOrder e getNextPlayer

import '../domain/models/player_turn.dart';

List<String> calculateTurnOrder(List<String> playerIds, int teamSize) {
  if (teamSize <= 1) return List.from(playerIds);

  final teams = <List<String>>[];
  for (int i = 0; i < playerIds.length; i += teamSize) {
    teams.add(playerIds.sublist(i, i + teamSize));
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

String? getNextPlayer(String currentPlayerId, List<String> playerIds, int teamSize) {
  final order = calculateTurnOrder(playerIds, teamSize);
  final currentIndex = order.indexOf(currentPlayerId);
  if (currentIndex == -1) return null;
  final nextIndex = (currentIndex + 1) % order.length;
  return order[nextIndex];
}

/// 🔥 PROSSIMO TURNO GLOBALE - non serve più playerId
int getNextTurnNumber(List<PlayerTurn> allTurns) {
  return allTurns.length + 1;
}
