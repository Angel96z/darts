import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';
import '../../domain/models/checkout_suggestion.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/player_turn.dart';
import 'cricket_board.dart';

class CurrentTurnCard extends ConsumerWidget {
  final GameState gameState;
  const CurrentTurnCard({super.key, required this.gameState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builderState = ref.watch(roomNotifierProvider.select((s) => s.builderState));
    final vm = _Vm.fromGameState(
      gameState: gameState,
      currentLegNumber: builderState?.currentLegNumber ?? 1,
    );
    return _CardView(vm: vm);
  }
}

class _Vm {
  final String playerName;
  final String score;
  final String avg;
  final String roundLabel;
  final String setLabel;
  final String legLabel;
  final bool isFrozen;
  final bool isOut;
  final bool isBust;
  final bool isCheckoutBlocked;
  final _BadgeVm? badge;
  final String? teamLabel;
  final List<String?> dartLabels;
  final List<String?> suggestedDartLabels;
  final String liveTotalLabel;
  final int tableStartScore;
  final List<_RowVm> tableRows;
  final GameState gameState;

  const _Vm({
    required this.playerName,
    required this.score,
    required this.avg,
    required this.roundLabel,
    required this.setLabel,
    required this.legLabel,
    required this.isFrozen,
    required this.isOut,
    required this.isBust,
    required this.isCheckoutBlocked,
    required this.badge,
    required this.teamLabel,
    required this.dartLabels,
    required this.suggestedDartLabels,
    required this.liveTotalLabel,
    required this.tableStartScore,
    required this.tableRows,
    required this.gameState,
  });

  factory _Vm.fromGameState({required GameState gameState, required int currentLegNumber}) {
    final turn = gameState.currentTurn;
    final pid = turn.playerId;
    final avgRaw = gameState.getPlayerAverage(pid);
    final teamId = gameState.getPlayerTeam(pid);
    final isTeamMode = gameState.isTeamMode && teamId != null;
    final isCricket = gameState.isCricket;  // ← Aggiungi questa linea

    final legsWon = isTeamMode ? gameState.getTeamLegsWon(teamId) : gameState.getLegsWonByPlayer(pid);
    final setsWon = isTeamMode ? gameState.getTeamSetsWon(teamId) : gameState.getSetsWonByPlayer(pid);

    String? teamLabel;
    if (isTeamMode) teamLabel = 'Team ${gameState.getTeamIndex(teamId) + 1}';

    final isFrozen = gameState.isPlayerFrozen(pid);
    final isCheckoutBlocked = gameState.isCheckoutBlocked;
    final isOut = turn.isCheckout;
    final isBust = turn.isBust;

    final dartLabels = List<String?>.generate(3, (i) => turn.throws.length > i ? turn.throws[i].label : null);
    final currentThrowCount = turn.throws.length;
    final remainingSlots = 3 - currentThrowCount;

    // 🔥 Passa isCricket come parametro
    final checkoutSuggestion = _buildCheckoutLabels(
      score: turn.score,
      slots: remainingSlots,
      doubleOut: gameState.gameConfig.doubleOut ?? false,
      tripleOut: gameState.gameConfig.tripleOut ?? false,
      isCricket: isCricket,  // ← Nuovo parametro
    );

    final suggestedDartLabels = List<String?>.generate(3, (i) {
      if (i < currentThrowCount) return null;
      final si = i - currentThrowCount;
      return si < checkoutSuggestion.length ? checkoutSuggestion[si] : null;
    });

    final legTurns = gameState.getTurnsForPlayer(pid).where((t) => t.legNumber == currentLegNumber).toList();

    return _Vm(
      playerName: gameState.getPlayerName(pid),
      score: gameState.getPlayerLiveScore(pid).toString(),
      avg: avgRaw.isNaN ? '-' : avgRaw.toStringAsFixed(1),
      roundLabel: gameState.currentRoundLabel,
      setLabel: 'S $setsWon/${gameState.matchConfig.setsToWin}',
      legLabel: 'L $legsWon/${gameState.matchConfig.legsToWin}',
      isFrozen: isFrozen, isOut: isOut, isBust: isBust, isCheckoutBlocked: isCheckoutBlocked,
      badge: _resolveBadge(statusLabel: gameState.getPlayerStateLabel(pid), isOut: isOut, isBust: isBust, isFrozen: isFrozen, isCheckoutBlocked: isCheckoutBlocked),
      dartLabels: dartLabels, suggestedDartLabels: suggestedDartLabels,
      liveTotalLabel: isFrozen ? '---' : '${turn.total}',
      tableStartScore: legTurns.isNotEmpty ? legTurns.first.initialScore : turn.initialScore,
      tableRows: legTurns.map(_RowVm.fromTurn).toList(),
      teamLabel: teamLabel,
      gameState: gameState,
    );
  }
  static _BadgeVm? _resolveBadge({required String statusLabel, required bool isOut, required bool isBust, required bool isFrozen, required bool isCheckoutBlocked}) {
    if (isCheckoutBlocked) return const _BadgeVm(icon: Icons.block_rounded, text: 'NO OUT', kind: _BK.orange);
    if (isOut) return const _BadgeVm(icon: Icons.check_circle_rounded, text: 'OUT', kind: _BK.green);
    if (isBust) return const _BadgeVm(icon: Icons.cancel_rounded, text: 'BUST', kind: _BK.red);
    if (isFrozen) return const _BadgeVm(icon: Icons.lock_rounded, text: 'DOUBLE IN', kind: _BK.grey);
    if (statusLabel.isNotEmpty && !statusLabel.endsWith('LEFT'))
      return _BadgeVm(icon: Icons.play_arrow_rounded, text: statusLabel, kind: _BK.accent);
    return null;
  }

