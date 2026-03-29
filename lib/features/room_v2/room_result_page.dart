import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_repository.dart';

class RoomResultPage extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomResultPage({
    super.key,
    required this.data,
    required this.repo,
  });

  Future<void> _resetToLobby() async {
    await repo.update(data.copyWith(phase: RoomPhase.lobby));
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Uscire dai risultati?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Si'),
          ),
        ],
      ),
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await _confirmExit(context);

        if (ok && context.mounted) {
          // torna alla lobby SENZA Navigator
          await repo.update(data.copyWith(phase: RoomPhase.lobby));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Result'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('RISULTATI'),
              const SizedBox(height: 16),
              Text('Room ID: ${data.roomId ?? "LOCALE"}'),
              Text('STATO: ${data.phase.name}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _resetToLobby();
                },
                child: const Text('Nuova lobby'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}