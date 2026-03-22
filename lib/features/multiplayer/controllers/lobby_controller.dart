import '../domain/models.dart';
import '../usecases/add_external_guest_usecase.dart';
import '../usecases/add_local_guest_usecase.dart';
import '../usecases/close_room_usecase.dart';
import '../usecases/leave_room_usecase.dart';
import '../usecases/remove_player_usecase.dart';
import '../usecases/start_match_usecase.dart';
import '../usecases/update_config_usecase.dart';
import '../usecases/usecase_result.dart';

class LobbyController {
  LobbyController({
    required AddLocalGuestUseCase addLocalGuest,
    required AddExternalGuestUseCase addExternalGuest,
    required RemovePlayerUseCase removePlayer,
    required UpdateConfigUseCase updateConfig,
    required StartMatchUseCase startMatch,
    required LeaveRoomUseCase leaveRoom,
    required CloseRoomUseCase closeRoom,
  })  : _addLocalGuest = addLocalGuest,
        _addExternalGuest = addExternalGuest,
        _removePlayer = removePlayer,
        _updateConfig = updateConfig,
        _startMatch = startMatch,
        _leaveRoom = leaveRoom,
        _closeRoom = closeRoom;

  final AddLocalGuestUseCase _addLocalGuest;
  final AddExternalGuestUseCase _addExternalGuest;
  final RemovePlayerUseCase _removePlayer;
  final UpdateConfigUseCase _updateConfig;
  final StartMatchUseCase _startMatch;
  final LeaveRoomUseCase _leaveRoom;
  final CloseRoomUseCase _closeRoom;

  Future<UseCaseResult<RoomParticipant>> addLocalGuest(String roomId, Session actor, String name) {
    return _addLocalGuest.execute(roomId: roomId, actor: actor, guestName: name);
  }

  Future<UseCaseResult<RoomParticipant>> addExternalGuest(String roomId, Session actor, String name) {
    return _addExternalGuest.execute(roomId: roomId, actor: actor, guestName: name);
  }

  Future<UseCaseResult<void>> removePlayer(String roomId, Session actor, String participantId) {
    return _removePlayer.execute(roomId: roomId, actor: actor, targetParticipantId: participantId);
  }

  Future<UseCaseResult<RoomConfig>> updateConfig(String roomId, Session actor, RoomConfig config) {
    return _updateConfig.execute(roomId: roomId, actor: actor, nextConfig: config);
  }

  Future<UseCaseResult<MatchSnapshot>> startMatch(String roomId, Session actor) {
    return _startMatch.execute(roomId: roomId, actor: actor);
  }

  Future<UseCaseResult<void>> leaveRoom(String roomId, Session actor) {
    return _leaveRoom.execute(roomId: roomId, actor: actor);
  }

  Future<UseCaseResult<void>> closeRoom(String roomId, Session actor) {
    return _closeRoom.execute(roomId: roomId, actor: actor);
  }

  String inviteLink(String roomId) => 'darts://join/$roomId';
}
