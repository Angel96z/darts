import 'dart:async';

import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';

class RoomViewModel {
  const RoomViewModel({
    required this.roomId,
    required this.status,
    required this.players,
    required this.spectators,
  });

  final String roomId;
  final String status;
  final List<RoomParticipant> players;
  final List<RoomParticipant> spectators;

  static RoomViewModel fromRoom(RoomSnapshot room) {
    return RoomViewModel(
      roomId: room.roomId,
      status: room.status.name,
      players: room.participants.values
          .where((p) => p.role == RoomRole.player || p.role == RoomRole.host)
          .toList(growable: false),
      spectators: room.participants.values.where((p) => p.role == RoomRole.spectator).toList(growable: false),
    );
  }
}

class RoomLiveCoordinator {
  RoomLiveCoordinator(this._roomRepository);

  final RoomRepository _roomRepository;
  StreamSubscription<RoomSnapshot?>? _subscription;

  void bind({
    required String roomId,
    required void Function(RoomViewModel viewModel) onChanged,
    required void Function(Object error) onError,
  }) {
    _subscription?.cancel();
    _subscription = _roomRepository.watchRoom(roomId).listen((room) {
      if (room == null) {
        onError(StateError('Room deleted'));
        return;
      }
      onChanged(RoomViewModel.fromRoom(room));
    }, onError: onError);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
