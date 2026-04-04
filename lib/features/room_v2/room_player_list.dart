import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'room_data.dart';
import 'room_repository.dart';
import 'room_current_user.dart';
import 'room_players.dart';
import 'user_room_repository.dart';

class RoomPlayerListController {
  final RoomRepository repo;

  RoomPlayerListController(this.repo);

  List<Map<String, dynamic>> sortPlayers(List<Map<String, dynamic>> players) {
    final list = List<Map<String, dynamic>>.from(players);
    list.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
    return list;
  }

  Future<void> reorder(
      RoomData data,
      List<Map<String, dynamic>> players,
      int oldIndex,
      int newIndex,
      ) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final updated = List<Map<String, dynamic>>.from(players);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    _normalizeOrder(updated);

    await repo.update(data.copyWith(players: updated));
  }

  Future<void> moveUp(
      RoomData data,
      List<Map<String, dynamic>> players,
      int index,
      ) async {
    if (index <= 0) return;

    final updated = List<Map<String, dynamic>>.from(players);
    final temp = updated[index - 1];
    updated[index - 1] = updated[index];
    updated[index] = temp;

    _normalizeOrder(updated);

    await repo.update(data.copyWith(players: updated));
  }

  Future<void> moveDown(
      RoomData data,
      List<Map<String, dynamic>> players,
      int index,
      ) async {
    if (index >= players.length - 1) return;

    final updated = List<Map<String, dynamic>>.from(players);
    final temp = updated[index + 1];
    updated[index + 1] = updated[index];
    updated[index] = temp;

    _normalizeOrder(updated);

    await repo.update(data.copyWith(players: updated));
  }

  Future<void> changeTeamSize(RoomData data, int value) async {
    await repo.update(data.copyWith(teamSize: value));
  }

  Future<void> addPlayer(RoomData data, dynamic player) async {
    final uid = RoomCurrentUser.current.uid;

    final updated =
    data.addPlayer(player, uid).syncAdminsFromPlayers();

    await repo.update(updated);

    if (!player.isGuest && updated.roomId != null) {
      await UserRoomRepository(FirebaseFirestore.instance)
          .setCurrentRoom(player.id, updated.roomId!);
    }
  }

  Future<void> removePlayer(
      RoomData data,
      Map<String, dynamic> player,
      ) async {
    final uid = RoomCurrentUser.current.uid;

    final targetId = player['id'];
    final targetOwner = player['ownerId'];

    final isAdmin = data.adminIds.contains(uid);

    final canRemove =
        isAdmin || targetId == uid || targetOwner == uid;

    if (!canRemove) return;

    final updated =
    data.removePlayerAndReorder(targetId);

    await repo.update(updated);

    final isGuest = player['isGuest'] == true;

    if (!isGuest && targetId != null) {
      await UserRoomRepository(FirebaseFirestore.instance)
          .clearCurrentRoom(targetId);
    }
  }

  void _normalizeOrder(List<Map<String, dynamic>> players) {
    for (int i = 0; i < players.length; i++) {
      players[i]['order'] = i;
    }
  }
}

class RoomPlayerList extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomPlayerList({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final controller = RoomPlayerListController(repo);

    final players = controller.sortPlayers(data.players);

    final currentUserId = RoomCurrentUser.current.uid;
    final isAdmin = data.adminIds.contains(currentUserId);
    final teamSize = data.teamSize;
    final isTeamMode = teamSize > 1;

    return _RoomPlayerListView(
      data: data,
      players: players,
      controller: controller,
      currentUserId: currentUserId,
      isAdmin: isAdmin,
      isTeamMode: isTeamMode,
    );
  }
}

class _RoomPlayerListView extends StatelessWidget {
  final RoomData data;
  final List<Map<String, dynamic>> players;
  final RoomPlayerListController controller;
  final String currentUserId;
  final bool isAdmin;
  final bool isTeamMode;

  const _RoomPlayerListView({
    required this.data,
    required this.players,
    required this.controller,
    required this.currentUserId,
    required this.isAdmin,
    required this.isTeamMode,
  });

  @override
  Widget build(BuildContext context) {
    final teamSize = data.teamSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Mode:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: teamSize,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('FFA')),
                DropdownMenuItem(value: 2, child: Text('2v2')),
                DropdownMenuItem(value: 3, child: Text('3v3')),
                DropdownMenuItem(value: 4, child: Text('4v4')),
              ],
              onChanged: (v) {
                if (v == null) return;
                controller.changeTeamSize(data, v);
              },
            ),
            const SizedBox(width: 12),
            if (!data.isValidTeamSetup())
              const Text(
                'Team non validi',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        RoomPlayersView(
          players: const [],
          currentUserId: currentUserId,
          adminIds: data.adminIds,
          onAddPlayer: (player) =>
              controller.addPlayer(data, player),
          onRemovePlayer: (_) {},
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final id = player['id'];
            final name = player['name'] ?? id;

            final teamIndex =
            isTeamMode ? (index ~/ teamSize) + 1 : null;
            final isFirstOfTeam =
            isTeamMode ? index % teamSize == 0 : false;

            return Column(
              key: ValueKey(id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstOfTeam)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 12, bottom: 6, left: 4),
                    child: Text(
                      'TEAM $teamIndex',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 0),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(
                      'Order: ${player['order'] ?? index}'
                          '${isTeamMode ? ' · TEAM $teamIndex' : ''}',
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward,
                              size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: index == 0
                              ? null
                              : () => controller.moveUp(
                            data,
                            players,
                            index,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward,
                              size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: index == players.length - 1
                              ? null
                              : () => controller.moveDown(
                            data,
                            players,
                            index,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          controller.removePlayer(data, player),
                    ),
                  ),
                ),
              ],
            );
          },
        )
      ],
    );
  }
}