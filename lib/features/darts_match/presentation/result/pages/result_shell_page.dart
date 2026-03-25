import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../../domain/entities/room.dart';
import '../controllers/result_controller.dart';

class ResultShellPage extends ConsumerStatefulWidget {
  const ResultShellPage({super.key});

  @override
  ConsumerState<ResultShellPage> createState() => _ResultShellPageState();
}

class _ResultShellPageState extends ConsumerState<ResultShellPage> {
  bool _routing = false;

  Future<void> _handleRoomState(LobbyViewModel next) async {
    if (!mounted || _routing) return;

    if (next.roomState == RoomState.waiting || next.roomState == RoomState.ready) {
      _routing = true;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoomLobbyShellPage()),
        (route) => false,
      );
      return;
    }

    if (next.roomState == RoomState.closed) {
      _routing = true;
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(resultControllerProvider);
    final lobbyVm = ref.watch(lobbyControllerProvider);
    final lobby = ref.read(lobbyControllerProvider.notifier);
    final isHost = lobby.isCurrentUserHost;

    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _handleRoomState(next);
    });

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Risultato')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: result == null
              ? const Center(child: Text('Risultato non disponibile'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stato room: ${lobbyVm.roomState.name}'),
                    const SizedBox(height: 8),
                    Text('Vincitore: ${result.winnerId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Highest score: ${result.highestScore}'),
                    Text('Average: ${result.average}'),
                    const Spacer(),
                    if (isHost)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => lobby.reopenRoomFromResult(),
                          child: const Text('Riapri lobby'),
                        ),
                      ),
                    if (isHost) const SizedBox(height: 8),
                    if (isHost)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => lobby.markRoomTerminated(),
                          child: const Text('Chiudi room'),
                        ),
                      ),
                    if (!isHost)
                      const Text('Attendi la scelta dell\'host'),
                  ],
                ),
        ),
      ),
    );
  }
}
