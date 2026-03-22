import 'package:uuid/uuid.dart';

import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class AddLocalGuestUseCase {
  AddLocalGuestUseCase(this._roomRepository, this._uuid);

  final RoomRepository _roomRepository;
  final Uuid _uuid;

  Future<UseCaseResult<RoomParticipant>> execute({
    required String roomId,
    required Session actor,
    required String guestName,
  }) async {
    try {
      final guest = await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }

        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!PermissionPolicy.canAddPlayer(room: room, actor: actor)) {
          throw UseCaseException('Not allowed');
        }
        if (room.players.length >= room.config.maxPlayers) {
          throw UseCaseException('Player limit reached');
        }

        final participant = RoomParticipant(
          participantId: _uuid.v4(),
          displayName: guestName,
          role: RoomRole.player,
          type: ParticipantType.localGuest,
          ownerParticipantId: actor.participantId,
          joinedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        );

        tx.update(roomRef, {'participants.${participant.participantId}': participant.toMap()});
        return participant;
      });

      return UseCaseResult.success(guest);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
