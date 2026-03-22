import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/link/app_link_state.dart';
import '../controllers/lobby_controller.dart';
import 'room_lobby_shell_page.dart';

class RoomLobbyShellPageWrapper extends ConsumerStatefulWidget {
  final String? roomId;

  const RoomLobbyShellPageWrapper({
    super.key,
    this.roomId,
  });

  @override
  ConsumerState<RoomLobbyShellPageWrapper> createState() =>
      _RoomLobbyShellPageWrapperState();
}

class _RoomLobbyShellPageWrapperState
    extends ConsumerState<RoomLobbyShellPageWrapper> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final roomId = widget.roomId ??
          ref.read(appLinkCoordinatorProvider.notifier).consumeRoomId();

      if (roomId == null || roomId.isEmpty) return;

      await ref.read(lobbyControllerProvider.notifier).joinFromLink(roomId);
    });

  }

  @override
  Widget build(BuildContext context) {
    return const RoomLobbyShellPage();
  }
}