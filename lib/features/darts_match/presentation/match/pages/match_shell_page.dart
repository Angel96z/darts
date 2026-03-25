import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      await ref.read(lobbyControllerProvider.notifier).closeRoom();
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyVm = ref.watch(lobbyControllerProvider);
    final matchVm = ref.watch(matchControllerProvider);
    final lobbyCtrl = ref.read(lobbyControllerProvider.notifier);

    ref.listen<LobbyViewModel>(lobbyControllerProvider, (prev, next) {
      _onLobbyState(next);
    });

    final statusText = matchVm == null
        ? 'Caricamento partita...'
        : (matchVm.match.snapshot.status == MatchStatus.completed ? 'Partita terminata' : 'Partita in corso');

    if (!_finishingSent &&
        matchVm != null &&
        matchVm.match.snapshot.status == MatchStatus.completed &&
        lobbyCtrl.isCurrentUserHost) {
      _finishingSent = true;
      Future.microtask(() => lobbyCtrl.markRoomFinished());
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match'),
          actions: [
            ConnectionBadge(vm: ConnectionBadgeVm(isOnline: lobbyVm.isOnline)),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: matchVm == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ROOM ID: ${lobbyVm.roomId ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('RUOLO: ${widget.canPlay ? 'player/host' : 'spectator'}'),
                    const SizedBox(height: 8),
                    Text(statusText),
                    const SizedBox(height: 12),
                    if (!widget.canPlay) const Text('Modalità sola lettura'),
                  ],
                ),
        ),
      ),
    );
  }
}
