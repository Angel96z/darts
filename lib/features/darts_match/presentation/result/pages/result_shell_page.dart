import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../controllers/result_controller.dart';

class ResultShellPage extends ConsumerWidget {
  const ResultShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultControllerProvider);
    final lobby = ref.read(lobbyControllerProvider.notifier);
    final isHost = lobby.isCurrentUserHost;
    return Scaffold(
      appBar: AppBar(title: const Text('Risultato')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: result == null
            ? const Center(child: Text('Risultato non disponibile'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vincitore: ${result.winnerId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Highest score: ${result.highestScore}'),
                  Text('Average: ${result.average}'),
                  const SizedBox(height: 16),
                  const Text('Placeholder salvataggio statistiche completato'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await lobby.reopenRoomFromResult();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const RoomLobbyShellPage()),
                          (r) => false,
                        );
                      },
                      child: const Text('Nuova partita (stessa room)'),
                    ),
                  ),
                  if (isHost) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await lobby.closeRoom();
                          if (!context.mounted) return;
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: const Text('Chiudi room'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      child: const Text('Torna home'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
