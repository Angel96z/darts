import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/router/home_shell_screen.dart';
import '../../../../../core/widgets/dartboard_overlays.dart';
import '../../../domain/entities/identity.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../result/pages/result_shell_page.dart';
import '../../result/controllers/result_controller.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/match_controller.dart';
import '../match_vm/match_vm.dart';

class MatchShellPage extends ConsumerStatefulWidget {
  const MatchShellPage({
    super.key,
    required this.match,
    required this.isOnline,
    required this.canPlay,
  });

  final Match? match;
  final bool isOnline;
  final bool canPlay;

  @override
  ConsumerState<MatchShellPage> createState() => _MatchShellPageState();
}

class _MatchShellPageState extends ConsumerState<MatchShellPage> {
  bool _moving = false;
  bool _finishingSent = false;
  bool _resultSynced = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final liveMatch =
          widget.match ?? await ref.read(lobbyControllerProvider.notifier).loadCurrentMatch();
      if (!mounted || liveMatch == null) return;
      await ref.read(matchControllerProvider.notifier).bindMatch(
        match: liveMatch,
        isOnline: widget.isOnline,
      );
    });
  }

  Future<void> _onLobbyState(LobbyViewModel next) async {
    if (!mounted || _moving) return;

    if (next.roomState == RoomState.finished) {
      _moving = true;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ResultShellPage()),
      );
      return;
    }

    if (next.roomState == RoomState.waiting || next.roomState == RoomState.ready) {
      _moving = true;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoomLobbyShellPage()),
            (route) => false,
      );
      return;
    }

    if (next.roomState == RoomState.closed) {
      _moving = true;
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(
            initialSection: AppSection.gioca,
          ),
        ),
            (route) => false,
      );
    }
  }

  Future<void> _exitMatchAndGoRoom() async {
    if (!mounted || _moving) return;
    _moving = true;

    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);
    final matchVm = ref.read(matchControllerProvider);
    final lobbyVm = ref.read(lobbyControllerProvider);

    final firestore = FirebaseFirestore.instance;

    if (matchVm != null) {
      final matchId = matchVm.match.id.value;

      // 1. delete root match (se esiste)
      if (matchId.isNotEmpty) {
        await firestore.collection('matches').doc(matchId).delete().catchError((_) {});
      }

      // 2. delete match dentro la room
      final roomId = lobbyVm.roomId ?? '';
      if (roomId.isNotEmpty) {
        final roomRef = firestore.collection('rooms').doc(roomId);

        // elimina eventuale sub-doc match
        await roomRef.collection('matches').doc(matchId).delete().catchError((_) {});

        // pulisci riferimento nella room
        await roomRef.update({
          'currentMatchId': FieldValue.delete(),
          'status': 'waiting',
        }).catchError((_) {});
      }
    }

    await lobbyCtrl.reloadRoomFromDb();

    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RoomLobbyShellPage(),
      ),
    );
  }

  Future<bool> _confirmExitMatch() async {
    if (_moving) return false;

    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);
    final isSpectator = !widget.canPlay;
    final canControlAdmin = lobbyCtrl.canCurrentAuthControlAsAdmin;

    final title = isSpectator
        ? 'Torna alla room'
        : canControlAdmin
        ? 'Termina partita e torna alla room'
        : 'Lascia partita e torna alla room';

    final message = isSpectator
        ? 'Tornerai alla room in sola lettura.'
        : canControlAdmin
        ? 'La partita verrà terminata e tornerai alla room mantenendo configurazione e giocatori.'
        : 'Lascerai la partita e tornerai alla room.';

    final confirmLabel = isSpectator
        ? 'Torna'
        : canControlAdmin
        ? 'Termina partita'
        : 'Lascia partita';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return false;

    await _exitMatchAndGoRoom();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lobbyVm = ref.watch(lobbyControllerProvider);
    final matchVm = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);
    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);

    final currentTurnPlayerId =
        matchVm?.match.snapshot.scoreboard.currentTurnPlayerId.value ?? '';

    final vm = matchVm == null ? null : controller.toVm(currentTurnPlayerId);

    final liveCanPlay = widget.canPlay || lobbyCtrl.canCurrentAuthControlAsAdmin;

    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _onLobbyState(next);
    });

    if (!_finishingSent &&
        matchVm != null &&
        matchVm.match.snapshot.status == MatchStatus.completed &&
        lobbyCtrl.canCurrentAuthControlAsAdmin) {
      _finishingSent = true;
      Future.microtask(() => lobbyCtrl.markRoomFinished());
    }

    if (!_resultSynced &&
        matchVm != null &&
        matchVm.match.snapshot.status == MatchStatus.completed) {
      _resultSynced = true;
      Future.microtask(() {
        ref.read(resultControllerProvider.notifier).setFromMatch(matchVm.match);
      });
    }

    return WillPopScope(
      onWillPop: _confirmExitMatch,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmExitMatch,
          ),
          title: const Text('Match'),
          actions: [
            ConnectionBadge(vm: ConnectionBadgeVm(isOnline: lobbyVm.isOnline)),
            const SizedBox(width: 8),
          ],
        ),
        body: matchVm == null
            ? const Center(child: CircularProgressIndicator())
            : _MatchLayout(
          vm: vm!,
          match: matchVm.match,
          canPlay: liveCanPlay,
        ),
      ),
    );
  }
}

