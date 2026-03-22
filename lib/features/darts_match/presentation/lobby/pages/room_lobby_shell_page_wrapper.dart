import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/lobby_controller.dart';
import 'room_lobby_shell_page.dart';

class RoomLobbyShellPageWrapper extends ConsumerStatefulWidget {
  final String roomId;

  const RoomLobbyShellPageWrapper({
    super.key,
    required this.roomId,
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
      await ref
          .read(lobbyControllerProvider.notifier)
          .joinFromLink(widget.roomId);
    });

  }

  @override
  Widget build(BuildContext context) {
    return const RoomLobbyShellPage();
  }
}