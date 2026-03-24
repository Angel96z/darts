import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/blocking_overlay.dart';
import '../../../application/usecases/providers.dart';
import '../../../application/usecases/start_match_usecase.dart';
import '../../../domain/entities/identity.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../../domain/value_objects/identifiers.dart';
import '../../../domain/policies/input_fidelity_policy.dart';
import '../../match/controllers/match_controller.dart';
import 'player_order_controller.dart';


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
      const Duration(seconds: 3),
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
    );
  }

  void _startConnectionMonitoring() {
    _connectionTimer?.cancel();
    _refreshConnectionState();
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 2),
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
    if (uid == null) return;

    if (state.players.length >= 8) {
      return;
    }

    _isSpectator = false;
    final id = 'guest_ext_$uid';
    final exists = state.players.any((p) => p.id == id);
    if (exists) return;

    final player = LobbyPlayerVm(
      id: id,
      name: FirebaseAuth.instance.currentUser?.email ?? 'Player',
      isGuest: true,
      connection: ConnectionState.connected,
      ownerUid: uid,
      order: _nextOrder(),
      teamId: null,
    );

    await _ref.read(playerOrderControllerProvider.notifier).addPlayer(player);
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

    // 🔥 cleanup user_rooms
    final player = state.players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => LobbyPlayerVm(
        id: '',
        name: '',
        isGuest: true,
        connection: ConnectionState.disconnected,
        ownerUid: null,
        order: 0,
        teamId: null,
      ),
    );

    final uid = _extractAuthenticatedUidFromPlayer(player);
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('user_rooms')
            .doc(uid)
            .delete();
      } catch (_) {}
    }

    await _ref
        .read(playerOrderControllerProvider.notifier)
        .removePlayerById(playerId);
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
        'status': 'inRoom',
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
    if (!state.canStart) return null;
    state = state.copyWith(roomState: RoomState.inMatch);
    return null;
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _watchRoom(String roomId) {
    FirebaseFirestore.instance
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
        final isOnline = (now - lastSeen) < 10000;

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
      final status = data['status'] as String? ?? 'inRoom';

      state = state.copyWith(
        players: players,
        isOnline: true,
        roomState: status == 'inGame'
            ? RoomState.inMatch
            : status == 'terminated'
            ? RoomState.closed
            : RoomState.waiting,
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
  Future<Match?> loadCurrentMatch() async => null;
  Future<void> reopenRoomFromResult() async {}
  Future<void> markRoomTerminated() async {}
}

final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController(ref));
