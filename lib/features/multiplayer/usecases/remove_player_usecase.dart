import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/repositories/room_repository.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class RemovePlayerUseCase {
  RemovePlayerUseCase(this._roomRepository);

  final RoomRepository _roomRepository;

  Future<UseCaseResult<void>> execute({
    required String roomId,
    required Session actor,
    required String targetParticipantId,
  }) async {
    try {
      await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }
        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        final target = room.participants[targetParticipantId];
        if (target == null) {
          return;
        }
        if (!PermissionPolicy.canRemovePlayer(room: room, actor: actor, target: target)) {
          throw UseCaseException('Not allowed');
        }

        tx.update(roomRef, {'participants.$targetParticipantId': FieldValue.delete()});
      });

      return const UseCaseResult.success(null);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
