import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/room.dart';
import '../../result/controllers/result_controller.dart';
import '../../result/pages/result_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/match_controller.dart';

class MatchShellPage extends ConsumerStatefulWidget {
  const MatchShellPage({super.key});

  @override
  ConsumerState<MatchShellPage> createState() => _MatchShellPageState();
}

class _MatchShellPageState extends ConsumerState<MatchShellPage> {
  int _input = 0;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(matchControllerProvider);
    if (vm == null) {
      return const Scaffold(body: Center(child: Text('Waiting match snapshot...')));
    }

    final match = vm.match;
    final active = match.snapshot.scoreboard.currentTurnPlayerId;
    final players = match.roster.players;

    return Scaffold(
      appBar: AppBar(
        title: Text('Match ${match.config.variant.name.toUpperCase()}'),
        actions: [
          ConnectionBadge(
            vm: ConnectionBadgeVm(
              state: vm.isOnline ? ConnectionState.connected : ConnectionState.disconnected,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text('Set ${match.snapshot.currentSet} • Leg ${match.snapshot.currentLeg}')),
                  Text('Turno ${match.snapshot.currentTurn}'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final p = players[index];
                  final score = match.snapshot.scoreboard.playerScores[p.playerId] ?? match.config.startScore;
                  final isActive = p.playerId == active;
                  return Card(
                    child: ListTile(
                      title: Text(p.playerId.value),
                      subtitle: Text(isActive ? 'Turno attivo' : 'In attesa'),
                      trailing: Text(
                        '$score',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Column(
                children: [
                  Text('Input: $_input', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      10,
                      (i) => SizedBox(
                        width: 64,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              final nextText = '$_input$i';
                              _input = int.tryParse(nextText) ?? 0;
                              if (_input > 180) _input = 180;
                            });
                          },
                          child: Text('$i'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _input = 0),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async => ref.read(matchControllerProvider.notifier).undoLastTurn(),
                          child: const Text('Undo ultimo turno'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await ref.read(matchControllerProvider.notifier).submitTurn(_input);
                            final after = ref.read(matchControllerProvider)?.match;
                            setState(() => _input = 0);
                            if (after != null && after.snapshot.scoreboard.playerScores.values.any((s) => s == 0)) {
                              final winner = after.snapshot.scoreboard.playerScores.entries.firstWhere((e) => e.value == 0).key;
                              ref.read(resultControllerProvider.notifier).setResult(
                                    winnerId: winner.value,
                                    highestScore: 180,
                                    average: 60,
                                  );
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ResultShellPage()),
                                );
                              }
                            }
                          },
                          child: const Text('Submit turno'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
