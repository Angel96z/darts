import 'package:darts/features/room_v2/core/room_match_engine.dart';
import 'package:darts/features/room_v2/core/room_match_engine_history.dart';
import 'package:darts/features/room_v2/core/room_match_engine_state.dart';
import 'package:darts/features/room_v2/games/cricket_engine.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:darts/features/room_v2/games_darts.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/room_data.dart';

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
    final winner = buildWinnerOverlayData(data, uid);
    if (winner == null) return null;
    final title = winner['title'] as String? ?? '';
    final name = winner['name'] as String? ?? '-';

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
                  Text(title, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final newState = RoomMatchEngineLogic.undoLastThrow(data);
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

          final currentThrows = buildCurrentThrowLabels(p);
          final historyDarts = buildPlayerHistoryDartLabels(data, id);
          final turnsHistory = buildTurnHistoryLabels(data, id);

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
                    'Current throws: ${currentThrows.join(", ")}',
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'Darts history: ${historyDarts.join(", ")}',

                  ),
                  const SizedBox(height: 10),

                  if (data.game.type == GameType.cricket)
                    _CricketPlayerStats(
                      player: p,
                      allPlayers: data.players,
                    ),

                  const SizedBox(height: 6),
                  Text(
                    'Turns history: ${turnsHistory.join(", ")}',
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

          ...buildTeamScoreRows(data).map((entry) {
            final index = (entry['index'] as int?) ?? 0;
            final teamPlayers = List<Map<String, dynamic>>.from(
              entry['players'] ?? const [],
            );
            final teamScore = (entry['score'] as int?) ?? 0;

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

class _CricketPlayerStats extends StatelessWidget {
  final Map<String, dynamic> player;
  final List<Map<String, dynamic>> allPlayers;

  const _CricketPlayerStats({
    required this.player,
    required this.allPlayers,
  });

  static const targets = ['20', '19', '18', '17', '16', '15', '25'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CRICKET'),

        const SizedBox(height: 6),

        ...targets.map((t) {
          final state = buildCricketRowState(
            allPlayers,
            player,
            t,
          );
          final value = state['value'] as int? ?? 0;
          final isClosed = state['isClosed'] == true;
          final canScore = state['canScore'] == true;
          final marksDisplay = List<String>.from(state['marksDisplay'] ?? const []);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(t),
                ),

                const SizedBox(width: 6),

                _marks(marksDisplay),

                const SizedBox(width: 8),

                if (isClosed)
                  const Text('CLOSED', style: TextStyle(color: Colors.grey))
                else if (canScore)
                  const Text('SCORING', style: TextStyle(color: Colors.green)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _marks(List<String> marks) {
    return Row(
      children: marks
          .map((w) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(w),
      ))
          .toList(),
    );
  }
}
