import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/link/app_link_state.dart';
import '../../../../core/network/offline_controller.dart';
import '../../../room_v2/games_darts.dart';
import '../../../room_v2/room_current_user.dart';
import '../../../room_v2/room_data.dart';
import '../../../room_v2/room_lobby_v2_page.dart';
import '../../../room_v2/room_repository.dart';
import '../../../room_v2/room_repository_provider.dart';
import '../../../room_v2/room_user_flow.dart';
import '../../../room_v2/user_room_repository.dart';
import '../../../../app/web_url_cleaner.dart';

class GiocaScreen extends ConsumerStatefulWidget {
  const GiocaScreen({super.key});

  @override
  ConsumerState<GiocaScreen> createState() => _GiocaScreenState();
}

class _GiocaScreenState extends ConsumerState<GiocaScreen> {
  bool _handledPendingInvite = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_handlePendingInvite);
  }

  Future<void> _handlePendingInvite() async {
    if (_handledPendingInvite) return;
    _handledPendingInvite = true;

    final coordinator = ref.read(appLinkCoordinatorProvider.notifier);
    final roomId = await coordinator.consumeRoomId();

    if (!mounted || roomId == null || roomId.isEmpty) return;

    final accept = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invito'),
        content: const Text('Vuoi entrare nella partita?'),
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

    cleanUrl();
    await coordinator.clearAll();

    if (accept != true || !mounted) return;

    final roomExists = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get()
        .then((doc) => doc.exists)
        .catchError((_) => false);

    if (!roomExists || !mounted) return;

    final repo = ref.read(roomRepositoryProvider);
    final isOnline = ref.read(offlineControllerProvider);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoomBootstrap(
          repo: repo,
          isOnline: isOnline,
          incomingRoomId: roomId,
        ),
      ),
    );
  }

  void _openManualRoom() {
    final repo = ref.read(roomRepositoryProvider);
    final isOnline = ref.read(offlineControllerProvider);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoomBootstrap(
          repo: repo,
          isOnline: isOnline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text('Room online'),
            subtitle: const Text('Apri la nuova sezione Gioca'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _openManualRoom,
          ),
        ),
      ],
    );
  }
}

class _RoomBootstrap extends StatefulWidget {
  final RoomRepository repo;
  final bool isOnline;
  final String? incomingRoomId;

  const _RoomBootstrap({
    required this.repo,
    required this.isOnline,
    this.incomingRoomId,
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
    final repo = widget.repo;
    final incomingRoomId = widget.incomingRoomId;

    repo.clearLocal();

    if (incomingRoomId != null && incomingRoomId.isNotEmpty) {
      final incomingExists = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(incomingRoomId)
          .get()
          .then((doc) => doc.exists)
          .catchError((_) => false);

      if (!incomingExists) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      repo.connectToRoom(incomingRoomId);

      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    repo.initLocal(
      RoomData(
        roomId: null,
        createdAt: DateTime.now(),
        game: GameConfig.x01(),
        phase: RoomPhase.lobby,
        creatorId: RoomCurrentUser.current.uid,
        adminIds: [RoomCurrentUser.current.uid],
        players: [],
      ),
    );

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
    } catch (_) {}

    if (roomId != null && roomId.isNotEmpty) {
      final roomExists = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get()
          .then((doc) => doc.exists)
          .catchError((_) => false);

      if (!roomExists) {
        try {
          await userRepo.clearCurrentRoom(uid);
        } catch (_) {}

        repo.clearLocal();
        repo.initLocal(
          RoomData(
            roomId: null,
            createdAt: DateTime.now(),
            game: GameConfig.x01(),
            phase: RoomPhase.lobby,
            creatorId: RoomCurrentUser.current.uid,
            adminIds: [RoomCurrentUser.current.uid],
            players: [],
          ),
        );

        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      final shouldRejoin = await _askRejoin(context, roomId);

      if (shouldRejoin) {
        repo.connectToRoom(roomId);
      } else {
        try {
          repo.connectToRoom(roomId);
          await Future.delayed(const Duration(milliseconds: 200));
          await RoomLobbyV2Controller(repo).exitRoom();
        } catch (_) {}

        repo.clearLocal();
        repo.initLocal(
          RoomData(
            roomId: null,
            createdAt: DateTime.now(),
            game: GameConfig.x01(),
            phase: RoomPhase.lobby,
            creatorId: RoomCurrentUser.current.uid,
            adminIds: [RoomCurrentUser.current.uid],
            players: [],
          ),
        );
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