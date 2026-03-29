import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_repository.dart';

class RoomMatchPage extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomMatchPage({
    super.key,
    required this.data,
    required this.repo,
  });

  Future<void> _finishMatch() async {
    await repo.update(data.copyWith(phase: RoomPhase.result));
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Abbandonare la partita?'),
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
          // torna alla lobby SENZA usare Navigator
          await repo.update(data.copyWith(phase: RoomPhase.lobby));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('MATCH IN CORSO'),
              const SizedBox(height: 16),
              Text('Room ID: ${data.roomId ?? "LOCALE"}'),
              Text('STATO: ${data.phase.name}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await _finishMatch();
                },
                child: const Text('Finish match'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}