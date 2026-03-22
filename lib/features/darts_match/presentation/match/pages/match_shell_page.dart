import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../../domain/entities/room.dart';
import '../../result/controllers/result_controller.dart';
import '../../result/pages/result_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/match_controller.dart';
import '../../../domain/entities/match.dart';
class MatchShellPage extends ConsumerStatefulWidget {
  const MatchShellPage({
    super.key,
    required this.match,
    required this.isOnline,
    required this.canPlay,
  });

  final Match match;
  final bool isOnline;
  final bool canPlay;

  @override
  ConsumerState<MatchShellPage> createState() => _MatchShellPageState();
}
class _MatchShellPageState extends ConsumerState<MatchShellPage> {
  int _input = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(matchControllerProvider.notifier).bindMatch(
        match: widget.match,
        isOnline: widget.isOnline,
      );
    });
  }
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
          if (ref.read(lobbyControllerProvider.notifier).isCurrentUserHost)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final lobby = ref.read(lobbyControllerProvider.notifier);
                if (value == 'restart') {
                  await lobby.reopenRoomFromResult();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomLobbyShellPage()),
                    (r) => false,
                  );
                }
                if (value == 'close') {
                  await lobby.closeRoom();
                  if (!mounted) return;
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restart', child: Text('Torna alla room')),
                PopupMenuItem(value: 'close', child: Text('Chiudi room')),
              ],
            ),
          ConnectionBadge(
            vm: ConnectionBadgeVm(isOnline: vm.isOnline),
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
                  if (!widget.canPlay)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Partita iniziata: modalità spettatore'),
                    ),
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
                          onPressed: widget.canPlay
                              ? () {
                            setState(() {
                              final nextText = '$_input$i';
                              _input = int.tryParse(nextText) ?? 0;
                              if (_input > 180) _input = 180;
                            });
                          }
                              : null,
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
                          onPressed: widget.canPlay ? () => setState(() => _input = 0) : null,
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.canPlay
                              ? () async => ref.read(matchControllerProvider.notifier).undoLastTurn()
                              : null,
                          child: const Text('Undo ultimo turno'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: widget.canPlay ? () async {
                            await ref.read(matchControllerProvider.notifier).submitTurn(_input);
                            final after = ref.read(matchControllerProvider)?.match;
                            setState(() => _input = 0);
                            if (after != null && after.snapshot.scoreboard.playerScores.values.any((s) => s == 0)) {
                              final winner = after.snapshot.scoreboard.playerScores.entries.firstWhere((e) => e.value == 0).key;
                              await ref.read(lobbyControllerProvider.notifier).markRoomTerminated();
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
                          } : null,
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
