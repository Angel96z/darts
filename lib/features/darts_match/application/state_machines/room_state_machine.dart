/// File: room_state_machine.dart. Contiene codice Dart del progetto.

import '../../domain/entities/room.dart';

class RoomStateMachine {
  const RoomStateMachine();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool canTransition(RoomState from, RoomState to) {
    final map = <RoomState, Set<RoomState>>{
      RoomState.draft: {RoomState.waiting, RoomState.closed},
      RoomState.waiting: {RoomState.ready, RoomState.closed},
      RoomState.ready: {RoomState.locked, RoomState.closed},
      RoomState.locked: {RoomState.inMatch, RoomState.closed},
      RoomState.inMatch: {RoomState.finished, RoomState.closed},
      RoomState.finished: {RoomState.ready, RoomState.closed},
      RoomState.closed: {},
    };
    return map[from]?.contains(to) ?? false;
  }
}