class _MatchLayout extends StatelessWidget {
  const _MatchLayout({
    required this.vm,
    required this.match,
    required this.canPlay,
  });

  final MatchVm vm;
  final Match match;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBarSection(match: match),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 2, child: _PlayersSection(vm: vm, match: match)),
              Expanded(flex: 3, child: _CenterBoardSection(match: match)),
              Expanded(flex: 2, child: _StatsSection(match: match)),
            ],
          ),
        ),
        _BottomControlsSection(canPlay: canPlay),
      ],
    );
  }
}


class _TopBarSection extends StatelessWidget {
  const _TopBarSection({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final currentSlot = _currentSlot(match);
    final currentScore =
        match.snapshot.scoreboard.playerScores[match.snapshot.scoreboard.currentTurnPlayerId] ??
            match.config.startScore;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Turno: ${match.snapshot.currentTurn}'),
          Text('Set: ${match.snapshot.currentSet}'),
          Text('Leg: ${match.snapshot.currentLeg}'),
          Text('Giocatore: ${_playerLabel(currentSlot)}'),
          Text('Score: $currentScore'),
        ],
      ),
    );
  }
}

class _PlayersSection extends StatelessWidget {
  const _PlayersSection({
    required this.vm,
    required this.match,
  });

  final MatchVm vm;
  final Match match;

  @override
  Widget build(BuildContext context) {
    final currentPlayer = match.roster.players.firstWhere(
          (p) => p.playerId.value == vm.currentPlayerId,
      orElse: () => match.roster.players.first,
    );

    final currentScore =
        match.snapshot.scoreboard.playerScores[currentPlayer.playerId] ?? match.config.startScore;

    final others = match.roster.players
        .where((p) => p.playerId.value != vm.currentPlayerId)
        .toList();

    return Column(
      children: [
        _CurrentPlayerCard(
          player: currentPlayer,
          score: currentScore,
        ),
        Expanded(
          child: ListView(
            children: [
              for (final player in others)
                _PlayerRow(
                  player: player,
                  score: match.snapshot.scoreboard.playerScores[player.playerId] ??
                      match.config.startScore,
                  isCurrent: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}


class _OtherPlayersList extends StatelessWidget {
  const _OtherPlayersList({required this.vm});

  final MatchVm vm;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: vm.players.length,
      itemBuilder: (_, i) {
        final p = vm.players[i];

        return Container(
          color: p.isCurrent ? Colors.green.withOpacity(0.2) : null,
          child: ListTile(
            title: Text(p.name),
            trailing: Text('${p.score}'),
          ),
        );
      },
    );
  }
}
class _CurrentPlayerCard extends StatelessWidget {
  const _CurrentPlayerCard({
    required this.player,
    required this.score,
  });

  final PlayerSlot player;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Giocatore in turno: ${_playerLabel(player)}'),
            const SizedBox(height: 8),
            Text('Punteggio: $score'),
            const SizedBox(height: 8),
            Text('Ordine: ${player.order + 1}'),
            Text('Team: ${player.teamId?.value ?? "Solo"}'),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.score,
    required this.isCurrent,
  });

  final PlayerSlot player;
  final int score;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCurrent ? Colors.green.withOpacity(0.3) : null,
      child: ListTile(
        title: Text(_playerLabel(player)),
        subtitle: Text('Team: ${player.teamId?.value ?? "Solo"}'),
        trailing: Text('$score'),
      ),
    );
  }
}
class _HitOverlayEntry {
  final String label;
  final int score;

  const _HitOverlayEntry(this.label, this.score);
}


class _CenterBoardSection extends ConsumerStatefulWidget {
  const _CenterBoardSection({required this.match});

  final Match match;

