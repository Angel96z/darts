import '../../domain/entities/room.dart';
import '../../domain/value_objects/identifiers.dart';
import '../dto/room_dto.dart';

class RoomMapper {
  const RoomMapper();

  Room toDomain(RoomDto dto) {
    ConnectionState parseConnection(String raw) {
      return ConnectionState.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => ConnectionState.connected,
      );
    }

    return Room(
      id: RoomId(dto.roomId),
      state: RoomState.values.firstWhere(
        (state) => state.name == dto.state,
        orElse: () => RoomState.waiting,
      ),
      hostPlayerId: PlayerId(dto.hostId),
      members: dto.members
          .map(
            (raw) => RoomMember(
              playerId: PlayerId((raw['playerId'] ?? '') as String),
              displayName: (raw['displayName'] ?? 'Player') as String,
              connectionState: parseConnection((raw['connectionState'] ?? 'connected') as String),
              lastSeen: (raw['lastSeen'] as num?) == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch((raw['lastSeen'] as num).toInt()),
              isHost: (raw['isHost'] as bool?) ?? false,
            ),
          )
          .toList(),
      guests: dto.guests
          .map(
            (raw) => RoomGuest(
              guestId: PlayerId((raw['guestId'] ?? '') as String),
              name: (raw['name'] ?? 'Guest') as String,
              createdBy: PlayerId((raw['createdBy'] ?? '') as String),
            ),
          )
          .toList(),
      invite: InviteInfo(
        code: (dto.invite['code'] ?? '') as String,
        link: (dto.invite['link'] ?? '') as String,
        expiresAt: DateTime.tryParse((dto.invite['expiresAt'] ?? '') as String),
      ),
      currentMatchId: dto.currentMatchId == null ? null : MatchId(dto.currentMatchId!),
      createdAt: dto.createdAt,
    );
  }

  RoomDto toDto(Room room) {
    return RoomDto(
      roomId: room.id.value,
      state: room.state.name,
      hostId: room.hostPlayerId.value,
      createdAt: room.createdAt,
      currentMatchId: room.currentMatchId?.value,
      members: room.members
          .map(
            (member) => {
              'playerId': member.playerId.value,
              'displayName': member.displayName,
              'connectionState': member.connectionState.name,
              'lastSeen': member.lastSeen?.millisecondsSinceEpoch,
              'isHost': member.isHost,
              'ownerUid': member.playerId.value,
            },
          )
          .toList(),
      guests: room.guests
          .map(
            (guest) => {
              'guestId': guest.guestId.value,
              'name': guest.name,
              'createdBy': guest.createdBy.value,
            },
          )
          .toList(),
      invite: {
        'code': room.invite.code,
        'link': room.invite.link,
        'expiresAt': room.invite.expiresAt?.toIso8601String(),
      },
    );
  }
}
