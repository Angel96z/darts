import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/room.dart';

class LobbyViewModel {
  const LobbyViewModel({required this.roomState, required this.connection});

  final RoomState roomState;
  final ConnectionState connection;
}

class LobbyController extends StateNotifier<LobbyViewModel> {
  LobbyController() : super(const LobbyViewModel(roomState: RoomState.waiting, connection: ConnectionState.connected));

  void setRoomState(RoomState state) {
    this.state = LobbyViewModel(roomState: state, connection: this.state.connection);
  }
}

final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController());
