import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class ReturnToLobbyUseCase {
  ReturnToLobbyUseCase(this._roomRepository);

  final RoomRepository _roomRepository;

  Future<UseCaseResult<void>> execute({required String roomId, required Session actor}) async {
    try {
      await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }
        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!PermissionPolicy.canCloseRoom(room: room, actor: actor)) {
          throw UseCaseException('Not allowed');
        }
        tx.update(roomRef, {
          'status': RoomStatus.waiting.name,
          'currentMatchId': null,
        });
      });
      return const UseCaseResult.success(null);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
