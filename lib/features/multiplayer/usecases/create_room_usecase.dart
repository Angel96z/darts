import 'package:uuid/uuid.dart';

import '../data/repositories/room_repository.dart';
import '../data/repositories/user_room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'usecase_result.dart';

class CreateRoomUseCase {
  CreateRoomUseCase(this._roomRepository, this._userRoomRepository, this._uuid);

  final RoomRepository _roomRepository;
  final UserRoomRepository _userRoomRepository;
  final Uuid _uuid;

  Future<UseCaseResult<RoomSnapshot>> execute({
    required String hostUid,
    required String hostDisplayName,
    required RoomConfig config,
  }) async {
    try {
      final roomId = _uuid.v4();
      final hostParticipantId = _uuid.v4();
      final hostParticipant = RoomParticipant(
        participantId: hostParticipantId,
        displayName: hostDisplayName,
        role: RoomRole.host,
        type: ParticipantType.authUser,
        authUid: hostUid,
        joinedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      final room = RoomSnapshot(
        roomId: roomId,
        hostUid: hostUid,
        status: RoomStatus.waiting,
        config: config,
        currentMatchId: null,
        participants: {hostParticipantId: hostParticipant},
      );

      await _roomRepository.createRoom(roomId: roomId, room: room);
      await _userRoomRepository.upsert(
        UserRoomRecord(
          uid: hostUid,
          roomId: roomId,
          role: RoomRole.host,
          participantIds: [hostParticipantId],
        ),
      );

      return UseCaseResult.success(room);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