  static List<String> _buildCheckoutLabels({
    required int score,
    required int slots,
    required bool doubleOut,
    required bool tripleOut,
    required bool isCricket,  // Nuovo parametro
  }) {
    // 🔥 SOLO per X01, nessun suggerimento per Cricket
    if (isCricket) return const [];

    if (score <= 0 || slots <= 0) return const [];

    // Determina la modalità di out
    String outMode;
    if (tripleOut) {
      outMode = 'triple';
    } else if (doubleOut) {
      outMode = 'double';
    } else {
      outMode = 'single';
    }

    return CheckoutSuggestion.getSuggestions(
      score: score,
      dartsLeft: slots,
      outMode: outMode,
    );
  }
}

class _RowVm {
  final String turnTotal, dartsLabel, scoreAfterTurn, roundNumber;
  final bool isBust, isCheckout;
  const _RowVm({required this.turnTotal, required this.dartsLabel, required this.scoreAfterTurn, required this.roundNumber, required this.isBust, required this.isCheckout});
  factory _RowVm.fromTurn(PlayerTurn t) => _RowVm(
    turnTotal: t.isBust ? '0' : '${t.total}',
    dartsLabel: t.throws.isEmpty ? '-' : t.throws.map((d) => d.label).join(' · '),
    scoreAfterTurn: '${t.score}', roundNumber: '${t.roundNumber}',
    isBust: t.isBust, isCheckout: t.isCheckout,
  );
}

enum _BK { green, red, orange, grey, accent }
class _BadgeVm {
  final IconData icon; final String text; final _BK kind;
  const _BadgeVm({required this.icon, required this.text, required this.kind});
  Color color(AppTokens t) => switch (kind) {
    _BK.green => t.green, _BK.red => t.red, _BK.orange => t.orange,
    _BK.grey => t.grey, _BK.accent => t.accent,
  };
}

// ──────────────────────────────────────────────
// CARD VIEW - decide layout in base al tipo di gioco
// ──────────────────────────────────────────────

class _CardView extends StatelessWidget {
  final _Vm vm;
  const _CardView({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final live = t.liveColor(isOut: vm.isOut, isBust: vm.isBust, isCheckoutBlocked: vm.isCheckoutBlocked);

    if (vm.gameState.isCricket) {
      // 🔥 CRICKET: live panel a sinistra, stats a destra, cricket board sotto
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 180, child: _LivePanel(vm: vm, t: t, live: live, showStats: false)),
                Container(width: 1, color: t.divider),
                Expanded(child: _RightPanel(vm: vm, t: t, live: live)),
              ],
            ),
            CricketBoard(gameState: vm.gameState),
          ],
        ),
      );
    }

    // 🔥 X01: live panel a sinistra, history panel a destra
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: _LivePanel(vm: vm, t: t, live: live, showStats: true)),
          Container(width: 1, color: t.divider),
          Expanded(
            child: _HistoryPanel(startScore: vm.tableStartScore, rows: vm.tableRows, t: t),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// LIVE PANEL (nome, score, round, freccette, stats)
// ──────────────────────────────────────────────

class _LivePanel extends StatelessWidget {
  final _Vm vm;
  final AppTokens t;
  final Color live;
  final bool showStats; // se false, stats e freccette vengono mostrate nel pannello destro (Cricket)

  const _LivePanel({
    required this.vm,
    required this.t,
    required this.live,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Riga 1: Nome + Badge
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vm.playerName, overflow: TextOverflow.ellipsis, style: t.bodyBold(t.textPrimary)),
              if (vm.teamLabel != null) Text(vm.teamLabel!, style: t.bodySmall(t.textMuted)),
            ])),
            if (vm.badge != null) _Pill(vm: vm.badge!, t: t),
          ]),
          const SizedBox(height: 4),
          // Riga 2: Score + Round
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(vm.score, maxLines: 1, style: t.numericLarge(t.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: t.accent.withOpacity(0.15), borderRadius: AppTokens.r4),
              child: Text(vm.roundLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: t.accent, letterSpacing: 0.5)),
            ),
          ]),
          // 🔥 Riga 3: 3 freccette - SOLO se showStats = true (X01)
          if (showStats) ...[
            const SizedBox(height: 4),
            Row(children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: _DartChip(
                  label: vm.dartLabels[i],
                  suggested: vm.suggestedDartLabels[i],
                  isFrozen: vm.isFrozen,
                  live: live,
                  t: t,
                ),
              ),
            ))),
          ],
          // Riga 4: Stats - SOLO se showStats = true (X01)
          if (showStats) ...[
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _StatItem(label: 'AVG', value: vm.avg, color: t.textSecondary, t: t)),
              const SizedBox(width: 6),
              Expanded(child: _StatItem(label: 'TURN', value: vm.liveTotalLabel, color: live, t: t)),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(vm.setLabel, style: t.bodySmall(t.textMuted)),
                Text(vm.legLabel, style: t.bodySmall(t.textMuted)),
              ]),
            ]),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// RIGHT PANEL (solo per Cricket - stats accanto)
