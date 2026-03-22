import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/room_repository.dart';
import '../../data/repositories/user_room_repository.dart';
import '../../domain/models.dart';
import '../../usecases/create_room_usecase.dart';
import '../../usecases/join_room_usecase.dart';

class MultiplayerRoomPage extends StatefulWidget {
  const MultiplayerRoomPage({super.key});

  @override
  State<MultiplayerRoomPage> createState() => _MultiplayerRoomPageState();
}

class _MultiplayerRoomPageState extends State<MultiplayerRoomPage> {
  final _roomIdController = TextEditingController();
  final _roomRepository = RoomRepository(FirebaseFirestore.instance);
  final _userRoomRepository = UserRoomRepository(FirebaseFirestore.instance);
  final _uuid = const Uuid();

  bool _loading = false;
  String? _message;
  String? _currentRoomId;

  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    final raw = user?.displayName?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Player';
  }

  Future<void> _createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _message = 'Devi fare login prima');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final useCase = CreateRoomUseCase(_roomRepository, _userRoomRepository, _uuid);
    final result = await useCase.execute(
      hostUid: user.uid,
      hostDisplayName: _displayName,
      config: const RoomConfig(
        startingScore: 501,
        maxPlayers: 2,
        allowSpectators: true,
      ),
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.isSuccess && result.value != null) {
        _currentRoomId = result.value!.roomId;
        _roomIdController.text = result.value!.roomId;
        _message = 'Room creata: ${result.value!.roomId}';
      } else {
        _message = result.error ?? 'Errore creazione room';
      }
    });
  }

  Future<void> _joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    final roomId = _roomIdController.text.trim();

    if (user == null) {
      setState(() => _message = 'Devi fare login prima');
      return;
    }
    if (roomId.isEmpty) {
      setState(() => _message = 'Inserisci Room ID');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final useCase = JoinRoomUseCase(_roomRepository, _userRoomRepository, _uuid);
    final result = await useCase.execute(
      roomId: roomId,
      authUid: user.uid,
      displayName: _displayName,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.isSuccess && result.value != null) {
        _currentRoomId = roomId;
        _message = 'Entrato nella room: $roomId';
      } else {
        _message = result.error ?? 'Errore ingresso room';
      }
    });
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multiplayer online')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _roomIdController,
            decoration: const InputDecoration(
              labelText: 'Room ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _createRoom,
                  child: const Text('Crea room'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _joinRoom,
                  child: const Text('Entra room'),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_currentRoomId != null) ...[
            const SizedBox(height: 16),
            const Text('Stato room', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            StreamBuilder<RoomSnapshot?>(
              stream: _roomRepository.watchRoom(_currentRoomId!),
              builder: (context, snapshot) {
                final room = snapshot.data;
                if (room == null) {
                  return const Text('Room non trovata');
                }
                final players = room.players.map((p) => p.displayName).join(', ');
                return Text('Room: ${room.roomId}\nStato: ${room.status.name}\nGiocatori: $players');
              },
            ),
          ],
        ],
      ),
    );
  }
}
