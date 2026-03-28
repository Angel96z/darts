/// File: repositories.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../commands/match_command.dart';
import '../entities/match.dart';
import '../entities/room.dart';
import '../events/match_event.dart';
import '../value_objects/identifiers.dart';

abstract class RoomRepository {
  Stream<Room> watchRoom(RoomId roomId);
  Future<Room?> getRoom(RoomId roomId);
  Future<void> saveRoom(Room room);
}

abstract class MatchRepository {
  Stream<Match> watchMatch(RoomId roomId, MatchId matchId);
  Future<Match?> getMatch(RoomId roomId, MatchId matchId);
  Future<void> saveMatch(Match match);
  Future<void> appendEvent(MatchEvent event);
  Stream<List<MatchEvent>> watchEvents(RoomId roomId, MatchId matchId);
}

abstract class CommandRepository {
  Future<void> enqueue(MatchCommand command);
  Stream<List<MatchCommand>> watchPending(RoomId roomId);
}

abstract class PresenceRepository {
  Stream<RoomPresenceSummary> watchPresence(RoomId roomId);
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> updateHeartbeat({required RoomId roomId, required PlayerId playerId});
}

abstract class StatsRepository {
  Future<void> persistMatchResult({required Match match});
}
