/// File: result_shell_page.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../../domain/entities/room.dart';
import '../controllers/result_controller.dart';

class ResultShellPage extends ConsumerStatefulWidget {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const ResultShellPage({super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  ConsumerState<ResultShellPage> createState() => _ResultShellPageState();
}

class _ResultShellPageState extends ConsumerState<ResultShellPage> {
  bool _routing = false;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _handleRoomState(LobbyViewModel next) async {
    if (!mounted || _routing) return;

    if (next.roomState == RoomState.waiting || next.roomState == RoomState.ready) {
      _routing = true;
      await Navigator.pushAndRemoveUntil(
        context,
        /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final result = ref.watch(resultControllerProvider);
    final lobbyVm = ref.watch(lobbyControllerProvider);
    final lobby = ref.read(lobbyControllerProvider.notifier);
    final canControlAdmin = lobby.canCurrentAuthControlAsAdmin;

    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _handleRoomState(next);
    });

    /// Funzione: descrive in modo semplice questo blocco di logica.
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
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    Text('Stato room: ${lobbyVm.roomState.name}'),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    const SizedBox(height: 8),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    Text('Vincitore: ${result.winnerId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    const SizedBox(height: 8),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    Text('Highest score: ${result.highestScore}'),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    Text('Average: ${result.average}'),
                    /// Funzione: descrive in modo semplice questo blocco di logica.
                    const Spacer(),
                    if (canControlAdmin)
                      /// Funzione: descrive in modo semplice questo blocco di logica.
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => lobby.reopenRoomFromResult(),
                          child: const Text('Riapri lobby'),
                        ),
                      ),
                    if (canControlAdmin) const SizedBox(height: 8),
                    if (canControlAdmin)
                      /// Funzione: descrive in modo semplice questo blocco di logica.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => lobby.markRoomTerminated(),
                          child: const Text('Chiudi room'),
                        ),
                      ),
                    if (!canControlAdmin)
                      const Text('Attendi la scelta dell\'host'),
                  ],
                ),
        ),
      ),
    );
  }
}
