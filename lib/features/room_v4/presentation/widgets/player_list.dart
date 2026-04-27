// TARGET: Lista giocatori per la lobby
// LOGIC GOAL: Mostrare giocatori, permettere rimozione/riordino

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ─── Lista singola ────────────────────────────────────────────────────────────

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

// ─── Lista team ───────────────────────────────────────────────────────────────

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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _teams.asMap().entries.map((entry) {
        final ti = entry.key;
        final team = entry.value;
        return SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label team
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'TEAM ${ti + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ...team.map((p) {
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
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Riga giocatore ───────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primary.withOpacity(0.1),
            child: Icon(Icons.person, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 10),

          // Nome + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (widget.player.isGuest)
                  Text(
                    'guest',
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
              ],
            ),
          ),

          // Frecce riordino
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

          // Rimuovi
          GestureDetector(
            onTap: () => widget.ref
                .read(roomNotifierProvider.notifier)
                .removePlayer(widget.player.id),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: Colors.red),
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

  const _ArrowBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
    );
  }
}