import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/room_match_page.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:darts/features/room_v2/room_user_flow.dart';
import 'package:flutter/material.dart';

class RoomLobbyV2Page extends StatefulWidget {
  const RoomLobbyV2Page({super.key});

  @override
  State<RoomLobbyV2Page> createState() => _RoomLobbyV2PageState();
}

class _RoomLobbyV2PageState extends State<RoomLobbyV2Page> {
  late final RoomRepository _repo;

  @override
  void initState() {
    super.initState();

    _repo = RoomRepository(FirebaseFirestore.instance);

    _repo.initLocal(
      RoomData(
        roomId: null,
        createdAt: DateTime.now(),
        gameMode: GameMode.x01,
        x01: X01Variant.x501,
        matchStarted: false,
        matchFinished: false,
      ),
    );
  }

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final current = _repo.current;
    if (current == null) return;
    if (current.roomId != null) return;

    await _repo.createOnline();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await _confirmExit(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lobby'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmExit(context);
              if (ok && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: StreamBuilder<RoomData>(
          stream: _repo.watch(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('LOBBY'),
                  Text('LOBBY - ${data.createdAt.toIso8601String()}'),

                  const SizedBox(height: 16),

                  Text('Room ID: ${data.roomId ?? "LOCALE"}'),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _invite,
                    child: const Text('Invita'),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      await _repo.update(
                        data.copyWith(matchStarted: true),
                      );
                      if (context.mounted) {
                        goToMatch(context);
                      }
                    },
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
      final current = _repo.current;

      if (current?.roomId != null) {
        final db = FirebaseFirestore.instance;
        await db.collection('rooms').doc(current!.roomId).delete();
      }

      return true;
    }

    return false;
  }
}