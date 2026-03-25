import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/router/home_shell_screen.dart';
import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../result/pages/result_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/match_controller.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';

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

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final liveMatch = widget.match ?? await ref.read(lobbyControllerProvider.notifier).loadCurrentMatch();
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

    // IMPORTANTE: ricarica la room esistente dal DB
    // così recuperi giocatori, config e stato reale
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
  @override
  Widget build(BuildContext context) {
    final lobbyVm = ref.watch(lobbyControllerProvider);
    final matchVm = ref.watch(matchControllerProvider);
    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);

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
            : const _MatchLayout(),
      ),
    );
  }
}
class _MatchLayout extends StatelessWidget {
  const _MatchLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _TopBarSection(),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 2, child: _PlayersSection()),
              Expanded(flex: 3, child: _CenterBoardSection()),
              Expanded(flex: 2, child: _StatsSection()),
            ],
          ),
        ),
        _BottomControlsSection(),
      ],
    );
  }
}

class _TopBarSection extends StatelessWidget {
  const _TopBarSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Turno: -'),
          Text('Set: -'),
          Text('Leg: -'),
          Text('Punti: -'),
        ],
      ),
    );
  }
}

class _PlayersSection extends StatelessWidget {
  const _PlayersSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _CurrentPlayerCard(),
        Expanded(child: _OtherPlayersList()),
      ],
    );
  }
}

class _CurrentPlayerCard extends StatelessWidget {
  const _CurrentPlayerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            Text('Giocatore in turno'),
            SizedBox(height: 8),
            Text('Punteggio'),
          ],
        ),
      ),
    );
  }
}

class _OtherPlayersList extends StatelessWidget {
  const _OtherPlayersList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (_, i) => const _PlayerRow(),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Giocatore'),
      trailing: const Text('Score'),
    );
  }
}

class _CenterBoardSection extends StatelessWidget {
  const _CenterBoardSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _DartsRow(),
        SizedBox(height: 16),
        _CheckoutSuggestion(),
      ],
    );
  }
}

class _DartsRow extends StatelessWidget {
  const _DartsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _DartBox(label: 'D1'),
        _DartBox(label: 'D2'),
        _DartBox(label: 'D3'),
      ],
    );
  }
}

class _DartBox extends StatelessWidget {
  final String label;
  const _DartBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label),
    );
  }
}

class _CheckoutSuggestion extends StatelessWidget {
  const _CheckoutSuggestion();

  @override
  Widget build(BuildContext context) {
    return const Text('Checkout suggerito');
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Expanded(child: Center(child: Text('Stats Team / Player'))),
      ],
    );
  }
}

class _BottomControlsSection extends StatelessWidget {
  const _BottomControlsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ScoreInputPlaceholder(),
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreInputPlaceholder extends StatelessWidget {
  const _ScoreInputPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text('Tastiera inserimento punteggio'),
    );
  }
}