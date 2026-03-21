import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/lobby_controller.dart';

class RoomLobbyShellPage extends ConsumerWidget {
  const RoomLobbyShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(lobbyControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Room Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room state: ${vm.roomState.name}'),
            Text('Connection: ${vm.connection.name}'),
            const SizedBox(height: 16),
            const Text('Flow: join → login/resume → guest → order → teams → config → lock → start'),
          ],
        ),
      ),
    );
  }
}
