// TARGET: Overlay risultati match completo - Clean Architecture
// LOGIC GOAL: Visualizzazione passiva di statistiche, albero match e struttura JSON
// REACTION: UI reagisce a loading/error/success del MatchResultNotifier
// ANTI-REGRESSION: Mantiene _buildMatchDetails, _SyncStatusWidget e _showDatabaseStructure

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app_theme.dart';
import '../../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../../match_sync/domain/entities/local_match_record.dart';
import '../../../application/room_notifier.dart';
import '../../../domain/models/leg.dart';
import '../../../domain/models/match.dart' as domain;
import '../../../domain/models/player_info.dart';
import '../../../domain/models/player_turn.dart';
import '../../../domain/models/set.dart' as domain_set;
import '../application/match_result_notifier.dart';
import '../domain/match_result_state.dart';

class MatchResultOverlay extends ConsumerStatefulWidget {
  const MatchResultOverlay({super.key});

  @override
  ConsumerState<MatchResultOverlay> createState() => _MatchResultOverlayState();
}

class _MatchResultOverlayState extends ConsumerState<MatchResultOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStats());
  }

  void _initStats() {
    final roomState = ref.read(roomNotifierProvider);
    final match = roomState.completedMatch;
    if (match == null) return;

    ref.read(matchResultProvider.notifier).loadMatchResult(
      match: match,
      players: roomState.players,
      isTeamMode: roomState.teamSize > 1,
      playerToTeam: roomState.builderState?.playerToTeam ?? {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final showOverlay = ref.watch(
      roomNotifierProvider.select((s) => s.showResultOverlay),
    );
    final completedMatch = ref.watch(
      roomNotifierProvider.select((s) => s.completedMatch),
    );
    final players = ref.watch(
      roomNotifierProvider.select((s) => s.players),
    );
    final teamSize = ref.watch(
      roomNotifierProvider.select((s) => s.teamSize),
    );
    final playerToTeam = ref.watch(
      roomNotifierProvider.select((s) => s.builderState?.playerToTeam ?? {}),
    );
    final resultState = ref.watch(matchResultProvider);

    if (!showOverlay || completedMatch == null) {
      return const SizedBox.shrink();
    }

    if (resultState.matchId != completedMatch.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initStats());
    }

    final match = resultState.match ?? completedMatch;
    final isTeamMode = teamSize > 1;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.82),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 980,
                maxHeight: 760,
              ),
              child: FractionallySizedBox(
                widthFactor: 0.94,
                heightFactor: 0.92,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: AppTokens.r16,
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    children: [
                      _Header(
                        winnerName: resultState.getWinnerDisplayName(players),
                        onClose: () {
                          ref
                              .read(roomNotifierProvider.notifier)
                              .closeResultOverlay();
                        },
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                          children: [
                            _WinnerPanel(
                              name: resultState.getWinnerDisplayName(players),
                              isTeamMode: resultState.isTeamMode,
                            ),
                            const SizedBox(height: 14),
                            _StatsPanel(
                              match: match,
                              state: resultState,
                              players: players,
                              isTeamMode: isTeamMode,
                              playerToTeam: playerToTeam,
                              getPlayerName: _getPlayerName,
                              onShowStructure: (playerId) {
                                _showDatabaseStructure(
                                  context,
                                  match,
                                  playerId,
                                  t,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _MatchDetailsPanel(
                              match: match,
                              players: players,
                              isTeamMode: isTeamMode,
                              playerToTeam: playerToTeam,
                              getPlayerName: _getPlayerName,
                              getTeamName: _getTeamName,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getPlayerName(String? playerId, List<PlayerInfo> players) {
    if (playerId == null) return 'Sconosciuto';

    final player = players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => PlayerInfo(
        id: playerId,
        name: playerId,
        isGuest: false,
        order: 0,
      ),
    );

    return player.name;
  }

  String _getTeamName(
      String? winnerId,
      List<PlayerInfo> players,
      Map<String, String> playerToTeam,
      ) {
    if (winnerId == null) return 'Sconosciuto';
    if (winnerId.startsWith('T')) return winnerId;

    return playerToTeam[winnerId] ?? winnerId;
  }

  String _buildLocalStructure(String playerId) {
    final localStructure =
    ref.read(matchResultProvider).buildLocalStructure(playerId);
    return _formatJson(localStructure);
  }

  String _formatJson(dynamic json) {
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  void _showDatabaseStructure(
      BuildContext context,
      domain.Match match,
      String playerId,
      AppTokens t,
      ) {
    bool useDbSource = false;
    String? dbMatchId;
    Map<String, dynamic>? dbStructure;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(14),
            backgroundColor: t.bg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppTokens.r16,
              side: BorderSide(color: t.border),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 920,
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              child: Column(
                children: [
                  _JsonDialogHeader(
                    useDbSource: useDbSource,
                    onClose: () => Navigator.pop(context),
                    onChanged: (value) async {
                      setDialogState(() => useDbSource = value);

                      if (value && dbMatchId == null) {
                        setDialogState(() => dbStructure = null);

                        final record =
                        await LocalMatchSyncService.instance.getById(
                          match.id,
                        );

                        if (record != null && record.remoteId != null) {
                          dbMatchId = record.remoteId;
                          dbStructure = await ref
                              .read(matchResultProvider.notifier)
                              .fetchRemoteStructure(dbMatchId!, playerId);
                        }

                        setDialogState(() {});
                      }
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: useDbSource
                          ? dbStructure == null
                          ? _LoadingJson(t: t)
                          : _JsonText(
                        text: _formatJson(dbStructure),
                        t: t,
                      )
                          : _JsonText(
                        text: _buildLocalStructure(playerId),
                        t: t,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// TOP UI
/// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String winnerName;
  final VoidCallback onClose;

  const _Header({
    required this.winnerName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          _IconBox(icon: Icons.emoji_events_outlined, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match completato',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: t.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _WinnerPanel extends StatelessWidget {
  final String name;
  final bool isTeamMode;

  const _WinnerPanel({
    required this.name,
    required this.isTeamMode,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return _Panel(
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, color: t.accent, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isTeamMode ? 'Team vincitore' : 'Vincitore del match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: t.textSecondary,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// STATS
/// ─────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final domain.Match match;
  final MatchResultState state;
  final List<PlayerInfo> players;
  final bool isTeamMode;
  final Map<String, String> playerToTeam;
  final String Function(String?, List<PlayerInfo>) getPlayerName;
  final ValueChanged<String> onShowStructure;

  const _StatsPanel({
    required this.match,
    required this.state,
    required this.players,
    required this.isTeamMode,
    required this.playerToTeam,
    required this.getPlayerName,
    required this.onShowStructure,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    if (state.isLoading && state.playerStats.isEmpty) {
      return _Panel(
        child: Center(
          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2),
        ),
      );
    }

    if (state.hasError && state.playerStats.isEmpty) {
      return _Panel(
        child: Text(
          state.failure?.message ?? 'Errore nel caricamento statistiche',
          style: TextStyle(color: t.red, fontWeight: FontWeight.w700),
        ),
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.query_stats_outlined,
            title: 'Statistiche giocatori',
          ),
          const SizedBox(height: 10),
          ...state.sortedStats.map(
                (entry) {
              return _PlayerStatCard(
                playerId: entry.key,
                stats: entry.value,
                players: players,
                match: match,
                teamId: isTeamMode ? playerToTeam[entry.key] : null,
                getPlayerName: getPlayerName,
                onShowStructure: onShowStructure,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlayerStatCard extends StatelessWidget {
  final String playerId;
  final PlayerStatistics stats;
  final List<PlayerInfo> players;
  final domain.Match match;
  final String? teamId;
  final String Function(String?, List<PlayerInfo>) getPlayerName;
  final ValueChanged<String> onShowStructure;

  const _PlayerStatCard({
    required this.playerId,
    required this.stats,
    required this.players,
    required this.match,
    required this.teamId,
    required this.getPlayerName,
    required this.onShowStructure,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final playerName = getPlayerName(playerId, players);

    final player = players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => PlayerInfo(
        id: playerId,
        name: playerName,
        isGuest: true,
        order: 0,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: stats.isWinner ? t.accent.withOpacity(0.08) : t.surfaceHigh,
        borderRadius: AppTokens.r10,
        border: Border.all(
          color: stats.isWinner ? t.accent.withOpacity(0.55) : t.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(name: playerName, isWinner: stats.isWinner),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: t.textPrimary,
                      ),
                    ),
                    if (teamId != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        teamId!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (stats.isWinner) ...[
                _TinyBadge(label: 'WINNER', color: t.accent),
                const SizedBox(width: 8),
              ],
              if (!player.isGuest)
                _SyncStatusWidget(
                  initialStatus: stats.syncStatus,
                  matchId: match.id,
                  onTap: () => onShowStructure(playerId),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatChip('Media', stats.formattedAverage, Icons.show_chart),
                _StatChip(
                  'Checkout',
                  stats.formattedCheckout,
                  Icons.check_circle_outline,
                ),
                _StatChip('Best', stats.formattedBestTurn, Icons.trending_up),
                _StatChip('Turni', stats.formattedTotalTurns, Icons.repeat),
                _StatChip(
                  'Dardi',
                  stats.formattedTotalDarts,
                  Icons.arrow_right_alt,
                ),
                _StatChip(
                  'Leg',
                  stats.formattedLegsWon,
                  Icons.sports_score_outlined,
                ),
                _StatChip(
                  'Set',
                  stats.formattedSetsWon,
                  Icons.emoji_events_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// MATCH DETAILS
/// ─────────────────────────────────────────────

class _MatchDetailsPanel extends StatelessWidget {
  final domain.Match match;
  final List<PlayerInfo> players;
  final bool isTeamMode;
  final Map<String, String> playerToTeam;
  final String Function(String?, List<PlayerInfo>) getPlayerName;
  final String Function(String?, List<PlayerInfo>, Map<String, String>)
  getTeamName;

  const _MatchDetailsPanel({
    required this.match,
    required this.players,
    required this.isTeamMode,
    required this.playerToTeam,
    required this.getPlayerName,
    required this.getTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.account_tree_outlined,
            title: 'Dettaglio match',
          ),
          const SizedBox(height: 10),
          if (match.sets.isEmpty)
            Text(
              'Nessun dettaglio disponibile',
              style: TextStyle(
                color: t.textMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...match.sets.asMap().entries.map(
                  (entry) => _SetTile(
                index: entry.key,
                set: entry.value,
                players: players,
                isTeamMode: isTeamMode,
                playerToTeam: playerToTeam,
                getPlayerName: getPlayerName,
                getTeamName: getTeamName,
              ),
            ),
        ],
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  final int index;
  final domain_set.Set set;
  final List<PlayerInfo> players;
  final bool isTeamMode;
  final Map<String, String> playerToTeam;
  final String Function(String?, List<PlayerInfo>) getPlayerName;
  final String Function(String?, List<PlayerInfo>, Map<String, String>)
  getTeamName;

  const _SetTile({
    required this.index,
    required this.set,
    required this.players,
    required this.isTeamMode,
    required this.playerToTeam,
    required this.getPlayerName,
    required this.getTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final winnerName = isTeamMode
        ? getTeamName(set.winnerId, players, playerToTeam)
        : getPlayerName(set.winnerId, players);

    return _ExpansionBox(
      color: t.surfaceHigh,
      margin: const EdgeInsets.only(bottom: 8),
      title: Row(
        children: [
          _TinyBadge(label: 'SET ${index + 1}', color: t.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vincitore: $winnerName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
      children: set.legs.asMap().entries.map(
            (entry) {
          return _LegTile(
            index: entry.key,
            leg: entry.value,
            players: players,
            isTeamMode: isTeamMode,
            playerToTeam: playerToTeam,
            getPlayerName: getPlayerName,
            getTeamName: getTeamName,
          );
        },
      ).toList(),
    );
  }
}

class _LegTile extends StatelessWidget {
  final int index;
  final Leg leg;
  final List<PlayerInfo> players;
  final bool isTeamMode;
  final Map<String, String> playerToTeam;
  final String Function(String?, List<PlayerInfo>) getPlayerName;
  final String Function(String?, List<PlayerInfo>, Map<String, String>)
  getTeamName;

  const _LegTile({
    required this.index,
    required this.leg,
    required this.players,
    required this.isTeamMode,
    required this.playerToTeam,
    required this.getPlayerName,
    required this.getTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final winnerName = isTeamMode
        ? getTeamName(leg.winnerId, players, playerToTeam)
        : getPlayerName(leg.winnerId, players);

    final rows = <_HistoryRowVm>[];

    for (final round in leg.rounds) {
      for (final turn in round.turns) {
        rows.add(
          _HistoryRowVm.fromTurn(
            turn: turn,
            playerName: getPlayerName(turn.playerId, players),
          ),
        );
      }
    }

    final startScore = rows.isNotEmpty ? rows.first.initialScore : 0;

    return _ExpansionBox(
      color: t.bg,
      margin: const EdgeInsets.only(top: 8),
      initiallyExpanded: index == 0,
      title: Row(
        children: [
          _TinyBadge(label: 'LEG ${index + 1}', color: t.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vincitore: $winnerName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t.textPrimary,
              ),
            ),
          ),
          Text(
            '${leg.winningScore} pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: t.green,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${leg.rounds.length} round · ${rows.length} turni',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: t.textMuted,
        ),
      ),
      children: [
        _HistoryTable(
          startScore: startScore,
          rows: rows,
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// HISTORY TABLE
/// ─────────────────────────────────────────────

class _HistoryRowVm {
  final String playerName;
  final String turnTotal;
  final String dartsLabel;
  final String scoreAfterTurn;
  final String roundNumber;
  final int initialScore;
  final bool isBust;
  final bool isCheckout;

  const _HistoryRowVm({
    required this.playerName,
    required this.turnTotal,
    required this.dartsLabel,
    required this.scoreAfterTurn,
    required this.roundNumber,
    required this.initialScore,
    required this.isBust,
    required this.isCheckout,
  });

  factory _HistoryRowVm.fromTurn({
    required PlayerTurn turn,
    required String playerName,
  }) {
    return _HistoryRowVm(
      playerName: playerName,
      turnTotal: turn.isBust ? '0' : '${turn.total}',
      dartsLabel: turn.throws.isEmpty
          ? '-'
          : turn.throws.map((d) => d.label).join(' · '),
      scoreAfterTurn: '${turn.score}',
      roundNumber: '${turn.roundNumber}',
      initialScore: turn.initialScore,
      isBust: turn.isBust,
      isCheckout: turn.isCheckout,
    );
  }
}

class _HistoryTable extends StatelessWidget {
  final int startScore;
  final List<_HistoryRowVm> rows;

  const _HistoryTable({
    required this.startScore,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final wantedHeight = 35.0 + (rows.length * 38.0);
    final height = wantedHeight.clamp(92.0, 260.0);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: AppTokens.r8,
          border: Border.all(color: t.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text('PLAYER', style: t.labelCaps(t.textMuted)),
                  ),
                  Expanded(
                    child: Text('SCORE', style: t.labelCaps(t.textMuted)),
                  ),
                  Text(
                    '$startScore',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text('R', style: t.labelCaps(t.textMuted)),
                ],
              ),
            ),
            Container(height: 1, color: t.divider),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                child: Text(
                  'Nessun turno',
                  style: t.bodySmall(t.textMuted),
                ),
              )
                  : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) => _HistoryRow(vm: rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _HistoryRowVm vm;

  const _HistoryRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final scoreColor = vm.isCheckout
        ? t.green
        : vm.isBust
        ? t.red
        : t.textPrimary;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              vm.playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: t.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  vm.turnTotal,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    vm.dartsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              vm.scoreAfterTurn,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: vm.isCheckout ? t.green : t.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              vm.roundNumber,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// JSON DIALOG
/// ─────────────────────────────────────────────

class _JsonDialogHeader extends StatelessWidget {
  final bool useDbSource;
  final VoidCallback onClose;
  final ValueChanged<bool> onChanged;

  const _JsonDialogHeader({
    required this.useDbSource,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, color: t.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Struttura dati salvata',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: t.textSecondary),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SourceSwitch(
            useDbSource: useDbSource,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LoadingJson extends StatelessWidget {
  final AppTokens t;

  const _LoadingJson({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            CircularProgressIndicator(color: t.accent, strokeWidth: 2),
            const SizedBox(height: 14),
            Text(
              'Caricamento dati...',
              style: TextStyle(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _JsonText extends StatelessWidget {
  final String text;
  final AppTokens t;

  const _JsonText({
    required this.text,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        height: 1.35,
        color: t.textSecondary,
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// SYNC STATUS
/// ─────────────────────────────────────────────

class _SyncStatusWidget extends StatefulWidget {
  final LocalMatchSyncStatus? initialStatus;
  final String matchId;
  final VoidCallback onTap;

  const _SyncStatusWidget({
    required this.initialStatus,
    required this.matchId,
    required this.onTap,
  });

  @override
  State<_SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<_SyncStatusWidget> {
  LocalMatchSyncStatus? _currentStatus;
  late final StreamSubscription _syncSubscription;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;

    _syncSubscription =
        LocalMatchSyncService.instance.onSyncStatusChanged.listen(
              (statusMap) {
            if (mounted && statusMap.containsKey(widget.matchId)) {
              setState(() => _currentStatus = statusMap[widget.matchId]);
            }
          },
        );
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final data = switch (_currentStatus) {
      LocalMatchSyncStatus.synced => (
      icon: Icons.cloud_done_outlined,
      color: t.green,
      tooltip: 'Match sincronizzato',
      ),
      LocalMatchSyncStatus.syncing => (
      icon: Icons.sync,
      color: t.orange,
      tooltip: 'Sincronizzazione in corso',
      ),
      LocalMatchSyncStatus.failed => (
      icon: Icons.cloud_off_outlined,
      color: t.red,
      tooltip: 'Sincronizzazione fallita. Tocca per dettagli',
      ),
      _ => (
      icon: Icons.cloud_upload_outlined,
      color: t.grey,
      tooltip: 'Match in attesa di sincronizzazione',
      ),
    };

    return Tooltip(
      message: data.tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _handleTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: data.color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 15, color: data.color),
              if (_currentStatus == LocalMatchSyncStatus.syncing) ...[
                const SizedBox(width: 5),
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: data.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_currentStatus == LocalMatchSyncStatus.failed) {
      await _retrySync(context);
      return;
    }

    widget.onTap();
  }

  Future<void> _retrySync(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Riprovo sincronizzazione...'),
        duration: Duration(seconds: 1),
      ),
    );

    await LocalMatchSyncService.instance.syncAll();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizzazione completata'),
        duration: Duration(seconds: 1),
      ),
    );

    widget.onTap();
  }
}

/// ─────────────────────────────────────────────
/// SMALL UI HELPERS
/// ─────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

class _ExpansionBox extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final EdgeInsets margin;
  final Color color;
  final bool initiallyExpanded;

  const _ExpansionBox({
    required this.title,
    required this.children,
    required this.margin,
    required this.color,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppTokens.r10,
          border: Border.all(color: t.border),
        ),
        child: ExpansionTile(
          dense: true,
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          collapsedIconColor: t.textSecondary,
          iconColor: t.textPrimary,
          title: title,
          subtitle: subtitle,
          children: children,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Row(
      children: [
        Icon(icon, size: 17, color: t.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w900,
            color: t.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: t.textSecondary),
          const SizedBox(width: 5),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool isWinner;

  const _Avatar({
    required this.name,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return CircleAvatar(
      radius: 15,
      backgroundColor:
      isWinner ? t.accent.withOpacity(0.16) : t.border.withOpacity(0.55),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: isWinner ? t.accent : t.textPrimary,
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: AppTokens.r10,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SourceSwitch extends StatelessWidget {
  final bool useDbSource;
  final ValueChanged<bool> onChanged;

  const _SourceSwitch({
    required this.useDbSource,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r10,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_android,
            size: 16,
            color: useDbSource ? t.textMuted : t.accent,
          ),
          const SizedBox(width: 6),
          Text(
            'Locale',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: useDbSource ? t.textMuted : t.accent,
            ),
          ),
          const Spacer(),
          Switch(
            value: useDbSource,
            onChanged: onChanged,
            activeColor: t.accent,
          ),
          const Spacer(),
          Text(
            'Database',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: useDbSource ? t.accent : t.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.cloud_outlined,
            size: 16,
            color: useDbSource ? t.accent : t.textMuted,
          ),
        ],
      ),
    );
  }
}