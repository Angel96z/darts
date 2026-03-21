import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/match_controller.dart';

class MatchShellPage extends ConsumerWidget {
  const MatchShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(matchControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('X01 Match')),
      body: vm == null
          ? const Center(child: Text('Waiting match snapshot...'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set ${vm.snapshot.currentSet} • Leg ${vm.snapshot.currentLeg} • Turn ${vm.snapshot.currentTurn}'),
                  const SizedBox(height: 12),
                  Text('Match state: ${vm.snapshot.matchState.name}'),
                  Text('Status: ${vm.snapshot.status.name}'),
                  const SizedBox(height: 12),
                  Text('Active player: ${vm.snapshot.scoreboard.currentTurnPlayerId.value}'),
                  const SizedBox(height: 12),
                  const Text('Current turn darts: [ ] [ ] [ ]'),
                  const SizedBox(height: 12),
                  const Text('Last turns timeline ready for realtime feed.'),
                ],
              ),
            ),
    );
  }
}
