/// Obiettivo: definire in modo STUPIDO e chiaro dove deve stare l’utente.
/// Responsabilità: dato lo stato della room, decide la schermata.
import 'package:darts/features/room_v2/room_result_page.dart';
import 'package:flutter/material.dart';
import 'room_match_page.dart';


enum RoomUserLocation {
  lobby,
  match,
  result,
}

/// Stato minimo della room.
/// UNA sola fonte di verità.
class RoomState {
  final String? roomId; // null = locale, valore = online
  final bool matchStarted;
  final bool matchFinished;

  const RoomState({
    required this.roomId,
    required this.matchStarted,
    required this.matchFinished,
  });
}

/// Obiettivo: funzione pura.
/// Input: stato room
/// Output: dove deve andare l’utente
RoomUserLocation resolveUserLocation(RoomState state) {
  /// 1. match finito → risultati
  if (state.matchFinished) {
    return RoomUserLocation.result;
  }

  /// 2. match iniziato → partita
  if (state.matchStarted) {
    return RoomUserLocation.match;
  }

  /// 3. default → lobby
  return RoomUserLocation.lobby;
}

/// NAVIGAZIONE → MATCH
/// Obiettivo: centralizzare la navigazione.
/// Responsabilità: andare alla pagina match.
void goToMatch(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const RoomMatchPage(roomId: null),
    ),
  );
}

/// NAVIGAZIONE → RESULT
/// Obiettivo: centralizzare la navigazione.
/// Responsabilità: andare alla pagina risultati.
void goToResult(BuildContext context, String? roomId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RoomResultPage(roomId: roomId),
    ),
  );
}