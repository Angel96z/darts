import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../application/usecases/providers.dart';
import '../../../domain/entities/identity.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../../domain/value_objects/identifiers.dart';
import '../../../domain/policies/input_fidelity_policy.dart';
import '../../match/controllers/match_controller.dart';
import 'player_order_controller.dart';
import 'package:flutter/foundation.dart';

class LobbyPlayerVm {
  const LobbyPlayerVm({
    required this.id,
    required this.name,
    required this.isGuest,
    required this.connection,
    required this.ownerUid,
    required this.order,
    required this.teamId,
  });

  final String id;
  final String name;
  final bool isGuest;
  final ConnectionState connection;
  final String? ownerUid;
  final int order;
  final String? teamId;
}


class LobbyConfigVm {
  const LobbyConfigVm({
    required this.variant,
    required this.inMode,
    required this.outMode,
    required this.legs,
    required this.sets,
    required this.gameType,
  });

  final X01Variant variant;
  final InMode inMode;
  final OutMode outMode;
  final int legs;
  final int sets;
  final String gameType;

  LobbyConfigVm copyWith({
    X01Variant? variant,
    InMode? inMode,
    OutMode? outMode,
    int? legs,
    int? sets,
    String? gameType,
  }) {
    return LobbyConfigVm(
      variant: variant ?? this.variant,
      inMode: inMode ?? this.inMode,
      outMode: outMode ?? this.outMode,
      legs: legs ?? this.legs,
      sets: sets ?? this.sets,
      gameType: gameType ?? this.gameType,
    );
  }
}

class LobbyViewModel {
  const LobbyViewModel({
    required this.roomState,
    required this.connection,
    required this.players,
    required this.config,
    required this.isOnline,
    required this.roomId,
    required this.inviteLink,
    required this.watchLink,
    required this.loading,
    required this.currentMatchId,
  });

  final RoomState roomState;
  final ConnectionState connection;
  final List<LobbyPlayerVm> players;
  final LobbyConfigVm config;
  final bool isOnline;
  final String? roomId;
  final String? inviteLink;
  final String? watchLink;
  final OverlayState? loading;
  final String? currentMatchId;

  bool get canStart => players.isNotEmpty;

  LobbyViewModel copyWith({
    RoomState? roomState,
    ConnectionState? connection,
    List<LobbyPlayerVm>? players,
    LobbyConfigVm? config,
    bool? isOnline,
    String? roomId,
    String? inviteLink,
    String? watchLink,
    OverlayState? loading,
    String? currentMatchId,
    bool clearLoading = false,
  }) {
    return LobbyViewModel(
      roomState: roomState ?? this.roomState,
      connection: connection ?? this.connection,
      players: players ?? this.players,
      config: config ?? this.config,
      isOnline: isOnline ?? this.isOnline,
      roomId: roomId ?? this.roomId,
      inviteLink: inviteLink ?? this.inviteLink,
      watchLink: watchLink ?? this.watchLink,
      loading: clearLoading ? null : (loading ?? this.loading),
      currentMatchId: currentMatchId ?? this.currentMatchId,
    );
  }
}

class LobbyController extends StateNotifier<LobbyViewModel> {
  Timer? _heartbeatTimer;
  bool _isSpectator = false;

