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
  int _nextOrder() {
    if (state.players.isEmpty) return 0;
    return state.players.map((p) => p.order).reduce(max) + 1;
  }
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

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

    for (final p in state.players) {
      // 👉 tutti i player creati da questo device
      if (p.ownerUid == uid) {
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
  // -----------------------
  // AUTH
  // -----------------------

  String? get authUid => FirebaseAuth.instance.currentUser?.uid;
  String get currentPlayerId => authUid ?? '';

  // -----------------------
  // HOST
  // -----------------------

  String? _hostId;
  String? get hostId => _hostId;

  bool get isCurrentUserHost {
    final uid = authUid;
    return uid != null && uid == _hostId;
  }
// -----------------------
// INIT ROOM (HOST ENTRY)
// -----------------------

  Future<void> initAsHost() async {
    final uid = authUid;
    if (uid == null) return;

    _hostId = uid;

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
  // -----------------------
  // CORE ROOM ACTIONS
  // -----------------------

  Future<void> participateInRoom() async {
    final uid = authUid;
    if (uid == null) return;

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

    final next = [...state.players, player];

    state = state.copyWith(players: next);
    _ref.read(playerOrderControllerProvider.notifier)
        .syncFromLobby(next);
    await _syncPlayers();
  }

  Future<void> addLocalGuest(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = 'guest_${DateTime.now().millisecondsSinceEpoch}';

    final newPlayer = LobbyPlayerVm(
      id: id,
      name: trimmed,
      isGuest: true,
      connection: ConnectionState.connected,
      ownerUid: authUid,
      order: 0,
      teamId: null,
    );

    if (state.roomId == null) {
      // offline → locale
      final next = [...state.players, newPlayer];
      state = state.copyWith(players: next);

      _ref.read(playerOrderControllerProvider.notifier)
          .syncFromLobby(next);
      return;
    }

    // online → transaction
    await _updatePlayersTransaction(
      roomId: state.roomId!,
      transform: (current) => [...current, newPlayer],
    );
  }

  Future<void> addGuestFromExternalAuth({
    required String externalId,
    required String name,
    String? email,
  }) async {
    final id = 'guest_ext_$externalId';

    final exists = state.players.any((p) => p.ownerUid == externalId);
    if (exists) return;

    final player = LobbyPlayerVm(
      id: id,
      name: name.isNotEmpty ? name : (email ?? 'Guest'),
      isGuest: true,
      connection: ConnectionState.connected,
      ownerUid: authUid,
      order: _nextOrder(),
      teamId: null,
    );

    final next = [...state.players, player];

    state = state.copyWith(players: next);
    _ref.read(playerOrderControllerProvider.notifier)
        .syncFromLobby(next);
    await _syncPlayers();
  }

  Future<void> removePlayer(String playerId) async {
    if (playerId == _hostId) return;

    if (state.roomId == null) {
      final next = state.players.where((p) => p.id != playerId).toList();

      state = state.copyWith(players: next);

      _ref.read(playerOrderControllerProvider.notifier)
          .syncFromLobby(next);
      return;
    }

    await _updatePlayersTransaction(
      roomId: state.roomId!,
      transform: (current) =>
          current.where((p) => p.id != playerId).toList(),
    );
  }

  // -----------------------
  // ROOM CREATION / INVITE
  // -----------------------

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

    // 👉 PRENDE ORDINE LOCALE (UI)
    final ordered = _ref.read(playerOrderControllerProvider).ordered;
    final playersForDb = ordered.isNotEmpty ? ordered : state.players;

    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        'id': roomId,
        'hostId': uid,
        'players': _playersToMap(playersForDb), // 👉 USA LISTA ORDINATA
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

    // 👉 ALLINEA STATO LOCALE ALL'ORDINE SALVATO
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

    if (state.roomId == null) {
      // 👉 offline
      final next = state.players
          .where((p) => p.ownerUid != uid && p.id != uid)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final reindexed = [
        for (int i = 0; i < next.length; i++)
          LobbyPlayerVm(
            id: next[i].id,
            name: next[i].name,
            isGuest: next[i].isGuest,
            connection: next[i].connection,
            ownerUid: next[i].ownerUid,
            order: i,
            teamId: next[i].teamId,
          )
      ];

      state = state.copyWith(players: reindexed);

      _ref.read(playerOrderControllerProvider.notifier)
          .syncFromLobby(reindexed);

      return;
    }

    // 👉 ONLINE = TRANSACTION
    await _updatePlayersTransaction(
      roomId: state.roomId!,
      transform: (players) {
        return players
            .where((p) => p.ownerUid != uid && p.id != uid)
            .toList();
      },
    );
  }
  Future<void> updatePlayersFromOrder(List<LobbyPlayerVm> ordered) async {
    final roomId = state.roomId;
    if (roomId == null) return;

    await _updatePlayersTransaction(
      roomId: roomId,
      transform: (_) => ordered,
    );
  }
  // -----------------------
  // MATCH
  // -----------------------

  Future<Match?> startMatch() async {
    if (!state.canStart) return null;

    state = state.copyWith(roomState: RoomState.inMatch);

    return null;
  }

  // -----------------------
  // DB SYNC
  // -----------------------
  @override
  void dispose() {
    _connectionTimer?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
  Future<void> _syncPlayers() async {
    if (state.roomId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(state.roomId!)
          .set({
        'players': _playersToMap(state.players),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _watchRoom(String roomId) {
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;

      final rawPlayers =
          data['players'] as Map<String, dynamic>? ?? {};

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

      state = state.copyWith(
        players: players,
        isOnline: true,
      );

      _hostId = host;
    });
  }

  String? _extractAuthenticatedUidFromPlayer(LobbyPlayerVm player) {
    if (!player.isGuest) {
      return player.id;
    }

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

  Future<void> _updatePlayersTransaction({
    required String roomId,
    required List<LobbyPlayerVm> Function(List<LobbyPlayerVm>) transform,
  }) async {
    final ref = FirebaseFirestore.instance.collection('rooms').doc(roomId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;

      final raw = data['players'] as Map<String, dynamic>? ?? {};

      final current = raw.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value);
        return LobbyPlayerVm(
          id: e.key,
          name: p['name'],
          isGuest: p['isGuest'],
          connection: ConnectionState.connected,
          ownerUid: p['ownerUid'],
          order: p['order'] ?? 0,
          teamId: p['teamId'],
        );
      }).toList();

      final updated = transform(current);

      // 🔥 RIASSEGNA ORDINI SEMPRE
      for (int i = 0; i < updated.length; i++) {
        updated[i] = LobbyPlayerVm(
          id: updated[i].id,
          name: updated[i].name,
          isGuest: updated[i].isGuest,
          connection: updated[i].connection,
          ownerUid: updated[i].ownerUid,
          order: i,
          teamId: updated[i].teamId,
        );
      }

      tx.update(ref, {
        'players': _playersToMap(updated),
      });
    });
  }





  // -----------------------
// STUB COMPATIBILITÀ (DA RISCRIVERE)
// -----------------------

  bool get isSpectator => false;

  Future<void> joinFromLink(String roomId) async {
    await invite();
  }

  Future<void> joinAsSpectator(String roomId) async {
    // noop
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

  Future<Match?> loadCurrentMatch() async {
    return null;
  }

  Future<void> reopenRoomFromResult() async {
    // noop
  }

  Future<void> markRoomTerminated() async {
    // noop
  }
}
final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController(ref));