  @override
  ConsumerState<_CenterBoardSection> createState() => _CenterBoardSectionState();
}

class _CenterBoardSectionState extends ConsumerState<_CenterBoardSection> {
  _HitOverlayEntry? _overlay;

  @override
  Widget build(BuildContext context) {
    ref.listen(matchControllerProvider, (prev, next) {
      if (next == null) return;

      final turns = next.match.snapshot.lastTurns;
      if (turns.isEmpty) return;

      final last = turns.last;

      final isBust = last.resolution.isBust;
      final isCheckout = last.resolution.isCheckout;

      final total = last.draft.total;

      String label;
      if (isCheckout) {
        label = 'CHECKOUT';
      } else if (isBust) {
        label = 'BUST';
      } else {
        label = 'TURN';
      }

      setState(() {
        _overlay = _HitOverlayEntry(label, total);
      });

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _overlay = null);
      });
    });

    final matchVmState = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);
    final currentPlayerId =
        matchVmState?.match.snapshot.scoreboard.currentTurnPlayerId.value ?? '';
    final vm = controller.toVm(currentPlayerId);

    final lastTurn =
    widget.match.snapshot.lastTurns.isNotEmpty ? widget.match.snapshot.lastTurns.last : null;
    final committedInputs = lastTurn?.draft.inputs ?? const <DartInput>[];

    final labels = vm.inputMode == MatchInputMode.perDart
        ? [
      for (int i = 0; i < 3; i++)
        i < vm.displayTurnLabels.length ? vm.displayTurnLabels[i] : '-',
    ]
        : [
      vm.displayTurnLabels.isNotEmpty ? vm.displayTurnLabels.first : '-',
    ];

    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DartsRow(
              labels: labels,
              isPerTurnMode: vm.inputMode == MatchInputMode.perTurn,
            ),
            const SizedBox(height: 16),
            if (vm.inputMode == MatchInputMode.perDart && vm.currentTurnInputs.isEmpty)
              _DartsRow(
                labels: [
                  for (int i = 0; i < 3; i++)
                    i < committedInputs.length
                        ? controller.formatInputLabel(committedInputs[i])
                        : '-',
                ],
                isPerTurnMode: false,
              ),
            const SizedBox(height: 16),
            _CheckoutSuggestion(match: widget.match),
          ],
        ),

        if (_overlay != null)
          Positioned.fill(
            child: IgnorePointer(
              child: HitFeedbackOverlay(
                sector: _overlay!.label,
                score: _overlay!.score,
              ),
            ),
          ),
      ],
    );
  }
}
class _DartsRow extends StatelessWidget {
  const _DartsRow({
    required this.labels,
    required this.isPerTurnMode,
  });

  final List<String> labels;
  final bool isPerTurnMode;

  @override
  Widget build(BuildContext context) {
    if (isPerTurnMode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DartBox(
            label: labels.isNotEmpty ? labels.first : '-',
            title: 'Turno',
            width: 180,
          ),
        ],
      );
    }

    final normalized = <String>[
      for (int i = 0; i < 3; i++) i < labels.length ? labels[i] : '-',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _DartBox(label: normalized[0], title: 'D1'),
        _DartBox(label: normalized[1], title: 'D2'),
        _DartBox(label: normalized[2], title: 'D3'),
      ],
    );
  }
}


class _DartBox extends StatelessWidget {
  const _DartBox({
    required this.label,
    required this.title,
    this.width = 96,
  });

  final String label;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _CheckoutSuggestion extends StatelessWidget {
  const _CheckoutSuggestion({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final score =
        match.snapshot.scoreboard.playerScores[match.snapshot.scoreboard.currentTurnPlayerId] ??
            match.config.startScore;

    return Text('Score rimanente: $score');
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('Turni registrati'),
          trailing: Text('${match.snapshot.lastTurns.length}'),
        ),
        for (final player in match.roster.players)
          ListTile(
            title: Text(_playerLabel(player)),
            subtitle: Text('Media turno: ${_playerAverage(match, player).toStringAsFixed(1)}'),
            trailing:
            Text('${match.snapshot.scoreboard.playerScores[player.playerId] ?? match.config.startScore}'),
          ),
      ],
    );
  }
}

class _BottomControlsSection extends ConsumerStatefulWidget {
  const _BottomControlsSection({required this.canPlay});

  final bool canPlay;

  @override
  ConsumerState<_BottomControlsSection> createState() => _BottomControlsSectionState();
}

