import '../../domain/commands/match_command.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/room.dart';
import '../../domain/events/match_event.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/value_objects/identifiers.dart';
import '../datasources/firestore/firestore_command_datasource.dart';
import '../datasources/firestore/firestore_match_datasource.dart';
import '../datasources/firestore/firestore_room_datasource.dart';
import '../datasources/rtdb_presence/rtdb_presence_datasource.dart';
import '../dto/command_dto.dart';
import '../mappers/match_mapper.dart';
import '../mappers/room_mapper.dart';

class FirebaseRoomRepository implements RoomRepository {
  FirebaseRoomRepository(this._dataSource, this._mapper);

  final FirestoreRoomDataSource _dataSource;
  final RoomMapper _mapper;

  @override
  Future<Room?> getRoom(RoomId roomId) async {
    final dto = await _dataSource.getRoom(roomId.value);
    return dto == null ? null : _mapper.toDomain(dto);
  }

  @override
  Future<void> saveRoom(Room room) => _dataSource.saveRoom(_mapper.toDto(room));

  @override
  Stream<Room> watchRoom(RoomId roomId) => _dataSource.watchRoom(roomId.value).map(_mapper.toDomain);
}

class FirebaseMatchRepository implements MatchRepository {
  FirebaseMatchRepository(this._dataSource, this._mapper);

  final FirestoreMatchDataSource _dataSource;
  final MatchMapper _mapper;

  @override
  Future<void> appendEvent(MatchEvent event) {
    return _dataSource.appendEvent(
      roomId: event.roomId.value,
      matchId: event.matchId.value,
      eventId: event.eventId.value,
      event: event.payload,
    );
  }

  @override
  Future<Match?> getMatch(RoomId roomId, MatchId matchId) async {
    final dto = await _dataSource.getMatch(roomId.value, matchId.value);
    return dto == null ? null : _mapper.toDomain(dto);
  }

  @override
  Future<void> saveMatch(Match match) => _dataSource.saveMatch(_mapper.toDto(match));

  @override
  Stream<Match> watchMatch(RoomId roomId, MatchId matchId) =>
      _dataSource.watchMatch(roomId.value, matchId.value).map(_mapper.toDomain);

  @override
  Stream<List<MatchEvent>> watchEvents(RoomId roomId, MatchId matchId) {
    return const Stream<List<MatchEvent>>.empty();
  }
}

class FirebaseCommandRepository implements CommandRepository {
  FirebaseCommandRepository(this._dataSource);

  final FirestoreCommandDataSource _dataSource;

  @override
  Future<void> enqueue(MatchCommand command) {
    return _dataSource.enqueue(
      CommandDto(
        commandId: command.commandId.value,
        roomId: command.roomId.value,
        matchId: command.matchId?.value,
        authorId: command.authorId.value,
        type: command.runtimeType.toString(),
        payload: command.payload,
        idempotencyKey: command.idempotencyKey,
        status: command.status.name,
        createdAt: command.createdAt,
      ),
    );
  }

  @override
  Stream<List<MatchCommand>> watchPending(RoomId roomId) => const Stream<List<MatchCommand>>.empty();
}

class FirebasePresenceRepository implements PresenceRepository {
  FirebasePresenceRepository(this._dataSource);

  final RtdbPresenceDataSource _dataSource;

  @override
  Future<void> updateHeartbeat({required RoomId roomId, required PlayerId playerId}) {
    return _dataSource.heartbeat(roomId: roomId.value, playerId: playerId.value);
  }

  @override
  Stream<RoomPresenceSummary> watchPresence(RoomId roomId) {
    return Stream.value(const RoomPresenceSummary(connected: 0, reconnecting: 0, disconnected: 0));
  }
}

class FirebaseStatsRepository implements StatsRepository {
  const FirebaseStatsRepository();

  @override
  Future<void> persistMatchResult({required Match match}) async {}
}
