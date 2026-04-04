import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_player_list.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return 'https://yourapp.web.app/?roomId=$roomId&from=$uid&game=$game';
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

    try {

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

      // PLAYER → si rimuove
      final updatedPlayers = current.players
          .where((p) => p['id'] != uid && p['ownerId'] != uid)
          .toList();

      await repo.update(current.copyWith(players: updatedPlayers));

      await UserRoomRepository(FirebaseFirestore.instance)
          .clearCurrentRoom(uid);

    } catch (_) {}
  }
}

class RoomLobbyV2Page extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final controller = RoomLobbyV2Controller(repo);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await _confirmExit(context);

        if (!ok) return;

        await controller.exitRoom();

        if (context.mounted) {
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

  const _RoomLobbyV2View({
    required this.data,
    required this.controller,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = controller.isAdmin;
    final isCreator = controller.isCreator;
    final creatorId = controller.creatorId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOBBY'),
          const SizedBox(height: 8),
          Text('SYNC: $connectionState'),
          const SizedBox(height: 8),
          Text('ROOM ID: ${data.roomId ?? "LOCALE"}'),
          const SizedBox(height: 8),
          Text('CREATOR: ${creatorId ?? "-"}'),
          Text('IS CREATOR: ${isCreator ? "YES" : "NO"}'),
          const SizedBox(height: 16),
          GameSelector(
            config: data.game,
            onChanged: (g) => controller.updateGame(data, g),
          ),
          const SizedBox(height: 16),
          MatchSelector(
            config: data.matchConfig,
            onChanged: (c) => controller.updateMatchConfig(data, c),
          ),
          const SizedBox(height: 16),
          Text('STATO: ${data.phase.name}'),
          const SizedBox(height: 16),
          const RoomCurrentUserView(),
          const SizedBox(height: 16),
          RoomPlayerList(data: data, repo: controller.repo),
          const SizedBox(height: 16),
          Text('ADMINS: ${data.adminIds.join(", ")}'),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'ENGINE DEBUG',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: RoomMatchEngineView(
              data: data,
              repo: controller.repo,
            ),
          ),
          ElevatedButton(
            onPressed: isAdmin ? () {} : null,
            child: const Text('Admin Action'),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final link = await controller.invite();
                  if (link == null) return;

                  await Clipboard.setData(ClipboardData(text: link));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiato')),
                  );
                },
                child: const Text('Invita'),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () async {
              final current = controller.repo.current;
              if (current?.roomId == null) return;

              final link =
                  'https://yourapp.web.app/?watchRoomId=${current!.roomId}';

              await Clipboard.setData(ClipboardData(text: link));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link spettatore copiato')),
              );
            },
            child: const Text('Invita spettatore'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
            isAdmin ? () => controller.startMatch(data) : null,
            child: const Text('Start match'),
          ),
        ],
      ),
    );
  }
}