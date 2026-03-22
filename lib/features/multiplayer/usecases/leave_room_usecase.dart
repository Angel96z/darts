import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repositories/room_repository.dart';
import '../data/repositories/user_room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'usecase_result.dart';

class LeaveRoomUseCase {
  LeaveRoomUseCase(this._roomRepository, this._userRoomRepository);

  final RoomRepository _roomRepository;
  final UserRoomRepository _userRoomRepository;

  Future<UseCaseResult<void>> execute({required String roomId, required Session actor}) async {
    try {
      await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          return;
        }

        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        final actorParticipant = room.participants[actor.participantId];
        if (actorParticipant == null) {
          return;
        }

        final updates = <String, dynamic>{'participants.${actor.participantId}': FieldValue.delete()};
        for (final participant in room.participants.values) {
          if (participant.ownerParticipantId == actor.participantId) {
            updates['participants.${participant.participantId}'] = FieldValue.delete();
          }
        }

        if (actorParticipant.role == RoomRole.host) {
          updates['status'] = RoomStatus.closed.name;
        }

        tx.update(roomRef, updates);
      });

      await _userRoomRepository.clear(actor.authUid);
      return const UseCaseResult.success(null);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
