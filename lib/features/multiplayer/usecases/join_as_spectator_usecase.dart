import 'package:uuid/uuid.dart';

import '../data/repositories/room_repository.dart';
import '../data/repositories/user_room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'usecase_result.dart';

class JoinAsSpectatorUseCase {
  JoinAsSpectatorUseCase(this._roomRepository, this._userRoomRepository, this._uuid);

  final RoomRepository _roomRepository;
  final UserRoomRepository _userRoomRepository;
  final Uuid _uuid;

  Future<UseCaseResult<RoomParticipant>> execute({
    required String roomId,
    required String authUid,
    required String displayName,
  }) async {
    try {
      final participant = await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }

        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!room.config.allowSpectators) {
          throw UseCaseException('Spectators disabled');
        }

        final existing = room.participants.values.where((p) => p.authUid == authUid).toList();
        if (existing.isNotEmpty) {
          return existing.first;
        }

        final newParticipant = RoomParticipant(
          participantId: _uuid.v4(),
          displayName: displayName,
          role: RoomRole.spectator,
          type: ParticipantType.authUser,
          authUid: authUid,
          joinedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        );

        tx.update(roomRef, {'participants.${newParticipant.participantId}': newParticipant.toMap()});
        return newParticipant;
      });

      await _userRoomRepository.upsert(
        UserRoomRecord(
          uid: authUid,
          roomId: roomId,
          role: participant.role,
          participantIds: [participant.participantId],
        ),
      );

      return UseCaseResult.success(participant);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
