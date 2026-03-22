import '../data/repositories/room_repository.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class UpdateConfigUseCase {
  UpdateConfigUseCase(this._roomRepository);

  final RoomRepository _roomRepository;

  Future<UseCaseResult<RoomConfig>> execute({
    required String roomId,
    required Session actor,
    required RoomConfig nextConfig,
  }) async {
    try {
      await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }
        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!PermissionPolicy.canEditConfig(room: room, actor: actor)) {
          throw UseCaseException('Not allowed');
        }
        tx.update(roomRef, {'config': nextConfig.toMap()});
      });

      return UseCaseResult.success(nextConfig);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
