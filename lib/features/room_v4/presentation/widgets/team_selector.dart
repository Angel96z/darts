// TARGET: Selettore team per la lobby
// LOGIC GOAL: Permettere selezione modalità team (2v2, 3v3, 4v4)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/room_notifier.dart';

class TeamSelector extends ConsumerWidget {
  final WidgetRef ref;

  const TeamSelector({required this.ref, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(roomNotifierProvider);
    final teamSize = state.teamSize;
    final invalid  = !state.canStartMatch && teamSize > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Team',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        DropdownButton<int>(
          value: teamSize,
          underline: const SizedBox(),
          isDense: true,
          style: Theme.of(context).textTheme.bodySmall,
          items: const [
            DropdownMenuItem(value: 0, child: Text('No')),
            DropdownMenuItem(value: 2, child: Text('2v2')),
            DropdownMenuItem(value: 3, child: Text('3v3')),
            DropdownMenuItem(value: 4, child: Text('4v4')),
          ],
          onChanged: (v) {
            if (v != null) ref.read(roomNotifierProvider.notifier).updateTeamSize(v);
          },
        ),
        if (invalid)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
          ),
      ],
    );
  }
}