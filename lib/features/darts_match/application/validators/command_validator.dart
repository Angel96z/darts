/// File: command_validator.dart. Contiene codice Dart del progetto.

import '../../domain/commands/match_command.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/room.dart';

class CommandValidator {
  const CommandValidator();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool validate({required MatchCommand command, required Room room, Match? match}) {
    if (room.state == RoomState.closed) return false;
    if (command is StartMatchCommand) {
      return room.hostPlayerId == command.authorId && room.state == RoomState.locked;
    }
    if (command is SubmitTurnCommand && match != null) {
      return match.snapshot.scoreboard.currentTurnPlayerId == command.authorId;
    }
    return true;
  }
}
