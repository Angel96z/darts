import '../../domain/entities/room.dart';
import '../../domain/value_objects/identifiers.dart';
import '../dto/room_dto.dart';

class RoomMapper {
  const RoomMapper();

  Room toDomain(RoomDto dto) {
    return Room(
      id: RoomId(dto.roomId),
      state: RoomState.values.firstWhere((e) => e.name == dto.state),
      hostPlayerId: PlayerId(dto.hostId),
      members: const [],
      guests: const [],
      invite: const InviteInfo(code: '', link: '', expiresAt: null),
      currentMatchId: null,
      createdAt: dto.createdAt,
    );
  }

  RoomDto toDto(Room room) {
    return RoomDto(
      roomId: room.id.value,
      state: room.state.name,
      hostId: room.hostPlayerId.value,
      createdAt: room.createdAt,
    );
  }
}