// ──────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final _Vm vm;
  final AppTokens t;
  final Color live;

  const _RightPanel({
    required this.vm,
    required this.t,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 freccette
          Row(children: List.generate(3, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: _DartChip(
                label: vm.dartLabels[i],
                suggested: vm.suggestedDartLabels[i],
                isFrozen: vm.isFrozen,
                live: live,
                t: t,
              ),
            ),
          ))),
          const SizedBox(height: 8),
          // Stats: AVG, TURN, Set/Leg
          Row(children: [
            Expanded(child: _StatItem(label: 'AVG', value: vm.avg, color: t.textSecondary, t: t)),
            const SizedBox(width: 12),
            Expanded(child: _StatItem(label: 'TURN', value: vm.liveTotalLabel, color: live, t: t)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(vm.setLabel, style: t.bodySmall(t.textMuted)),
              Text(vm.legLabel, style: t.bodySmall(t.textMuted)),
            ]),
          ]),
        ],
      ),
    );
  }
}
// ──────────────────────────────────────────────
// UI COMPONENTS
// ──────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final _BadgeVm vm; final AppTokens t;
  const _Pill({required this.vm, required this.t});
  @override
  Widget build(BuildContext context) {
    final c = vm.color(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: AppTokens.r4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(vm.icon, size: 10, color: c),
        const SizedBox(width: 3),
        Text(vm.text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c, letterSpacing: 0.4)),
      ]),
    );
  }
}

class _DartChip extends StatelessWidget {
  final String? label, suggested; final bool isFrozen; final Color live; final AppTokens t;
  const _DartChip({required this.label, required this.suggested, required this.isFrozen, required this.live, required this.t});
  @override
  Widget build(BuildContext context) {
    final hasValue = label != null;
    final hasSuggestion = !hasValue && suggested != null;
    final text = hasValue ? label! : hasSuggestion ? suggested! : isFrozen ? '?' : '_';
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasValue ? live.withOpacity(0.1) : t.surfaceHigh,
        borderRadius: AppTokens.r6,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: hasValue ? FontWeight.w800 : FontWeight.w600,
          color: hasValue ? live : hasSuggestion ? t.textMuted : t.textMuted,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value; final Color color; final AppTokens t;
  const _StatItem({required this.label, required this.value, required this.color, required this.t});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.6)),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, height: 1.1)),
    ],
  );
}

// ──────────────────────────────────────────────
// HISTORY PANEL (X01)
// ──────────────────────────────────────────────

class _HistoryPanel extends StatefulWidget {
  final int startScore; final List<_RowVm> rows; final AppTokens t;
  const _HistoryPanel({required this.startScore, required this.rows, required this.t});
  @override State<_HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<_HistoryPanel> {
  final _scroll = ScrollController();
  @override void initState() { super.initState(); _toBottom(); }
  @override void didUpdateWidget(covariant _HistoryPanel old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) _toBottom();
  }
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }
  @override void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(children: [
            Expanded(child: Text('SCORE', style: t.labelCaps(t.textMuted))),
            Text('${widget.startScore}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.textSecondary)),
            const SizedBox(width: 24),
            Text('R', style: t.labelCaps(t.textMuted)),
          ]),
        ),
        Container(height: 1, color: t.divider),
        widget.rows.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No turns yet', style: t.bodySmall(t.textMuted))))
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          controller: _scroll,
          itemCount: widget.rows.length,
          itemBuilder: (_, i) => _HistoryRow(vm: widget.rows[i], t: t),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final _RowVm vm; final AppTokens t;
  const _HistoryRow({required this.vm, required this.t});
  @override
  Widget build(BuildContext context) {
    final scoreColor = vm.isCheckout ? t.green : vm.isBust ? t.red : t.textPrimary;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(child: Row(children: [
          Text(vm.turnTotal, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scoreColor)),
          const SizedBox(width: 6),
          Flexible(child: Text(vm.dartsLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: t.textMuted))),
        ])),
        SizedBox(width: 44, child: Text(vm.scoreAfterTurn, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: vm.isCheckout ? t.green : t.textSecondary))),
        SizedBox(width: 24, child: Text(vm.roundNumber, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted))),
      ]),
    );
  }
}