class _BottomControlsSectionState extends ConsumerState<_BottomControlsSection> {
  final TextEditingController _scoreCtrl = TextEditingController();

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchVm = ref.watch(matchControllerProvider);
    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);
    final currentPlayerId =
        matchVm?.match.snapshot.scoreboard.currentTurnPlayerId.value ?? '';
    final controller = ref.read(matchControllerProvider.notifier);
    final vm = controller.toVm(currentPlayerId);

    final isFinished = matchVm?.match.snapshot.status == MatchStatus.completed;
    final canControlTurn = vm.isInputEnabled || lobbyCtrl.canCurrentAuthControlAsAdmin;
    final canSubmit = widget.canPlay && canControlTurn && !isFinished;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SegmentedButton<MatchInputMode>(
            segments: const [
              ButtonSegment<MatchInputMode>(
                value: MatchInputMode.perDart,
                label: Text('Freccette'),
              ),
              ButtonSegment<MatchInputMode>(
                value: MatchInputMode.perTurn,
                label: Text('Turno'),
              ),
            ],
            selected: {vm.inputMode},
            onSelectionChanged: canSubmit
                ? (values) => controller.setInputMode(values.first)
                : null,
          ),
        ),
        if (vm.inputMode == MatchInputMode.perDart)
          _PerDartControls(
            canSubmit: canSubmit,
            vm: vm,
          )
        else
          _PerTurnControls(
            canSubmit: canSubmit,
            scoreCtrl: _scoreCtrl,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: widget.canPlay &&
                canControlTurn &&
                !isFinished &&
                (matchVm?.isOnline ?? false)
                ? () => controller.undoLastTurn()
                : null,
            child: const Text('Undo'),
          ),
        ),
      ],
    );
  }
}


class _PerDartControls extends ConsumerWidget {
  const _PerDartControls({
    required this.canSubmit,
    required this.vm,
  });

  final bool canSubmit;
  final MatchVm vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(matchControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final mode in DartMultiplierMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: vm.selectedMultiplier == mode,
                  onSelected: canSubmit
                      ? (_) => controller.setSelectedMultiplier(mode)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (int value = 1; value <= 20; value++)
                  ElevatedButton(
                    onPressed: canSubmit && vm.currentTurnInputs.length < 3
                        ? () => controller.registerDartValue(value)
                        : null,
                    child: Text('$value'),
                  ),
                ElevatedButton(
                  onPressed: canSubmit && vm.currentTurnInputs.length < 3
                      ? () => controller.registerDartValue(25)
                      : null,
                  child: const Text('25'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: canSubmit && vm.currentTurnInputs.isNotEmpty
                    ? () => controller.removeLastBufferedDart()
                    : null,
                child: const Text('Cancella ultima'),
              ),
              ElevatedButton(
                onPressed: canSubmit && vm.currentTurnInputs.isNotEmpty
                    ? () => controller.clearBufferedTurn()
                    : null,
                child: const Text('Reset turno'),
              ),
              ElevatedButton(
                onPressed: canSubmit && vm.currentTurnInputs.isNotEmpty
                    ? () => controller.submitBufferedTurn()
                    : null,
                child: const Text('Invia turno'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerTurnControls extends ConsumerWidget {
  const _PerTurnControls({
    required this.canSubmit,
    required this.scoreCtrl,
  });

  final bool canSubmit;
  final TextEditingController scoreCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(matchControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final value in const [26, 45, 60, 85, 100, 140, 180])
                ElevatedButton(
                  onPressed: canSubmit ? () => controller.submitTurn(value) : null,
                  child: Text('$value'),
                ),
              ElevatedButton(
                onPressed: canSubmit ? () => controller.submitCheckout() : null,
                child: const Text('Checkout'),
              ),
              ElevatedButton(
                onPressed: canSubmit ? () => controller.submitBust() : null,
                child: const Text('Bust'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Punteggio turno',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: canSubmit
                    ? () {
                  final value = int.tryParse(scoreCtrl.text.trim());
                  if (value == null) return;
                  controller.submitTurn(value);
                  scoreCtrl.clear();
                }
                    : null,
                child: const Text('Invia'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


PlayerSlot _currentSlot(Match match) {
  return match.roster.players.firstWhere(
        (p) => p.playerId == match.snapshot.scoreboard.currentTurnPlayerId,
    orElse: () => match.roster.players.first,
  );
}

String _playerLabel(PlayerSlot player) {
  return player.playerId.value;
}

double _playerAverage(Match match, PlayerSlot player) {
  final turns = match.snapshot.lastTurns.where((t) => t.draft.playerId == player.playerId).toList();
  if (turns.isEmpty) return 0;
  final total = turns.fold<int>(0, (sum, turn) => sum + turn.draft.total);
  return total / turns.length;
}
