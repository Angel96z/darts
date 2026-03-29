import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'room_data.dart';
import 'room_repository.dart';
import 'room_current_user.dart';
import 'room_players.dart';
import 'user_room_repository.dart';

class RoomPlayerList extends StatefulWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomPlayerList({
    super.key,
    required this.data,
    required this.repo,
  });

  @override
  State<RoomPlayerList> createState() => _RoomPlayerListState();
}

class _RoomPlayerListState extends State<RoomPlayerList> {
  late List<Map<String, dynamic>> _players;

  @override
  void initState() {
    super.initState();
    _syncFromRemote();
  }

  @override
  void didUpdateWidget(covariant RoomPlayerList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldHash = _hash(oldWidget.data.players);
    final newHash = _hash(widget.data.players);

    if (oldHash != newHash) {
      _syncFromRemote();
    }
  }

  String _hash(List players) {
    return players.map((e) => '${e['id']}-${e['order']}').join('|');
  }

  void _syncFromRemote() {
    _players = List<Map<String, dynamic>>.from(widget.data.players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final updated = List<Map<String, dynamic>>.from(_players);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    for (int i = 0; i < updated.length; i++) {
      updated[i]['order'] = i;
    }

    setState(() {
      _players = updated;
    });

    await widget.repo.update(widget.data.copyWith(players: updated));
  }

  Future<void> _moveUp(int index) async {
    if (index <= 0) return;

    final updated = List<Map<String, dynamic>>.from(_players);
    final temp = updated[index - 1];
    updated[index - 1] = updated[index];
    updated[index] = temp;

    for (int i = 0; i < updated.length; i++) {
      updated[i]['order'] = i;
    }

    setState(() {
      _players = updated;
    });

    await widget.repo.update(widget.data.copyWith(players: updated));
  }

  Future<void> _moveDown(int index) async {
    if (index >= _players.length - 1) return;

    final updated = List<Map<String, dynamic>>.from(_players);
    final temp = updated[index + 1];
    updated[index + 1] = updated[index];
    updated[index] = temp;

    for (int i = 0; i < updated.length; i++) {
      updated[i]['order'] = i;
    }

    setState(() {
      _players = updated;
    });

    await widget.repo.update(widget.data.copyWith(players: updated));
  }
  @override
  Widget build(BuildContext context) {
    final currentUserId = RoomCurrentUser.current.uid;
    final isAdmin = widget.data.adminIds.contains(currentUserId);
    final teamSize = widget.data.teamSize;
    final isTeamMode = teamSize > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Mode:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: widget.data.teamSize,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('FFA')),
                DropdownMenuItem(value: 2, child: Text('2v2')),
                DropdownMenuItem(value: 3, child: Text('3v3')),
                DropdownMenuItem(value: 4, child: Text('4v4')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await widget.repo.update(widget.data.copyWith(teamSize: v));
              },
            ),
            const SizedBox(width: 12),
            if (!widget.data.isValidTeamSetup())
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
          adminIds: widget.data.adminIds,
          onAddPlayer: (player) async {
            final updated = widget.data
                .addPlayer(player, currentUserId)
                .syncAdminsFromPlayers();

            await widget.repo.update(updated);

            if (!player.isGuest && updated.roomId != null) {
              await UserRoomRepository(FirebaseFirestore.instance)
                  .setCurrentRoom(player.id, updated.roomId!);
            }
          },
          onRemovePlayer: (_) {},
        ),

        const SizedBox(height: 8),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _players.length,
          itemBuilder: (context, index) {
            final player = _players[index];
            final id = player['id'];
            final name = player['name'] ?? id;

            final teamSize = widget.data.teamSize;
            final isTeamMode = teamSize > 1;

            final teamIndex = isTeamMode ? (index ~/ teamSize) + 1 : null;
            final isFirstOfTeam = isTeamMode ? index % teamSize == 0 : false;

            return Column(
              key: ValueKey(id),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstOfTeam)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                    child: Text(
                      'TEAM $teamIndex',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
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
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: index == 0 ? null : () => _moveUp(index),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: index == _players.length - 1
                              ? null
                              : () => _moveDown(index),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final uid = currentUserId;
                        final targetId = player['id'];
                        final targetOwner = player['ownerId'];

                        final canRemove = isAdmin ||
                            targetId == uid ||
                            targetOwner == uid;

                        if (!canRemove) return;

                        final updated =
                        widget.data.removePlayerAndReorder(targetId);

                        await widget.repo.update(updated);

                        final isGuest = player['isGuest'] == true;

                        if (!isGuest && targetId != null) {
                          await UserRoomRepository(
                            FirebaseFirestore.instance,
                          ).clearCurrentRoom(targetId);
                        }
                      },
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