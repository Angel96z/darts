/// File: room_lobby_shell_page_wrapper.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_lobby_shell_page.dart';

class RoomLobbyShellPageWrapper extends ConsumerStatefulWidget {
  final String? roomId;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomLobbyShellPageWrapper({
    super.key,
    this.roomId,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  ConsumerState<RoomLobbyShellPageWrapper> createState() =>
      _RoomLobbyShellPageWrapperState();
}

class _RoomLobbyShellPageWrapperState
    extends ConsumerState<RoomLobbyShellPageWrapper> {

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    return const RoomLobbyShellPage();
  }
}
