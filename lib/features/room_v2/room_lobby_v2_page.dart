import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_player_list.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:flutter/material.dart';
import 'games_darts.dart';
import 'room_data.dart';
import 'room_match_engine.dart';
import 'room_repository.dart';
import 'room_current_user.dart';
import 'games_darts.dart';

class RoomLobbyV2Page extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomLobbyV2Page({
    super.key,
    required this.data,
    required this.repo,
  });

  Future<void> _invite() async {
    final current = repo.current;
    if (current == null || current.roomId != null) return;
    await repo.createOnline();
  }

  Future<bool> confirmExit(BuildContext context) async {
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

    if (result != true) return false;

    final current = repo.current;
    final uid = RoomCurrentUser.current.uid;

    if (current == null) return true;

    () async {
      try {
// =========================
// CREATOR → elimina room + scollega tutti
// =========================
        if (current.creatorId == uid && current.roomId != null) {
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

        // =========================
        // USER NORMALE
        // =========================

        final ownedPlayers = current.players.where((p) {
          final owner = p['ownerId'];
          final id = p['id'];
          return owner == uid || id == uid;
        }).toList();

        // rimuove players dalla room
        final updatedPlayers = current.players
            .where((p) => !ownedPlayers.contains(p))
            .toList();

        await repo.update(current.copyWith(players: updatedPlayers));

        // pulisce user_rooms
        for (final p in ownedPlayers) {
          final id = p['id'];
          final isGuest = p['isGuest'] == true;

          if (!isGuest && id != null) {
            await UserRoomRepository(FirebaseFirestore.instance)
                .clearCurrentRoom(id);
          }
        }
      } catch (_) {}

    }();

    return true;
  }


  @override
  Widget build(BuildContext context) {
    final isCurrentUserAdmin =
    data.adminIds.contains(RoomCurrentUser.current.uid);
    final isCreator = isCurrentUserCreator(data);
    final creatorId = getRoomCreatorId(data);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await confirmExit(context);

        if (ok && context.mounted) {
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LOBBY'),

                  const SizedBox(height: 8),

                  Text('SYNC: ${snapshot.connectionState.name}'),

                  const SizedBox(height: 8),

                  Text('ROOM ID: ${liveData.roomId ?? "LOCALE"}'),

                  const SizedBox(height: 8),

                  Text('CREATOR: ${creatorId ?? "-"}'),

                  Text('IS CREATOR: ${isCreator ? "YES" : "NO"}'),

                  const SizedBox(height: 16),

                  GameSelector(
                    config: liveData.game,
                    onChanged: (newGame) async {
                      await repo.update(liveData.copyWith(game: newGame));
                    },
                  ),
                  const SizedBox(height: 16),

                  MatchSelector(
                    config: liveData.matchConfig,
                    onChanged: (newConfig) async {
                      await repo.update(
                        liveData.copyWith(matchConfig: newConfig),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Text('STATO: ${liveData.phase.name}'),

                  const SizedBox(height: 16),

                  const RoomCurrentUserView(),

                  const SizedBox(height: 16),

                  RoomPlayerList(
                    data: liveData,
                    repo: repo,
                  ),

                  const SizedBox(height: 16),

                  Text('ADMINS: ${liveData.adminIds.join(", ")}'),

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
                    child: RoomMatchEngineView(data: liveData, repo: repo,),
                  ),
                  ElevatedButton(
                    onPressed: isCurrentUserAdmin ? () {} : null,
                    child: const Text('Admin Action'),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _invite,
                    child: const Text('Invita'),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: isCurrentUserAdmin
                        ? () async {
                      await repo.update(
                          liveData.initMatch()
                      );
                    }
                        : null,
                    child: const Text('Start match'),
                  ),
                ],
              ),
            );
          },
        ),
      ),

    );
  }
}