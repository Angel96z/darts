import 'package:flutter/material.dart';
import 'games_darts.dart';
import 'room_data.dart';

class RoomMatchEngineView extends StatelessWidget {
  final RoomData data;

  const RoomMatchEngineView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // NON ATTIVO
    if (data.phase != RoomPhase.match) {
      return const Center(
        child: Text('ENGINE NON ATTIVO'),
      );
    }

    // ATTIVO
    return ListView(
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
    );
  }
}