  int _nextOrder() {
    if (state.players.isEmpty) return 0;
    return state.players.map((p) => p.order).reduce(max) + 1;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (_isSpectator) return;

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) => _ping(),
    );
  }

  Future<void> _ping() async {
    final roomId = state.roomId;
    final uid = authUid;

    if (roomId == null || uid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final updates = <String, dynamic>{};

    // 1. Trova tutti gli ownerUid che questo device controlla
    final controlledOwnerUids = <String>{};

    for (final p in state.players) {
      final isDirectUser = p.id == uid;
      final isExternalGuestOfMe = p.id == 'guest_ext_$uid';

      if (isDirectUser || isExternalGuestOfMe) {
        if (p.ownerUid != null) {
          controlledOwnerUids.add(p.ownerUid!);
        }
        controlledOwnerUids.add(uid);
      }
    }

    if (controlledOwnerUids.isEmpty) return;

    // 2. Aggiorna tutti i player che appartengono a questi owner
    for (final p in state.players) {
      final owner = p.ownerUid;

      if (owner != null && controlledOwnerUids.contains(owner)) {
        updates['players.${p.id}.lastSeen'] = now;
      }

      // fallback: player diretto (non guest)
      if (!p.isGuest && controlledOwnerUids.contains(p.id)) {
        updates['players.${p.id}.lastSeen'] = now;
      }
    }

    if (updates.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .update(updates);
    } catch (_) {}
  }

  Timer? _connectionTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  LobbyController(this._ref) : super(_initial()) {
    _startConnectionMonitoring();
  }
  final Ref _ref;

  static LobbyViewModel _initial() {
    return const LobbyViewModel(
      roomState: RoomState.waiting,
      connection: ConnectionState.connected,
      players: [],
      config: LobbyConfigVm(
        variant: X01Variant.x501,
        inMode: InMode.straightIn,
        outMode: OutMode.doubleOut,
        legs: 1,
        sets: 1,
        gameType: 'X01',
      ),
      isOnline: false,
      roomId: null,
      inviteLink: null,
      watchLink: null,
      loading: null,
      currentMatchId: null,
    );
  }

  void _startConnectionMonitoring() {
    _connectionTimer?.cancel();
    _refreshConnectionState();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 6),
          (_) => _refreshConnectionState(),
    );
  }

  Future<void> _refreshConnectionState() async {
    try {
      final online =
      await _ref.read(backendConnectionServiceProvider).checkBackendConnection();

      state = state.copyWith(
        isOnline: online,
        connection:
        online ? ConnectionState.connected : ConnectionState.disconnected,
      );
    } catch (_) {
      state = state.copyWith(
        isOnline: false,
        connection: ConnectionState.disconnected,
      );
    }
  }

  String? get authUid => FirebaseAuth.instance.currentUser?.uid;
  String get currentPlayerId => authUid ?? '';

  String? _hostId;
  String? get hostId => _hostId;

  bool get isCurrentUserHost {
    final uid = authUid;
    return uid != null && uid == _hostId;
  }

  bool get isSpectator => _isSpectator;

  Future<void> initAsHost() async {
    final uid = authUid;
    if (uid == null) return;

    _hostId = uid;
    _isSpectator = false;

    final exists = state.players.any((p) => p.ownerUid == uid);

    if (!exists) {
      final player = LobbyPlayerVm(
        id: uid,
        name: FirebaseAuth.instance.currentUser?.email ?? 'Player',
        isGuest: false,
        connection: ConnectionState.connected,
        ownerUid: uid,
        order: _nextOrder(),
        teamId: null,
      );

      state = state.copyWith(
        players: [...state.players, player],
      );
    }
  }

  Future<void> participateInRoom() async {
    final uid = authUid;
    final roomId = state.roomId;
    if (uid == null) return;

    if (state.players.length >= 8) return;

    _isSpectator = false;
// L'ID nel database della stanza per questo player
    final playerId = 'guest_ext_$uid';

    final exists = state.players.any((p) => p.id == playerId || p.id == uid);
    if (exists) return;

    final String name = FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Player';

    if (roomId != null) {
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final players = Map<String, dynamic>.from(data['players'] ?? {});

        players[playerId] = {
          'name': name,
          'isGuest': true,
          'ownerUid': uid, // CRUCIALE: salviamo l'UID reale qui
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'order': players.length,
          'teamId': null,
        };

        transaction.update(roomRef, {'players': players});

        // Colleghiamo l'utente alla stanza nella tabella globale
        transaction.set(
          FirebaseFirestore.instance.collection('user_rooms').doc(uid),
          {
            'roomId': roomId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });
    } else {
      // Offline
      final player = LobbyPlayerVm(
        id: playerId,
        name: name,
        isGuest: true,
        connection: ConnectionState.connected,
        ownerUid: uid,
        order: _nextOrder(),
        teamId: null,
      );
      await _ref.read(playerOrderControllerProvider.notifier).addPlayer(player);
      state = state.copyWith(players: _ref.read(playerOrderControllerProvider).ordered);
    }
  }


  Future<LobbyPlayerVm> buildLocalGuestVm(String name) async {
    final id = 'guest_${DateTime.now().millisecondsSinceEpoch}';

    return LobbyPlayerVm(
      id: id,
      name: name,
      isGuest: true,
      connection: ConnectionState.connected,
      ownerUid: authUid,
      order: _nextOrder(),
      teamId: null,
    );
  }

  Future<LobbyPlayerVm> buildExternalGuestVm({
    required String externalId,
    required String email,
  }) async {
    final name = email.split('@').first;

    return LobbyPlayerVm(
      id: 'guest_ext_$externalId',
      name: name,
      isGuest: true,
      connection: ConnectionState.connected,
      ownerUid: authUid,
      order: _nextOrder(),
      teamId: null,
    );
  }

  Future<void> removePlayer(String playerId) async {
    if (playerId == _hostId) return;

    final roomId = state.roomId;
    final orderCtrl = _ref.read(playerOrderControllerProvider.notifier);

// 1. GESTIONE OFFLINE
    if (roomId == null) {
      await orderCtrl.removePlayerById(playerId);
      state = state.copyWith(players: _ref.read(playerOrderControllerProvider).ordered);
      return;
    }

// 2. GESTIONE ONLINE (Pipeline DB -> UI)
    orderCtrl.beginRemoteMutation();

    try {
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> playersMap = Map<String, dynamic>.from(data['players'] ?? {});

        if (playersMap.containsKey(playerId)) {
          // FIX: Estraiamo l'ID pulito per user_rooms
          // Se l'ID è 'guest_ext_ABC', cerchiamo 'ABC' in user_rooms
          String cleanIdForUserRooms = playerId;
          if (playerId.startsWith('guest_ext_')) {
            cleanIdForUserRooms = playerId.replaceFirst('guest_ext_', '');
          }

          // Eliminiamo il binding dell'utente specifico
          transaction.delete(
              FirebaseFirestore.instance.collection('user_rooms').doc(cleanIdForUserRooms)
          );

          // Rimuoviamo il giocatore dalla mappa della stanza
          playersMap.remove(playerId);
          transaction.update(roomRef, {'players': playersMap});
        }
      });
    } catch (e) {
      debugPrint("Errore critico durante la rimozione: $e");
    } finally {
      orderCtrl.endRemoteMutation();
    }
  }

  Future<void> invite() async {
    if (state.roomId != null) {
      state = state.copyWith(
        inviteLink: _buildInviteLink(state.roomId!),
        watchLink: _buildWatchLink(state.roomId!),
        isOnline: true,
      );
      return;
    }

    final roomId =
        'room_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';

    final uid = authUid;
    _hostId = uid;

    final ordered = _ref.read(playerOrderControllerProvider).ordered;
    final playersForDb = ordered.isNotEmpty ? ordered : state.players;
    final orderState = _ref.read(playerOrderControllerProvider);

    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        'id': roomId,
        'hostId': uid,
        'players': _playersToMap(playersForDb),
        'teamSize': orderState.teamSize,
        'teamsEnabled': orderState.teamsEnabled,
        'status': 'waiting',
        'config': {
          'variant': state.config.variant.name,
          'inMode': state.config.inMode.name,
          'outMode': state.config.outMode.name,
          'legs': state.config.legs,
          'sets': state.config.sets,
          'gameType': state.config.gameType,
        }
      });
    } catch (_) {}

    state = state.copyWith(players: playersForDb);

    await _syncUserRoomBindingsForAuthenticatedPlayers(roomId);

    state = state.copyWith(
      roomId: roomId,
      isOnline: true,
      inviteLink: _buildInviteLink(roomId),
      watchLink: _buildWatchLink(roomId),
    );

    _watchRoom(roomId);
    _startHeartbeat();
  }

  Future<void> closeRoom() async {
    final roomId = state.roomId;

    // 🔥 cleanup user_rooms per tutti i player
    for (final player in state.players) {
      final uid = _extractAuthenticatedUidFromPlayer(player);
      if (uid != null && uid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('user_rooms')
              .doc(uid)
              .delete();
        } catch (_) {}
      }
    }

    if (roomId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .delete();
      } catch (_) {}
    }

    _hostId = null;
    state = _initial();
  }

  Future<void> leaveRoom() async {
    final uid = authUid;
    if (uid == null) return;

    final idsToRemove = state.players
        .where((p) => p.ownerUid == uid || p.id == uid)
        .map((p) => p.id)
        .toList();

    for (final id in idsToRemove) {
      final player = state.players.firstWhere((p) => p.id == id);

      final playerUid = _extractAuthenticatedUidFromPlayer(player);
      if (playerUid != null && playerUid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('user_rooms')
              .doc(playerUid)
              .delete();
        } catch (_) {}
      }

      await _ref
          .read(playerOrderControllerProvider.notifier)
          .removePlayerById(id);
    }
  }

  Future<void> updatePlayersFromOrder(List<LobbyPlayerVm> ordered) async {
    final roomId = state.roomId;
    if (roomId == null) return;

    final orderState = _ref.read(playerOrderControllerProvider);

    // 🔥 SYNC user_rooms: aggiungi nuovi + rimuovi vecchi
    final current = state.players;
    final currentUids = current
        .map(_extractAuthenticatedUidFromPlayer)
        .whereType<String>()
        .toSet();

    final nextUids = ordered
        .map(_extractAuthenticatedUidFromPlayer)
        .whereType<String>()
        .toSet();

    final toRemove = currentUids.difference(nextUids);
    final toAdd = nextUids.difference(currentUids);

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final uid in toRemove) {
      batch.delete(db.collection('user_rooms').doc(uid));
    }

    for (final player in ordered) {
      final uid = _extractAuthenticatedUidFromPlayer(player);
      if (uid == null || !toAdd.contains(uid)) continue;

      batch.set(
        db.collection('user_rooms').doc(uid),
        {
          'roomId': roomId,
          'playerId': player.id,
          'ownerUid': player.ownerUid,
          'updatedAt': now,
        },
      );
    }

    await batch.commit();

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .set({
      'players': _playersToMap(ordered),
      'teamSize': orderState.teamSize,
      'teamsEnabled': orderState.teamsEnabled,
    }, SetOptions(merge: true));
  }


  Future<Match?> startMatch() async {
    final roomId = state.roomId;
    if (roomId == null || state.players.isEmpty) return null;
    if (!isCurrentUserHost) return null;
    if (state.roomState == RoomState.closed || state.roomState == RoomState.inMatch) {
      return null;
    }

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final matchId = FirebaseFirestore.instance.collection('matches').doc().id;
    final match = _buildInitialMatch(roomId: roomId, matchId: matchId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) {
        throw StateError('ROOM_NOT_FOUND');
      }
      final status = (snap.data()?['status'] as String?) ?? 'waiting';
      if (status == 'inMatch') {
        throw StateError('MATCH_ALREADY_RUNNING');
      }
      if (status == 'closed' || status == 'terminated') {
        throw StateError('ROOM_CLOSED');
      }
      tx.set(
        roomRef,
        {
          'status': 'inMatch',
          'currentMatchId': matchId,
          'startedAt': FieldValue.serverTimestamp(),
          'finishedAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });

    await _ref.read(matchRepositoryProvider).saveMatch(match);
    state = state.copyWith(
      roomState: RoomState.inMatch,
      currentMatchId: matchId,
      clearLoading: true,
    );
    return match;
  }


  @override
  void dispose() {
    _connectionTimer?.cancel();
    _heartbeatTimer?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  void _watchRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) {
        state = state.copyWith(loading: OverlayState.error);
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final rawPlayers = data['players'] as Map<String, dynamic>? ?? {};

      final players = rawPlayers.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value);
        final lastSeen = p['lastSeen'] as int? ?? 0;
        final isOnline = (now - lastSeen) < 25000;

        return LobbyPlayerVm(
          id: e.key,
          name: p['name'] ?? 'Guest',
          isGuest: p['isGuest'] ?? true,
          connection: isOnline
              ? ConnectionState.connected
              : ConnectionState.disconnected,
          ownerUid: p['ownerUid'],
          order: p['order'] ?? 0,
          teamId: p['teamId'],
        );
      }).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final host = data['hostId'] as String?;
      final teamSize = data['teamSize'] as int? ?? 1;
      final teamsEnabled = data['teamsEnabled'] as bool? ?? false;
      final status = data['status'] as String? ?? 'waiting';
      final currentMatchId = data['currentMatchId'] as String?;

      state = state.copyWith(
        players: players,
        isOnline: true,
        currentMatchId: currentMatchId,
        loading: null,
        roomState: _mapRemoteStatus(status),
      );

      final orderCtrl = _ref.read(playerOrderControllerProvider.notifier);
      orderCtrl.syncFromLobby(players);

      if (orderCtrl.state.teamSize != teamSize ||
          orderCtrl.state.teamsEnabled != teamsEnabled) {
        orderCtrl.state = orderCtrl.state.copyWith(
          teamSize: teamSize,
          teamsEnabled: teamsEnabled,
        );
      }

      _hostId = host;

    });
  }

  RoomState _mapRemoteStatus(String status) {
    switch (status) {
      case 'ready':
        return RoomState.ready;
      case 'inMatch':
      case 'inGame':
        return RoomState.inMatch;
      case 'finished':
        return RoomState.finished;
      case 'closed':
      case 'terminated':
        return RoomState.closed;
      case 'draft':
        return RoomState.draft;
      case 'locked':
        return RoomState.locked;
      case 'waiting':
      case 'inRoom':
      default:
        return RoomState.waiting;
    }
  }

  String? _extractAuthenticatedUidFromPlayer(LobbyPlayerVm player) {
    if (!player.isGuest) return player.id;
    if (player.id.startsWith('guest_ext_')) {
      return player.id.replaceFirst('guest_ext_', '');
    }
    return null;
  }

  Future<void> _syncUserRoomBindingsForAuthenticatedPlayers(String roomId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final player in state.players) {
      final playerUid = _extractAuthenticatedUidFromPlayer(player);
      if (playerUid == null || playerUid.isEmpty) continue;

      batch.set(
        db.collection('user_rooms').doc(playerUid),
        {
          'roomId': roomId,
          'playerId': player.id,
          'ownerUid': player.ownerUid,
          'updatedAt': now,
        },
      );
    }
    await batch.commit();
  }

  Map<String, dynamic> _playersToMap(List<LobbyPlayerVm> players) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      for (final p in players)
        p.id: {
          'name': p.name,
          'isGuest': p.isGuest,
          'connected': p.connection == ConnectionState.connected,
          'ownerUid': p.ownerUid,
          'lastSeen': now,
          'order': p.order,
          'teamId': p.teamId,
        }
    };
  }

  String _buildInviteLink(String roomId) {
    return Uri(
      scheme: 'https',
      host: 'dartsroses.netlify.app',
      queryParameters: {'roomId': roomId},
    ).toString();
  }

  String _buildWatchLink(String roomId) {
    return Uri(
      scheme: 'https',
      host: 'dartsroses.netlify.app',
      queryParameters: {'watchRoomId': roomId},
    ).toString();
  }

  Future<void> joinFromLink(String roomId) async {
    if (roomId.isEmpty) return;
    _hostId = null;
    _isSpectator = false;
    state = state.copyWith(roomId: roomId, isOnline: true);
    _watchRoom(roomId);
    _startHeartbeat();
  }

  Future<void> joinAsSpectator(String roomId) async {
    if (roomId.isEmpty) return;
    _hostId = null;
    _isSpectator = true;
    state = state.copyWith(roomId: roomId, isOnline: true);
    _watchRoom(roomId);
  }

  void updateConfig({
    X01Variant? variant,
    InMode? inMode,
    OutMode? outMode,
    int? legs,
    int? sets,
    String? gameType,
  }) {
    final next = state.config.copyWith(
      variant: variant,
      inMode: inMode,
      outMode: outMode,
      legs: legs,
      sets: sets,
      gameType: gameType,
    );
    state = state.copyWith(config: next);
  }
  Future<void> autoRejoinRoomIfNeeded() async {
    final uid = authUid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_rooms')
          .doc(uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final roomId = data['roomId'] as String?;
      if (roomId == null || roomId.isEmpty) return;

      _hostId = null;
      _isSpectator = false;

      state = state.copyWith(
        roomId: roomId,
        isOnline: true,
      );

      _watchRoom(roomId);
      _startHeartbeat();
    } catch (_) {}
  }
  Future<Match?> loadCurrentMatch() async {
    final roomId = state.roomId;
    final currentMatchId = state.currentMatchId;
    if (roomId == null || currentMatchId == null || currentMatchId.isEmpty) {
      return null;
    }
    return _ref
        .read(matchRepositoryProvider)
        .getMatch(RoomId(roomId), MatchId(currentMatchId));
  }

  Future<void> reopenRoomFromResult() async {
    final roomId = state.roomId;
    if (roomId == null) {
      state = state.copyWith(roomState: RoomState.waiting);
      return;
    }

    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'status': 'waiting',
      'currentMatchId': FieldValue.delete(),
      'finishedAt': FieldValue.delete(),
    }, SetOptions(merge: true));

    state = state.copyWith(roomState: RoomState.waiting, currentMatchId: null);
  }

  Future<void> markRoomTerminated() async {
    final roomId = state.roomId;
    if (roomId == null) {
      state = state.copyWith(roomState: RoomState.closed);
      return;
    }

    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    state = state.copyWith(roomState: RoomState.closed);
  }

  Future<void> markRoomFinished() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'status': 'finished',
      'finishedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    state = state.copyWith(roomState: RoomState.finished);
  }

  Match _buildInitialMatch({required String roomId, required String matchId}) {
    final sortedPlayers = [...state.players]..sort((a, b) => a.order.compareTo(b.order));
    final slots = <PlayerSlot>[];
    final scores = <PlayerId, int>{};
    for (final p in sortedPlayers) {
      final pid = PlayerId(p.id);
      slots.add(PlayerSlot(playerId: pid, order: p.order));
      scores[pid] = _variantScore(state.config.variant);
    }
    final currentPlayer = slots.isNotEmpty ? slots.first.playerId : const PlayerId('');

    return Match(
      id: MatchId(matchId),
      roomId: RoomId(roomId),
      config: MatchConfig(
        gameType: GameType.x01,
        variant: state.config.variant,
        inMode: state.config.inMode,
        outMode: state.config.outMode,
        matchMode: MatchMode.legsOnly,
        legsTargetType: MatchTargetType.firstTo,
        legsTargetValue: state.config.legs,
        setsTargetType: null,
        setsTargetValue: null,
        teamMode: TeamMode.solo,
        teamSharedScore: false,
        finishConstraintEnabled: false,
        undoRequiresHost: true,
        inputSnapshot: const {},
      ),
      roster: MatchRoster(players: slots, teams: const []),
      snapshot: MatchStateSnapshot(
        matchState: MatchState.turnActive,
        status: MatchStatus.active,
        currentSet: 1,
        currentLeg: 1,
        currentTurn: 1,
        scoreboard: Scoreboard(
          playerScores: scores,
          teamScores: const {},
          currentTurnPlayerId: currentPlayer,
        ),
        lastTurns: const [],
      ),
      legs: const [],
      sets: const [],
      result: null,
      createdAt: DateTime.now(),
    );
  }

  int _variantScore(X01Variant variant) {
    switch (variant) {
      case X01Variant.x101:
        return 101;
      case X01Variant.x180:
        return 180;
      case X01Variant.x301:
        return 301;
      case X01Variant.x501:
        return 501;
      case X01Variant.x701:
        return 701;
      case X01Variant.x1001:
        return 1001;
    }
  }


}

final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController(ref));
