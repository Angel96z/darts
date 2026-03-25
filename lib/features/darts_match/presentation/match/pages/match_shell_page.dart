import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lobby/controllers/lobby_controller.dart';
import '../../lobby/pages/room_lobby_shell_page.dart';
import '../../../domain/entities/room.dart';
import '../../result/controllers/result_controller.dart';
import '../../result/pages/result_shell_page.dart';
import '../../shared/view_models/connection_badge_vm.dart';
import '../../shared/widgets/connection_badge.dart';
import '../controllers/match_controller.dart';
import '../../../domain/entities/match.dart';
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
  int _input = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final match = widget.match;
      if (match == null) return;

      ref.read(matchControllerProvider.notifier).bindMatch(
        match: match,
        isOnline: widget.isOnline,
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final lobbyVm = ref.watch(lobbyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        actions: [
          if (ref.read(lobbyControllerProvider.notifier).isCurrentUserHost)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final lobby = ref.read(lobbyControllerProvider.notifier);
                if (value == 'restart') {
                  await lobby.reopenRoomFromResult();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomLobbyShellPage()),
                        (r) => false,
                  );
                }
                if (value == 'close') {
                  await lobby.closeRoom();
                  if (!mounted) return;
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restart', child: Text('Torna alla room')),
                PopupMenuItem(value: 'close', child: Text('Chiudi room')),
              ],
            ),
          ConnectionBadge(
            vm: ConnectionBadgeVm(isOnline: lobbyVm.isOnline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ROOM ID: ${lobbyVm.roomId ?? '-'}'),
            const SizedBox(height: 12),
            Text('ROOM STATE: ${lobbyVm.roomState.name}'),
          ],
        ),
      ),
    );
  }
}
