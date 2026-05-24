import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';
import 'add_player_dialog.dart';
import 'player_list.dart';
import 'team_selector.dart';

class PlayersColumn extends ConsumerWidget {
  final WidgetRef ref;

  const PlayersColumn({required this.ref, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomNotifierProvider);
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intestazione come MATCH e GAME
        Row(
          children: [
            Icon(Icons.people_rounded, size: 16, color: t.accent),
            const SizedBox(width: 8),
            Text('PLAYERS', style: t.labelCaps(t.accent)),
            const SizedBox(width: 8),

            _CountBadge(count: state.players.length),
            const Spacer(),
            TeamSelector(ref: ref),


          ],
        ),
        const SizedBox(height: 12),

        // Card contenuto come MATCH e GAME
        Container(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contenuto principale
              if (state.players.isNotEmpty)
                PlayerList(
                  players: state.players,
                  isTeamMode: state.teamSize > 1,
                  teamSize: state.teamSize,
                )
              else
                const _EmptyState(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.12),
        borderRadius: AppTokens.r16,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: t.accent,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 48,
              color: t.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'Nessun giocatore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tocca + per aggiungere',
              style: t.bodySmall(t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class AddPlayerButton extends ConsumerWidget {
  const AddPlayerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);

    return InkResponse(
      onTap: () => _onAddPlayer(context, ref),
      radius: 28,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: AppTokens.r16,
        ),
        child: Icon(
          Icons.person_add_alt_1_rounded,
          size: 24,
          color: t.accentFg,
        ),
      ),
    );
  }

  Future<void> _onAddPlayer(BuildContext context, WidgetRef ref) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'local';
    final player = await showAddPlayerDialog(context, currentUserId);

    if (player != null && context.mounted) {
      ref.read(roomNotifierProvider.notifier).addPlayer(
        player.$1,
        player.$2,
        player.$3,
      );
    }
  }
}