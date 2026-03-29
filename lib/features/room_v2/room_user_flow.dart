/// Obiettivo: definire in modo STUPIDO e chiaro dove deve stare l’utente.
/// Responsabilità: dato lo stato della room, decide la schermata.
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/room_lobby_v2_page.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:darts/features/room_v2/room_result_page.dart';
import 'package:flutter/material.dart';
import 'room_match_page.dart';

enum RoomUserLocation {
  lobby,
  match,
  result,
}

class RoomGate extends StatelessWidget {
  final RoomRepository repo;

  const RoomGate({
    super.key,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoomData>(
      stream: repo.watch(),
      initialData: repo.current,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;

        final location = resolveUserLocation(RoomState(
          roomId: data.roomId,
          phase: data.phase,
        ));

        switch (location) {
          case RoomUserLocation.lobby:
            return RoomLobbyV2Page(
              data: data,
              repo: repo,
            );
          case RoomUserLocation.match:
            return RoomMatchPage(
              data: data,
              repo: repo,
            );
          case RoomUserLocation.result:
            return RoomResultPage(
              data: data,
              repo: repo,
            );
        }
      },
    );
  }
}

/// Stato minimo della room.
/// UNA sola fonte di verità.
class RoomState {
  final String? roomId;
  final RoomPhase phase;

  const RoomState({
    required this.roomId,
    required this.phase,
  });
}

/// Obiettivo: funzione pura.
/// Input: stato room
/// Output: dove deve andare l’utente
RoomUserLocation resolveUserLocation(RoomState state) {
  switch (state.phase) {
    case RoomPhase.match:
      return RoomUserLocation.match;
    case RoomPhase.result:
      return RoomUserLocation.result;
    case RoomPhase.lobby:
      return RoomUserLocation.lobby;
  }
}