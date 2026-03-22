import '../data/repositories/room_repository.dart';
import '../data/repositories/user_room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class CloseRoomUseCase {
  CloseRoomUseCase(this._roomRepository, this._userRoomRepository);

  final RoomRepository _roomRepository;
  final UserRoomRepository _userRoomRepository;

  Future<UseCaseResult<void>> execute({required String roomId, required Session actor}) async {
    try {
      final affectedUids = await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }
        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!PermissionPolicy.canCloseRoom(room: room, actor: actor)) {
          throw UseCaseException('Not allowed');
        }
        tx.update(roomRef, {'status': RoomStatus.closed.name});
        return room.participants.values
            .map((p) => p.authUid)
            .whereType<String>()
            .toSet()
            .toList(growable: false);
      });

      for (final uid in affectedUids) {
        await _userRoomRepository.clear(uid);
      }

      return const UseCaseResult.success(null);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
