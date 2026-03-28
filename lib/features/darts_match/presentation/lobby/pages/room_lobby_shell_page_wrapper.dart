import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Widget build(BuildContext context) {
    return const RoomLobbyShellPage();
  }
}