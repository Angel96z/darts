import 'package:darts/features/room_v2/room_match_engine_logic.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:flutter/material.dart';
import 'games_darts.dart';
import 'room_current_user.dart';
import 'room_data.dart';

class RoomMatchEngineView extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomMatchEngineView({
    super.key,
    required this.data,
    required this.repo,
  });
  Widget? _buildWinnerOverlay(BuildContext context) {
    final uid = RoomCurrentUser.current.uid;
    final isTeam = data.teamSize > 1;

    bool hasWinner = false;
    bool isLocalWinner = false;

    if (isTeam) {
      final teams = data.buildTeams();

      List<Map<String, dynamic>>? winningTeam;

      for (final team in teams) {
        final sets = (team.first['sets'] ?? 0) as int;
        if (sets >= data.matchConfig.setsToWin) {
          winningTeam = team;
          hasWinner = true;
          break;
        }
      }

      if (!hasWinner || winningTeam == null) return null;

      isLocalWinner = winningTeam.any((p) {
        return p['id'] == uid || p['ownerId'] == uid;
      });

      if (!isLocalWinner) return null;

      final names = winningTeam.map((p) => p['name']).join(', ');

      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TEAM VINCENTE', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(names, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final newState =
                            RoomMatchEngineLogic.undo(data);
                            await repo.update(newState);
                          },
                          child: const Text('Undo'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            await repo.update(
                              data.copyWith(phase: RoomPhase.result),
                            );
                          },
                          child: const Text('Vai ai risultati'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      Map<String, dynamic>? winner;

      for (final p in data.players) {
        final sets = (p['sets'] ?? 0) as int;
        if (sets >= data.matchConfig.setsToWin) {
          winner = p;
          hasWinner = true;
          break;
        }
      }

      if (!hasWinner || winner == null) return null;

      isLocalWinner =
          winner['id'] == uid || winner['ownerId'] == uid;

      if (!isLocalWinner) return null;

      final name = winner['name'] ?? '-';

      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('VINCITORE', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final newState =
                            RoomMatchEngineLogic.undo(data);
                            await repo.update(newState);
                          },
                          child: const Text('Undo'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            await repo.update(
                              data.copyWith(phase: RoomPhase.result),
                            );
                          },
                          child: const Text('Vai ai risultati'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // AUTO NAVIGAZIONE A RISULTATI
    if (data.phase == RoomPhase.result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop(); // esce dal match
        }
      });
    }
    // NON ATTIVO SOLO IN LOBBY
    if (data.phase == RoomPhase.lobby) {
      return const Center(
        child: Text('ENGINE NON ATTIVO'),
      );
    }

    final winnerOverlay = _buildWinnerOverlay(context);
    // ATTIVO
    return Stack(
        children: [
    ListView(
    padding: const EdgeInsets.all(16),
    children: [
        const Text(
          'MATCH ENGINE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Text('Game: ${data.game.type.name}'),
        Text('Mode: ${data.matchConfig.mode.name}'),
        Text('Sets: ${data.matchConfig.setCount}'),
        Text('Legs per set: ${data.matchConfig.legCount}'),

        Text('→ Win sets: ${data.matchConfig.setsToWin}'),
        Text('→ Win legs: ${data.matchConfig.legsToWin}'),
        const SizedBox(height: 16),

        const Text('PLAYERS'),

        const SizedBox(height: 8),

        ...data.players.map((p) {
          final name = p['name'] ?? '-';
          final id = p['id'] ?? '-';
          final order = p['order'] ?? 0;
          final score = p['score'] ?? '-';
          final legs = p['legs'] ?? 0;
          final sets = p['sets'] ?? 0;
          final isTurn = p['turn'] == true;

          final throws = p['throws'] is List
              ? List<int?>.from(p['throws'])
              : <int?>[];

// NUOVO STORICO TURNI
          final historyTurns = data.history is List
              ? data.history
              .where((h) => h['playerId'] == id)
              .toList()
              : [];

// DERIVATO: darts flat dai turni
          final historyDarts = historyTurns
              .expand((t) => List<int?>.from(t['throws'] ?? []))
              .toList();

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name (${isTurn ? "TURN" : ""})'),
                  Text('ID: $id'),
                  Text('Order: $order'),
                  Text('Score: $score'),
                  Text('Legs: $legs | Sets: $sets'),

                  const SizedBox(height: 6),
                  Text(
                    'Current throws: ${throws.map((e) => e?.toString() ?? "null").join(", ")}',
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'Darts history: ${historyDarts.map((e) => e?.toString() ?? "null").join(", ")}',
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'Turns history: ${historyTurns.map((t) {
                      final total = t['total'];
                      final kind = t['endKind'];
                      final mode = t['inputMode'];
                      return '$total ($mode/$kind)';
                    }).join(", ")}',
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        if (data.teamSize > 1) ...[
          const Text('TEAMS'),

          const SizedBox(height: 8),

          ...data.buildTeams().asMap().entries.map((entry) {
            final index = entry.key;
            final teamPlayers = entry.value;

            final teamScore = teamPlayers.fold<int>(
              0,
                  (sum, p) => sum + ((p['score'] ?? 0) as int),
            );

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team ${index + 1}'),
                    Text('Score: $teamScore'),

                    const SizedBox(height: 8),

                    ...teamPlayers.map((p) {
                      return Text(
                        '- ${p['name']} (${p['score']})',
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
    ],
    ),
          if (winnerOverlay != null) winnerOverlay,
        ],
    );
  }


}

