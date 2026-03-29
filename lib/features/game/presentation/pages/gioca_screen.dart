/// File: gioca_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/offline_controller.dart';
import '../../../room_v2/games_darts.dart';
import '../../../room_v2/room_current_user.dart';
import '../../../room_v2/room_data.dart';
import '../../../room_v2/room_repository.dart';
import '../../../room_v2/room_user_flow.dart';
import '../../../room_v2/user_room_repository.dart';

class GiocaScreen extends ConsumerWidget {
  const GiocaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(offlineControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isOnline ? 'Online' : 'Offline'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('Room online'),
            subtitle: const Text('Apri la nuova sezione Gioca'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    final repo = RoomRepository(FirebaseFirestore.instance);

                    repo.initLocal(RoomData(
                      roomId: null,
                      createdAt: DateTime.now(),
                      game: GameConfig.x01(),
                      phase: RoomPhase.lobby,
                      creatorId: RoomCurrentUser.current.uid,
                      adminIds: [RoomCurrentUser.current.uid],
                      players: [],
                    ));

                    return _RoomBootstrap(
                      repo: repo,
                      isOnline: isOnline,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoomBootstrap extends StatefulWidget {
  final RoomRepository repo;
  final bool isOnline;

  const _RoomBootstrap({
    required this.repo,
    required this.isOnline,
  });

  @override
  State<_RoomBootstrap> createState() => _RoomBootstrapState();
}

class _RoomBootstrapState extends State<_RoomBootstrap> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!widget.isOnline) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final uid = RoomCurrentUser.current.uid;
    final userRepo = UserRoomRepository(FirebaseFirestore.instance);

    String? roomId;

    try {
      roomId = await userRepo.getCurrentRoom(uid);
    } catch (_) {
      roomId = null;
    }

    if (roomId != null && roomId.isNotEmpty) {
      final shouldRejoin = await _askRejoin(context, roomId);

      if (shouldRejoin) {
        try {
          widget.repo.connectToRoom(roomId);
        } catch (_) {}
      } else {
        try {
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .get();

          if (roomDoc.exists) {
            final data = roomDoc.data()!;

            final isCreator = data['creatorId'] == uid;

            if (isCreator) {
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(roomId)
                  .delete();
            }
          }
        } catch (_) {}

        try {
          await userRepo.clearCurrentRoom(uid);
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return RoomGate(repo: widget.repo);
  }

  Future<bool> _askRejoin(BuildContext context, String roomId) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Room trovata'),
        content: Text('Vuoi rientrare nella room $roomId?'),
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
    ) ??
        false;
  }
}