// TARGET: Schermata principale "Gioca" - punto di ingresso per le room V4
// LOGIC GOAL: Gestire deep link, inviti e auto-rejoin per la nuova room V4
// REACTION: Navigazione verso RoomLobbyPage (V4) o gestione inviti
// ERROR STRATEGY: Gestione offline e timeout per operazioni remote
// ANTI-REGRESSION: Mantenere dialogo conferma invito, gestione offline, auto-rejoin

// TARGET: Schermata principale "Gioca" - SOLO OFFLINE
// LOGIC GOAL: Navigare direttamente alla Room V4 senza bootstrap/inviti/auto-rejoin
// REACTION: Tap sul bottone → RoomLobbyPage
// ERROR STRATEGY: N/A (tutto locale)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../room_v4/presentation/room_lobby_page.dart';

class GiocaScreen extends ConsumerWidget {
  const GiocaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.new_releases, color: Colors.green),
            title: const Text('ROOM V4 (NUOVA ARCHITETTURA)'),
            subtitle: const Text('Match completo X01/Cricket - Lobby + Partita'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomLobbyPage()),
              );
            },
          ),
        ),
      ],
    );
  }
}
/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darts/app/link/app_link_state.dart';
import 'package:darts/app/web_url_cleaner.dart';
import 'package:darts/core/network/offline_controller.dart';
import 'package:darts/features/room_v2/application/room_notifier.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/room_gate.dart';
import 'package:darts/features/room_v2/user_room_repository.dart';
import 'package:darts/features/room_v4/presentation/room_lobby_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../string_test/presentation/string_test_page.dart';

class GiocaScreen extends ConsumerStatefulWidget {
  const GiocaScreen({super.key});

  @override
  ConsumerState<GiocaScreen> createState() => _GiocaScreenState();
}

class _GiocaScreenState extends ConsumerState<GiocaScreen> {
  bool _handledPendingInvite = false;
  bool _openingRoom = false;
  bool _openingRoomV4 = false;

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
            child: const Text('Sì'),
          ),
        ],
      ),
    );

    cleanUrl();
    await coordinator.clearAll();

    if (accept != true || !mounted) return;

    final isOnline = ref.read(offlineControllerProvider);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoomBootstrapV4(
          isOnline: isOnline,
          incomingRoomId: roomId,
        ),
      ),
    );
  }

  Future<void> _openManualRoomV4() async {
    if (_openingRoomV4) return;
    _openingRoomV4 = true;

    final isOnline = ref.read(offlineControllerProvider);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _RoomBootstrapV4(isOnline: isOnline),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingRoomV4 = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.new_releases, color: Colors.green),
            title: const Text('ROOM V4 (NUOVA ARCHITETTURA)'),
            subtitle: const Text('Match completo X01/Cricket - Lobby + Partita'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _openingRoomV4 ? null : _openManualRoomV4,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.text_fields, color: Colors.deepPurple),
            title: const Text('Test Stringa Firestore'),
            subtitle: const Text('Salva, carica, modifica e cancella una stringa'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StringTestPage()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoomBootstrapV4 extends ConsumerStatefulWidget {
  final bool isOnline;
  final String? incomingRoomId;

  const _RoomBootstrapV4({required this.isOnline, this.incomingRoomId});

  @override
  ConsumerState<_RoomBootstrapV4> createState() => _RoomBootstrapV4State();
}

class _RoomBootstrapV4State extends ConsumerState<_RoomBootstrapV4> {
  bool _didStart = false;
  bool _rejoinDialogOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startBootstrap);
  }

  Future<void> _startBootstrap() async {
    if (_didStart) return;
    _didStart = true;

    final incomingRoomId = widget.incomingRoomId;

    // Se c'è un invito in arrivo, gestiscilo
    if (incomingRoomId != null && incomingRoomId.isNotEmpty) {
      await _handleIncomingInvite(incomingRoomId);
      return;
    }

    // Se non online, vai direttamente alla lobby locale
    if (!widget.isOnline) {
      _navigateToLobby();
      return;
    }

    // Prova auto-rejoin
    await _tryAutoRejoin();
  }

  Future<void> _handleIncomingInvite(String roomId) async {
    // Verifica se la room esiste su Firestore
    final roomExists = await FirebaseFirestore.instance
        .collection('rooms_v4')
        .doc(roomId)
        .get()
        .timeout(const Duration(seconds: 4))
        .then((doc) => doc.exists)
        .catchError((_) => false);

    if (!roomExists) {
      // Room non trovata, vai a lobby vuota
      _navigateToLobby();
      return;
    }

    // TODO: Implementare load della room V4 quando sarà online
    // Per ora, naviga alla lobby vuota
    _navigateToLobby();
  }

  Future<void> _tryAutoRejoin() async {
    final uid = RoomCurrentUser.current.uid;
    final userRepo = UserRoomRepository(FirebaseFirestore.instance);

    String? roomId;
    try {
      roomId = await userRepo
          .getCurrentRoom(uid)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    } catch (_) {
      roomId = null;
    }

    if (!mounted || roomId == null || roomId.isEmpty) {
      _navigateToLobby();
      return;
    }

    final roomExists = await FirebaseFirestore.instance
        .collection('rooms_v4')
        .doc(roomId)
        .get()
        .timeout(const Duration(seconds: 3))
        .then((doc) => doc.exists)
        .catchError((_) => false);

    if (!roomExists) {
      try {
        await userRepo.clearCurrentRoom(uid);
      } catch (_) {}
      _navigateToLobby();
      return;
    }

    if (_rejoinDialogOpen || !mounted) return;
    _rejoinDialogOpen = true;

    final shouldRejoin = await _askRejoin(roomId);

    _rejoinDialogOpen = false;
    if (!mounted) return;

    if (!shouldRejoin) {
      try {
        await userRepo.clearCurrentRoom(uid);
      } catch (_) {}
      _navigateToLobby();
      return;
    }

    // TODO: Implementare load della room V4 quando sarà online
    _navigateToLobby();
  }

  Future<bool> _askRejoin(String roomId) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Partita trovata'),
        content: Text('Vuoi rientrare nella partita $roomId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _navigateToLobby() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const RoomLobbyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}*/