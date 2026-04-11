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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // TEAM
                const Text('Team:'),
                const SizedBox(width: 8),

                DropdownButton<int>(
                  value: teamSize,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No')),
                    DropdownMenuItem(value: 2, child: Text('2v2')),
                    DropdownMenuItem(value: 3, child: Text('3v3')),
                    DropdownMenuItem(value: 4, child: Text('4v4')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    controller.changeTeamSize(data, v);
                  },
                ),

                const SizedBox(width: 16),

                // ADD BUTTON
                ElevatedButton.icon(
                  onPressed: () async {
                    final player = await RoomPlayersController(
                      currentUserId: currentUserId,
                      adminIds: data.adminIds,
                    ).openAddDialog(context);

                    if (player != null) {
                      controller.addPlayer(data, player);
                    }
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Aggiungi'),
                ),

                const SizedBox(width: 12),

                // VALIDATION
                if (!data.isValidTeamSetup())
                  const Text(
                    'Team non validi',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final teamSize = data.teamSize;

            // FFA → lista semplice
            if (!isTeamMode || teamSize <= 1) {
              return Column(
                children: players.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  final name = player['name'] ?? player['id'];

                  return _buildPlayerCard(
                    context,
                    data,
                    players,
                    controller,
                    index,
                    player,
                    name,
                  );
                }).toList(),
              );
            }

            // GROUP BY TEAM
            final teams = <List<Map<String, dynamic>>>[];

            for (int i = 0; i < players.length; i += teamSize) {
              teams.add(
                players.skip(i).take(teamSize).toList(),
              );
            }

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: teams.map((teamPlayers) {
                final teamIndex = teams.indexOf(teamPlayers) + 1;

                return SizedBox(
                  width: isWide ? 260 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEAM $teamIndex',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),

                      ...teamPlayers.map((player) {
                        final index = players.indexOf(player);
                        final name = player['name'] ?? player['id'];

                        return _buildPlayerCard(
                          context,
                          data,
                          players,
                          controller,
                          index,
                          player,
                          name,
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        )
      ],
    );
  }
}

Widget _buildPlayerCard(
    BuildContext context,
    RoomData data,
    List<Map<String, dynamic>> players,
    RoomPlayerListController controller,
    int index,
    Map<String, dynamic> player,
    String name,
    ) {
  final currentUserId = RoomCurrentUser.current.uid;
  final isAdmin = data.adminIds.contains(currentUserId);

  final ownerId = player['ownerId'];
  final playerId = player['id'];

  final canRemove =
      isAdmin || ownerId == currentUserId || playerId == currentUserId;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(context)
            .dividerColor
            .withOpacity(0.15),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.1),
          ),
          child: const Icon(Icons.person, size: 20),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 🔼🔽 SOLO ADMIN
        if (isAdmin)
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: index == 0
                      ? null
                      : () => controller.moveUp(
                    data,
                    players,
                    index,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_upward, size: 22),
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: index == players.length - 1
                      ? null
                      : () => controller.moveDown(
                    data,
                    players,
                    index,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_downward, size: 22),
                  ),
                ),
              ),
            ],
          ),

        // ❌ REMOVE (regole corrette)
        if (canRemove)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () =>
                  controller.removePlayer(data, player),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 22, color: Colors.red),
              ),
            ),
          ),
      ],
    ),
  );
}