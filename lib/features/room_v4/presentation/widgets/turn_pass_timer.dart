// TARGET: Widget timer di passaggio turno (3.5 secondi)
// LOGIC GOAL: Mostrare barra di progresso e tempo rimanente
// REACTION: UI reagisce a isWaitingForTurnPass e turnPassProgress

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/room_notifier.dart';

class TurnPassTimer extends ConsumerWidget {
  const TurnPassTimer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWaiting = ref.watch(roomNotifierProvider.select((s) => s.isWaitingForTurnPass));
    final progress  = ref.watch(roomNotifierProvider.select((s) => s.turnPassProgress));

    if (!isWaiting) return const SizedBox.shrink();

    final remaining = (3.5 * (1 - progress)).toInt().toString();

    return Center(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 150,
          maxWidth: 250,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Text(
              '${remaining}s',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,  // ← normale (parte da 0 a 1)
                  backgroundColor: Colors.orange.shade100,
                  color: Colors.orange,
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}