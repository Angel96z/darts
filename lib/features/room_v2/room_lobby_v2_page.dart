import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_player_list.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/offline_controller.dart';
import 'games_darts.dart';
import 'room_data.dart';
import 'room_match_engine.dart';
import 'room_repository.dart';
import 'room_current_user.dart';

class RoomLobbyV2Controller {
  final RoomRepository repo;

  RoomLobbyV2Controller(this.repo);

  RoomData get currentData => repo.current!;

  bool get isAdmin =>
      currentData.adminIds.contains(RoomCurrentUser.current.uid);

  bool get isCreator =>
      currentData.creatorId == RoomCurrentUser.current.uid;

  String? get creatorId => currentData.creatorId;

  Future<String?> invite() async {
    final current = repo.current;
    if (current == null) return null;

    // CREA ROOM SOLO QUI (evento esplicito)
    if (current.roomId == null) {
      await repo.createOnline();
    }

    final updated = repo.current;
    if (updated == null || updated.roomId == null) return null;

    final roomId = updated.roomId!;
    final game = updated.game.type.name;
    final uid = RoomCurrentUser.current.uid;

    return 'https://dartsroses.netlify.app/?roomId=$roomId';
  }

  Future<void> startMatch(RoomData data) async {
    await repo.update(data.initMatch());
  }

  Future<void> updateGame(RoomData data, GameConfig game) async {
    await repo.update(data.copyWith(game: game));
  }

  Future<void> updateMatchConfig(
      RoomData data, MatchConfig config) async {
    await repo.update(data.copyWith(matchConfig: config));
  }

  Future<void> exitRoom() async {
    final current = repo.current;
    final uid = RoomCurrentUser.current.uid;

    if (current == null) return;

    // 1. USCITA LOCALE IMMEDIATA (SEMPRE)
    try {
      final updatedPlayers = current.players
          .where((p) => p['id'] != uid && p['ownerId'] != uid)
          .toList();

      repo.update(current.copyWith(players: updatedPlayers));
    } catch (_) {}

    // 2. SYNC REMOTO (BEST EFFORT)
    try {
      if (current.roomId == null) return;

      // CREATOR → chiude room
      if (current.creatorId == uid) {
        for (final p in current.players) {
          final id = p['id'];
          final isGuest = p['isGuest'] == true;

          if (!isGuest && id != null) {
            await UserRoomRepository(FirebaseFirestore.instance)
                .clearCurrentRoom(id);
          }
        }

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(current.roomId)
            .delete();

        return;
      }

      // PLAYER → sync remoto
      await repo.update(repo.current!);

      await UserRoomRepository(FirebaseFirestore.instance)
          .clearCurrentRoom(uid);

    } catch (_) {}
  }

}

class RoomLobbyV2Page extends ConsumerWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomLobbyV2Page({
    super.key,
    required this.data,
    required this.repo,
  });

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: const Text('Uscire dalla lobby?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Si'),
          ),
        ],
      ),
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = RoomLobbyV2Controller(repo);
    final isOnline = ref.watch(offlineControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await _confirmExit(context);
        if (!ok) return;

        await controller.exitRoom();

        if (context.mounted) {
          controller.repo.clearLocal();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Lobby')),
        body: StreamBuilder<RoomData>(
          stream: repo.watch(),
          initialData: data,
          builder: (context, snapshot) {
            final liveData = snapshot.data ?? data;

            return _RoomLobbyV2View(
              data: liveData,
              controller: controller,
              connectionState: snapshot.connectionState.name,
              isOnline: isOnline,
            );
          },
        ),
      ),
    );
  }
}


class _RoomLobbyV2View extends StatelessWidget {
  final RoomData data;
  final RoomLobbyV2Controller controller;
  final String connectionState;
  final bool isOnline;

  const _RoomLobbyV2View({
    required this.data,
    required this.controller,
    required this.connectionState,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = controller.isAdmin;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      /*
                      if (data.roomId != null) ...[
                        OutlinedButton(
                          onPressed: () async {
                            final current = controller.repo.current;
                            if (current?.roomId == null) return;

                            final link =
                                'https://dartsroses.netlify.app/?watchRoomId=${current!.roomId}';

                            await Clipboard.setData(
                                ClipboardData(text: link));

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Link spettatore copiato')),
                            );
                          },
                          child: const Text('Invita a guardare'),
                        ),
                        const SizedBox(width: 8),
                      ],*/
                      ElevatedButton.icon(
                        onPressed: isOnline
                            ? () async {
                          final link = await controller.invite();
                          if (link == null) return;

                          await Clipboard.setData(
                              ClipboardData(text: link));

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copiato')),
                          );
                        }
                            : null,
                        icon: Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                        label: const Text('Gioca online'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SINISTRA → Match + Gioco
                        Expanded(
                          child: Column(
                            children: [
                              _CardBlock(
                                title: 'Match',
                                child: MatchSelector(
                                  config: data.matchConfig,
                                  onChanged: (c) => controller.updateMatchConfig(data, c),
                                  isAdmin: isAdmin,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _CardBlock(
                                title: 'Gioco',
                                child: GameSelector(
                                  config: data.game,
                                  onChanged: (g) => controller.updateGame(data, g),
                                  isAdmin: isAdmin,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // DESTRA → Giocatori (full height)
                        Expanded(
                          child: _CardBlock(
                            title: 'Giocatori',
                            child: RoomPlayerList(
                              data: data,
                              repo: controller.repo,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _CardBlock(
                          title: 'Match',
                          child: MatchSelector(
                            config: data.matchConfig,
                            onChanged: (c) => controller.updateMatchConfig(data, c),
                            isAdmin: isAdmin,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CardBlock(
                          title: 'Gioco',
                          child: GameSelector(
                            config: data.game,
                            onChanged: (g) => controller.updateGame(data, g),
                            isAdmin: isAdmin,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CardBlock(
                          title: 'Giocatori',
                          child: RoomPlayerList(
                            data: data,
                            repo: controller.repo,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isAdmin)
                        ElevatedButton(
                          onPressed: data.isValidTeamSetup()
                              ? () => controller.startMatch(data)
                              : null,
                          child: const Text('Start match'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


class _CardBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardBlock({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}