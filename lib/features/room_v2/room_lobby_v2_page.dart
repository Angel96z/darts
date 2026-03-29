import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_repository.dart';
import 'room_current_user.dart';
import 'room_players.dart';

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

    if (result == true) {
      final current = repo.current;

      if (current?.roomId != null &&
          current!.adminIds.contains(RoomCurrentUser.current.uid)) {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(current.roomId)
            .delete();
      }

      return true;
    }

    return false;
  }


  @override
  Widget build(BuildContext context) {
    final isCurrentUserAdmin = data.adminIds.contains(RoomCurrentUser.current.uid);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final ok = await _confirmExit(context);

        if (ok && context.mounted) {
          Navigator.pop(context); // unico punto in cui esci dal flow
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Lobby')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('LOBBY'),
              Text('LOBBY - ${data.createdAt.toIso8601String()}'),
              const SizedBox(height: 16),
              Text('Room ID: ${data.roomId ?? "LOCALE"}'),
              Text('STATO: ${data.phase.name}'),
              const SizedBox(height: 16),
              const RoomCurrentUserView(),
              const SizedBox(height: 16),
              RoomPlayersView(
                players: data.players,
                onAddPlayer: (player) async {
                  final currentUserId = RoomCurrentUser.current.uid;
                  final updated =
                  data.addPlayer(player, currentUserId).syncAdminsFromPlayers();
                  await repo.update(updated);
                },
              ),
              const SizedBox(height: 16),
              Text('ADMINS: ${data.adminIds.join(", ")}'),
              const SizedBox(height: 16),
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
                  await repo.update(data.copyWith(phase: RoomPhase.match));
                }
                    : null,
                child: const Text('Start match'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}