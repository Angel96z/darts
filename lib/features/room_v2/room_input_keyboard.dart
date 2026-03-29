import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_match_engine_logic.dart';
import 'room_repository.dart';
import 'room_current_user.dart';

class RoomInputKeyboard extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomInputKeyboard({
    super.key,
    required this.data,
    required this.repo,
  });

  Map<String, dynamic>? _getCurrentPlayer() {
    final uid = RoomCurrentUser.current.uid;

    return data.players.firstWhere(
          (p) =>
      p['turn'] == true &&
          (p['ownerId'] == uid || p['id'] == uid),
      orElse: () => {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.phase != RoomPhase.match) {
      return const SizedBox.shrink();
    }

    final player = _getCurrentPlayer();

    if (player == null || player.isEmpty) {
      return const SizedBox.shrink();
    }

    final mode = player['inputMode'] ?? 'dart';
    final currentMode = player['inputMode'] ?? 'dart';
    final throws = List<int>.from(player['throws'] ?? []);
    final canSwitch = throws.isEmpty;
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
          onSelectionChanged: canSwitch ? (set) async {
            final newMode = set.first;

            final players = List<Map<String, dynamic>>.from(data.players);
            final index = players.indexWhere((p) => p['id'] == player['id']);
            if (index == -1) return;

            final updated = Map<String, dynamic>.from(players[index]);
            updated['inputMode'] = newMode;

            players[index] = updated;

            await repo.update(data.copyWith(players: players));
          } : null,
        ),
        const SizedBox(height: 8),

        if (mode == 'dart')
          _DartKeyboard(
            data: data,
            repo: repo,
            player: player,
          ),

        if (mode == 'total')
          _TotalKeyboard(
            data: data,
            repo: repo,
            player: player,
          ),
      ],
    );
  }
}

class _DartKeyboard extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;
  final Map<String, dynamic> player;

  const _DartKeyboard({
    required this.data,
    required this.repo,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final canUndo = data.history.isNotEmpty;
    final throws = List<int>.from(player['throws'] ?? []);

    return Column(
      children: [
        Wrap(
          spacing: 6,
          children: List.generate(21, (i) {
            final value = i == 20 ? 25 : i + 1;

            return ElevatedButton(
              onPressed: () => _addThrow(value),
              child: Text('$value'),
            );
          }),
        ),

        const SizedBox(height: 8),

        Text('Throws: ${throws.join(", ")}'),
        Text('History: ${data.history.length}'),

        Row(
          children: [
            ElevatedButton(
              onPressed: canUndo ? _undo : null,
              child: const Text('Undo'),
            ),
          ],
        )
      ],
    );
  }

  void _addThrow(int value) async {
    final newState = RoomMatchEngineLogic.applyThrow(
      data,
      player['id'],
      value,
    );

    await repo.update(newState);
  }

  void _undo() async {
    final newState = RoomMatchEngineLogic.undo(data);
    await repo.update(newState);
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
          children: [
            ...List.generate(10, (i) {
              return ElevatedButton(
                onPressed: () => _add(i),
                child: Text('$i'),
              );
            }),
          ],
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 6,
          children: [
            ElevatedButton(
              onPressed: _clear,
              child: const Text('C'),
            ),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: _miss,
              child: const Text('MISS'),
            ),
            ElevatedButton(
              onPressed: _bust,
              child: const Text('BUST'),
            ),
            ElevatedButton(
              onPressed: canUndo ? _undo : null,
              child: const Text('UNDO'),
            ),
          ],
        )
      ],
    );
  }

  void _add(int n) {
    setState(() {
      input += '$n';
    });
  }

  void _clear() {
    setState(() {
      input = '';
    });
  }

  void _submit() async {
    final value = int.tryParse(input);
    if (value == null) return;

    final newState = RoomMatchEngineLogic.applyTurn(
      widget.data,
      widget.player['id'],
      value,
    );

    await widget.repo.update(newState);

    setState(() {
      input = '';
    });
  }

  void _miss() async {
    final newState = RoomMatchEngineLogic.applyTurn(
      widget.data,
      widget.player['id'],
      0,
    );

    await widget.repo.update(newState);
  }

  void _bust() async {
    final newState = RoomMatchEngineLogic.applyTurn(
      widget.data,
      widget.player['id'],
      999, // forza bust
    );

    await widget.repo.update(newState);
  }

  void _undo() async {
    final newState = RoomMatchEngineLogic.undo(widget.data);
    await widget.repo.update(newState);
  }
}
