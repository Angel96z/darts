import 'package:flutter/material.dart';
import 'package:darts/features/room_v2/games_darts.dart';
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/core/room_match_engine.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/utils/player_utils.dart';

class RoomInputKeyboard extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomInputKeyboard({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    if (data.phase != RoomPhase.match) {
      return const SizedBox.shrink();
    }

    final player = resolveActiveInputPlayer(data, RoomCurrentUser.current.uid);

    if (player == null || player.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentMode = player['inputMode'] ?? 'dart';
    final canSwitch = canSwitchInputMode(player);

    return Column(
      children: [
        const Divider(),
        Text('INPUT (${player['name']})'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'dart', label: Text('DART')),
            ButtonSegment(value: 'total', label: Text('TOTAL')),
          ],
          selected: {currentMode},
          onSelectionChanged: canSwitch
              ? (set) async {
            final newMode = set.first;

            final updated = copyWithPlayerInputMode(
              data,
              player['id'],
              newMode,
            );
            await repo.update(updated);
          }
              : null,
        ),
        const SizedBox(height: 8),
        if (data.game.type == GameType.cricket) ...[
          _CricketKeyboard(data: data, repo: repo, player: player),
        ] else ...[
          if (currentMode == 'dart')
            _DartKeyboard(data: data, repo: repo, player: player),
          if (currentMode == 'total')
            _TotalKeyboard(data: data, repo: repo, player: player),
        ]
      ],
    );
  }
}

class _DartKeyboard extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _DartKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  State<_DartKeyboard> createState() => _DartKeyboardState();
}

class _DartKeyboardState extends State<_DartKeyboard> {
  int multiplier = 1;

  @override
  Widget build(BuildContext context) {
    final canUndo = canUndoForPlayer(widget.data, widget.player);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: multiplier == 2 ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() {
                  multiplier = (multiplier == 2) ? 1 : 2;
                });
              },
              child: const Text('D'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: multiplier == 3 ? Colors.blue : null,
              ),
              onPressed: () {
                setState(() {
                  multiplier = (multiplier == 3) ? 1 : 3;
                });
              },
              child: const Text('T'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: List.generate(21, (i) {
            final base = i == 20 ? 25 : i + 1;
            final isDisabled = isTripleBullDisabled(multiplier, base);

            return ElevatedButton(
              onPressed: isDisabled ? null : () => _addThrow(base),
              child: Text('$base'),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _addThrow(0),
              child: const Text('MISS'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canUndo ? _undo : null,
              child: const Text('Undo'),
            ),
          ],
        )
      ],
    );
  }

  void _addThrow(int base) async {
    await widget.repo.enqueue(() async {
      final current = widget.repo.current!;

      final intent = {
        'type': 'dart',
        'number': base == 0 ? null : base,
        'multiplier': base == 0 ? 0 : multiplier,
        'isMiss': base == 0,
      };

      final newState = RoomMatchEngineLogic.applyThrow(
        current,
        widget.player['id'],
        intent,
      );

      await widget.repo.update(newState);
    });

    setState(() {
      multiplier = 1;
    });
  }

  void _undo() async {
    await widget.repo.enqueue(() async {
      final newState =
      RoomMatchEngineLogic.undoLastThrow(widget.repo.current!);
      await widget.repo.update(newState);
    });
  }
}
class _CricketKeyboard extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _CricketKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final targets = [20, 19, 18, 17, 16, 15, 25];

    final canUndo = canUndoForPlayer(data, player);

    return Column(
      children: [
        const SizedBox(height: 8),

        ...targets.map((t) {
          final isBull = t == 25;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '$t',
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: 8),

                _btn(t, 1, 'S'),
                const SizedBox(width: 6),
                _btn(t, 2, 'D'),
                if (!isBull) ...[
                  const SizedBox(width: 6),
                  _btn(t, 3, 'T'),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _addThrow(null, 0, true),
              child: const Text('MISS'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: canUndo ? _undo : null,
              child: const Text('UNDO'),
            ),
          ],
        )
      ],
    );
  }

  Widget _btn(int number, int multiplier, String label) {
    return ElevatedButton(
      onPressed: () => _addThrow(number, multiplier, false),
      child: Text(label),
    );
  }

  void _addThrow(int? number, int multiplier, bool isMiss) async {
    await repo.enqueue(() async {
      final current = repo.current!;

      final intent = {
        'type': 'dart',
        'number': number,
        'multiplier': multiplier,
        'isMiss': isMiss,
      };

      final newState = RoomMatchEngineLogic.applyThrow(
        current,
        player['id'],
        intent,
      );

      await repo.update(newState);
    });
  }

  void _undo() async {
    await repo.enqueue(() async {
      final newState =
      RoomMatchEngineLogic.undoLastThrow(repo.current!);
      await repo.update(newState);
    });
  }
}

class _TotalKeyboard extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _TotalKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  State<_TotalKeyboard> createState() => _TotalKeyboardState();
}

class _TotalKeyboardState extends State<_TotalKeyboard> {
  String input = '';

  @override
  Widget build(BuildContext context) {
    final canUndo = widget.data.history.isNotEmpty;

    return Column(
      children: [
        Text('Input: $input'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: List.generate(10, (i) {
            return ElevatedButton(
              onPressed: () => _add(i),
              child: Text('$i'),
            );
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            ElevatedButton(onPressed: _clear, child: const Text('C')),
            ElevatedButton(onPressed: _submit, child: const Text('OK')),
            ElevatedButton(
                onPressed: _checkout, child: const Text('CHECKOUT')),
            ElevatedButton(onPressed: _miss, child: const Text('MISS')),
            ElevatedButton(onPressed: _bust, child: const Text('BUST')),
            ElevatedButton(
                onPressed: canUndo ? _undo : null,
                child: const Text('UNDO')),
          ],
        )
      ],
    );
  }

  void _add(int n) {
    if (canAppendTotalInput(input, n)) {
      setState(() {
        input = input + '$n';
      });
    }
  }

  void _clear() {
    setState(() {
      input = '';
    });
  }

  void _checkout() async {
    await widget.repo.enqueue(() async {
      final intent = {
        'type': 'checkout',
      };

      final newState = RoomMatchEngineLogic.applyIntent(
        widget.repo.current!,
        widget.player['id'],
        intent,
      );

      await widget.repo.update(newState);
    });

    setState(() {
      input = '';
    });
  }

  void _submit() async {
    final value = int.tryParse(input);
    if (value == null) return;

    await widget.repo.enqueue(() async {
      final intent = {
        'type': 'total',
        'value': value,
      };

      final newState = RoomMatchEngineLogic.applyIntent(
        widget.repo.current!,
        widget.player['id'],
        intent,
      );

      await widget.repo.update(newState);
    });

    setState(() {
      input = '';
    });
  }

  void _miss() async {
    await widget.repo.enqueue(() async {
      final intent = {'type': 'miss'};

      final newState = RoomMatchEngineLogic.applyIntent(
        widget.repo.current!,
        widget.player['id'],
        intent,
      );

      await widget.repo.update(newState);
    });
  }

  void _bust() async {
    await widget.repo.enqueue(() async {
      final intent = {'type': 'bust'};

      final newState = RoomMatchEngineLogic.applyIntent(
        widget.repo.current!,
        widget.player['id'],
        intent,
      );

      await widget.repo.update(newState);
    });
  }

  void _undo() async {
    final newState =
    RoomMatchEngineLogic.undoLastThrow(widget.data);
    await widget.repo.update(newState);
  }
}
