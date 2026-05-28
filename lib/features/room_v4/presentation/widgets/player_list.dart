// TARGET: Lista giocatori per la lobby
// LOGIC GOAL: Mostrare giocatori, permettere rimozione/riordino
// TEAM MODE: Mostra team come blocchi verticali separati

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';
import '../../domain/models/player_info.dart';

class PlayerList extends ConsumerWidget {
  final List<PlayerInfo> players;
  final bool isTeamMode;
  final int teamSize;

  const PlayerList({
    super.key,
    required this.players,
    required this.isTeamMode,
    required this.teamSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = List<PlayerInfo>.from(players)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (!isTeamMode) {
      return _PlayerListView(players: sorted, ref: ref);
    }
    return _TeamListView(players: sorted, teamSize: teamSize, ref: ref);
  }
}

// ─── Lista singola (single mode) ─────────────────────────────────────────────

class _PlayerListView extends StatelessWidget {
  final List<PlayerInfo> players;
  final WidgetRef ref;

  const _PlayerListView({required this.players, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _PlayerRow(
        index: i,
        player: players[i],
        total: players.length,
        ref: ref,
      ),
    );
  }
}

// ─── Lista team (blocchi verticali separati) ─────────────────────────────────

class _TeamListView extends StatelessWidget {
  final List<PlayerInfo> players;
  final int teamSize;
  final WidgetRef ref;

  const _TeamListView({
    required this.players,
    required this.teamSize,
    required this.ref,
  });

  List<List<PlayerInfo>> get _teams {
    final teams = <List<PlayerInfo>>[];
    for (int i = 0; i < players.length; i += teamSize) {
      final end = (i + teamSize).clamp(0, players.length);
      teams.add(players.sublist(i, end));
    }
    return teams;
  }

  @override
  Widget build(BuildContext context) {
    final teams = _teams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: teams.asMap().entries.map((entry) {
        final ti = entry.key;
        final team = entry.value;
        return TeamBlock(
          teamIndex: ti,
          team: team,
          players: players,
          ref: ref,
        );
      }).toList(),
    );
  }
}

// Nuovo widget separato per il team block
class TeamBlock extends StatelessWidget {
  final int teamIndex;
  final List<PlayerInfo> team;
  final List<PlayerInfo> players;
  final WidgetRef ref;

  const TeamBlock({
    super.key,
    required this.teamIndex,
    required this.team,
    required this.players,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header semplificato
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Text(
              'TEAM ${teamIndex + 1}',
              style: tt.labelSmall?.copyWith(color: t.accent),
            ),
          ),
          const Divider(height: 1),
          // Lista giocatori
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: team.map((p) {
                final gi = players.indexWhere((x) => x.id == p.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PlayerRow(
                    index: gi,
                    player: p,
                    total: players.length,
                    ref: ref,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
// ─── Riga giocatore ───────────────────────────────────────────────

class _PlayerRow extends StatefulWidget {
  final int index;
  final PlayerInfo player;
  final int total;
  final WidgetRef ref;

  const _PlayerRow({
    required this.index,
    required this.player,
    required this.total,
    required this.ref,
  });

  @override
  State<_PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends State<_PlayerRow> {
  bool _busy = false;

  void _reorder(int from, int to) {
    if (_busy) return;
    _busy = true;
    widget.ref.read(roomNotifierProvider.notifier).reorderPlayers(from, to);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r10,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: t.accent.withValues(alpha: 0.1),
            child: Icon(Icons.person, size: 16, color: t.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.player.name,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: t.textPrimary),
                ),
                if (widget.player.isGuest)
                  Text(
                    'guest',
                    style: tt.bodySmall?.copyWith(color: t.textMuted),
                  ),
              ],
            ),
          ),
          _ArrowBtn(
            icon: Icons.arrow_upward,
            enabled: widget.index > 0,
            onTap: () => _reorder(widget.index, widget.index - 1),
          ),
          _ArrowBtn(
            icon: Icons.arrow_downward,
            enabled: widget.index < widget.total - 1,
            onTap: () => _reorder(widget.index, widget.index + 1),
          ),
          GestureDetector(
            onTap: () => widget.ref
                .read(roomNotifierProvider.notifier)
                .removePlayer(widget.player.id),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(Icons.close, size: 20, color: t.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ArrowBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1.0 : 0.2,
            child: Icon(icon, size: 20, color: t.textPrimary),
          ),
        ),
      ),
    );
  }
}
