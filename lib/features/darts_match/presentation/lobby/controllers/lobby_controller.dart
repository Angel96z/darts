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


class LobbyPlayerVm {
  const LobbyPlayerVm({
    required this.id,
    required this.name,
    required this.isGuest,
    required this.connection,
    required this.ownerUid,
  });

  final String id;
  final String name;
  final bool isGuest;
  final ConnectionState connection;
  final String? ownerUid;
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
  void _debugDump(String reason) {
    final vm = state;

    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now().toIso8601String();

    // ignore: avoid_print
    print('========== LOBBY EVENT DEBUG ==========');
    // ignore: avoid_print
    print('event: $reason');
    // ignore: avoid_print
    print('timestamp: $now');

    // ignore: avoid_print
    print('--- AUTH ---');
    // ignore: avoid_print
    print('uid: ${user?.uid}');
    // ignore: avoid_print
    print('isAnonymous: ${user?.isAnonymous}');

    // ignore: avoid_print
    print('--- ROOM ---');
    // ignore: avoid_print
    print('isOnline: ${vm.isOnline}');
    // ignore: avoid_print
    print('playersCount: ${vm.players.length}');
    // ignore: avoid_print
    print('canStart: ${vm.canStart}');

    // ignore: avoid_print
    print('--- CONFIG ---');
    // ignore: avoid_print
    print('gameType: ${vm.config.gameType}');
    // ignore: avoid_print
    print('variant: ${vm.config.variant}');
    // ignore: avoid_print
    print('inMode: ${vm.config.inMode}');
    // ignore: avoid_print
    print('outMode: ${vm.config.outMode}');
    // ignore: avoid_print
    print('legs: ${vm.config.legs}');
    // ignore: avoid_print
    print('sets: ${vm.config.sets}');

    // ignore: avoid_print
    print('--- PLAYERS ---');
    for (final p in vm.players) {
      final isHost = p.id == hostId;
      final isSelf = p.id == currentPlayerId;

      // ignore: avoid_print
      print(
        '${p.id} | ${p.name} | guest=${p.isGuest} | '
            'ownerUid=${p.ownerUid} | '
            'connection=${p.connection.name} | '
            'host=$isHost | self=$isSelf',
      );
    }

    // ignore: avoid_print
    print('======================================');
  }
  bool _isSpectator = false;
  bool get isSpectator => _isSpectator;
  Timer? _connectionTimer;


  Future<void> addGuestFromExternalAuth({
    required String externalId,
    required String name,
    String? email,
  }) async {
    if (_isSpectator) return;
    final id = 'guest_ext_$externalId';
    final appUser = FirebaseAuth.instance.currentUser;

// se è lo stesso utente del device → NON aggiungerlo
    if (appUser != null && appUser.uid == externalId) {
      state = state.copyWith(
        loading: OverlayState.error,
      );

      // reset dopo breve delay
      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(clearLoading: true);
      });

      return;
    }
    final exists = state.players.any((p) => p.id == id);

    if (exists) {
      state = state.copyWith(loading: OverlayState.error);

      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(clearLoading: true);
      });

      return;
    }
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;

    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: name.isNotEmpty ? name : (email ?? 'Guest'),
          isGuest: true,
          connection: ConnectionState.connected,
          ownerUid: ownerUid,
        ),
      ],
    );

    _debugDump('player_added_external');
    await _syncPlayers();
// salva per resume
    try {
      final uid = externalId;

      await FirebaseFirestore.instance
          .collection('user_rooms')
          .doc(uid)
          .set({
        'roomId': state.roomId,
        'joinedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
  LobbyViewModel _initialState() {
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
  String? _joiningRoomId;
  String? _hostId;
  String? get hostId => _hostId;
  String get currentPlayerId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String? get isCurrentUserHostId => _hostId;
  bool get isCurrentUserHost {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _hostId;
  }
  bool get isCurrentUserPlayer {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return state.players.any((p) => p.id == uid || p.id == 'guest_ext_$uid');
  }


  Future<void> leaveRoom() async {
    _debugDump('player_left');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final spectatorId = uid ?? 'anon_device';
// NON bloccare spectator anon
    final isAnon = uid == null;
    final currentRoomId = state.roomId;
    final wasSpectator = _isSpectator;

    if (wasSpectator && currentRoomId != null && await _refreshBackendConnection()) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(currentRoomId)
            .update({
          'spectators.$spectatorId': FieldValue.delete(),
        });
      } catch (_) {}
    }

    _isSpectator = false;
    _roomSub?.cancel();

    final next = state.players
        .where((p) =>
    p.ownerUid != uid &&
        p.id != uid &&
        p.id != 'guest_ext_$uid')
        .toList();

    if (!isAnon && currentRoomId != null && await _refreshBackendConnection()) {

      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(currentRoomId)
            .set({
          'players': _playersToMap(next),
        }, SetOptions(merge: true));
        try {
          await FirebaseFirestore.instance
              .collection('user_rooms')
              .doc(uid)
              .delete();
        } catch (_) {}
      } catch (_) {
        _setOffline();
      }
    }

    _hostId = null;

    state = _initialState();
    await _autoAddAuthenticatedUser();

    // 🔥 FIX: rimuove qualsiasi loading attivo
    state = state.copyWith(clearLoading: true);
  }

  LobbyController(this._ref) : super(_emptyInitialState()) {
    state = _initialState();

    _startConnectionMonitoring(); // 👈 AGGIUNGI QUESTO

    _autoAddAuthenticatedUser();
  }
  void _startConnectionMonitoring() {
    _connectionTimer?.cancel();

    // 👇 CHECK IMMEDIATO
    _refreshBackendConnection();

    _connectionTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final prev = state.isOnline;

      final now = await _ref
          .read(backendConnectionServiceProvider)
          .checkBackendConnection();

      if (prev != now) {
        state = state.copyWith(
          isOnline: now,
          connection: now
              ? ConnectionState.connected
              : ConnectionState.disconnected,
        );
      }
    });
  }
  static LobbyViewModel _emptyInitialState() {
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

  final Ref _ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  Future<bool> _refreshBackendConnection() async {
    final ok = await _ref
        .read(backendConnectionServiceProvider)
        .checkBackendConnection();

    state = state.copyWith(
      isOnline: ok,
      connection:
      ok ? ConnectionState.connected : ConnectionState.disconnected,
    );

    return ok;
  }

  void _setOffline() {
    state = state.copyWith(
      isOnline: false,
      connection: ConnectionState.disconnected,
      clearLoading: true,
    );
  }

  void _setLoading(String step) {
    state = state.copyWith(loading: OverlayState.loading, roomState: RoomState.waiting);
  }

  Future<void> _autoAddAuthenticatedUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = user.uid;
    final name = user.displayName ?? user.email ?? 'Player';

    final exists = state.players.any((p) => p.id == id);
    if (exists) return;

    final updatedPlayers = [
      ...state.players,
      LobbyPlayerVm(
        id: id,
        name: name,
        isGuest: false,
        connection: ConnectionState.connected,
        ownerUid: id,
      ),
    ];

    state = state.copyWith(players: updatedPlayers);

    if (_hostId == null) {
      _hostId = id;
    }
  }


  Future<void> joinAsSpectator(String roomId) async {
    _isSpectator = true;
    _roomSub?.cancel();
    _hostId = null;
    state = _initialState();

    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();

    if (!snap.exists) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final spectatorId = uid ?? 'anon_device';

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .set({
      'spectators.$spectatorId': {
        'ts': DateTime.now().toIso8601String(),
      }
    }, SetOptions(merge: true));

    state = state.copyWith(
      roomId: roomId,
      isOnline: true,
      inviteLink: _buildInviteLink(roomId),
      watchLink: _buildWatchLink(roomId),
    );

    await _watchRoom(roomId);
  }
  Future<void> joinFromLink(String roomId) async {
    final targetRoomId = roomId.trim();
    if (targetRoomId.isEmpty) return;

    if (_joiningRoomId == targetRoomId) return;
    if (state.roomId == targetRoomId && _roomSub != null) return;

    _isSpectator = false;
    _roomSub?.cancel();
    _hostId = null;
    _joiningRoomId = targetRoomId;

    try {
      if (state.roomId == targetRoomId) return;

      final previousRoomId = state.roomId;

      if (previousRoomId != null && previousRoomId != targetRoomId) {
        if (_roomSub != null) {
          await _roomSub!.cancel();
          _roomSub = null;
        }

        final uid = FirebaseAuth.instance.currentUser?.uid;

        final next = state.players
            .where((p) => p.ownerUid != uid && p.id != uid)
            .toList();

        state = _initialState();
        await _autoAddAuthenticatedUser();

        if (uid != null) {
          try {
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(previousRoomId)
                .set({
              'players': _playersToMap(next),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final spectatorId = uid ?? 'anon_device';

      try {
        if (previousRoomId != null) {
          try {
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(previousRoomId)
                .update({
              'spectators.$spectatorId': FieldValue.delete(),
            });
          } catch (_) {}
        }
      } catch (_) {}

      _setLoading('join');

      if (!await _refreshBackendConnection()) {
        _setOffline();
        return;
      }

      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('rooms')
            .doc(targetRoomId)
            .get();
      } catch (_) {
        _setOffline();
        return;
      }

      if (!snap.exists) {
        state = _initialState();

        state = state.copyWith(
          loading: OverlayState.error,
        );

        Future.delayed(const Duration(seconds: 2), () {
          state = state.copyWith(clearLoading: true);
        });

        return;
      }
      final data = snap.data() ?? const <String, dynamic>{};

      final players = _mapPlayers(data['players'] as Map<String, dynamic>?);
      _hostId = data['hostId'] as String?;

      state = state.copyWith(
        roomId: targetRoomId,
        isOnline: true,
        inviteLink: _buildInviteLink(targetRoomId),
        watchLink: _buildWatchLink(targetRoomId),
        players: players,
      );

      await _watchRoom(targetRoomId);

    } finally {
      _joiningRoomId = null;

      // FIX loader sempre chiuso
      state = state.copyWith(clearLoading: true);
    }
  }

  Future<void> _watchRoom(String roomId) async {
    if (!await _refreshBackendConnection()) return;

    if (_roomSub != null) {
      await _roomSub!.cancel();
      _roomSub = null;
    }

    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen((doc) async {


      if (!doc.exists) {
        _roomSub?.cancel();
        _roomSub = null;

        final uid = FirebaseAuth.instance.currentUser?.uid;

        if (uid != null) {
          try {
            await FirebaseFirestore.instance
                .collection('user_rooms')
                .doc(uid)
                .delete();
          } catch (_) {}
        }

        _isSpectator = false;
        _hostId = null;

        state = _initialState();

        state = state.copyWith(
          loading: OverlayState.error,
        );

        Future.delayed(const Duration(seconds: 2), () {
          state = state.copyWith(clearLoading: true);
        });

        return;
      }

      final data = doc.data();
      if (data == null) return;
      final status = data['status'];
      final mappedStatus = _mapRoomState(status);

      final players = _mapPlayers(
        data['players'] as Map<String, dynamic>?,
      );

      _hostId = data['hostId'] as String?;

// 👇 CONFIG DA DB (se esiste)
      LobbyConfigVm config = state.config;
      final rawConfig = data['config'];

      if (rawConfig is Map<String, dynamic>) {
        config = LobbyConfigVm(
          variant: X01Variant.values.firstWhere(
                (e) => e.name == rawConfig['variant'],
            orElse: () => X01Variant.x501,
          ),
          inMode: InMode.values.firstWhere(
                (e) => e.name == rawConfig['inMode'],
            orElse: () => InMode.straightIn,
          ),
          outMode: OutMode.values.firstWhere(
                (e) => e.name == rawConfig['outMode'],
            orElse: () => OutMode.doubleOut,
          ),
          legs: rawConfig['legs'] ?? 1,
          sets: rawConfig['sets'] ?? 1,
          gameType: rawConfig['gameType'] ?? 'X01',
        );
      }

      state = state.copyWith(
        players: players,
        config: config, // 👈 AGGIUNTO
        roomState: mappedStatus,
        connection: ConnectionState.connected,
        isOnline: true,
      );
    }, onError: (_) {
      _setOffline();
    });
  }

  RoomState _mapRoomState(dynamic rawStatus) {
    switch (rawStatus) {
      case 'inGame':
        return RoomState.inMatch;
      case 'terminato':
        return RoomState.finished;
      case 'chiuso':
        return RoomState.closed;
      case 'inRoom':
      default:
        return RoomState.waiting;
    }
  }


  List<LobbyPlayerVm> _mapPlayers(Map<String, dynamic>? rawPlayers) {
    if (rawPlayers == null) return [];

    return rawPlayers.entries.map((entry) {
      final p = Map<String, dynamic>.from(entry.value);

      return LobbyPlayerVm(
        id: entry.key,
        name: p['name'] ?? 'Guest',
        isGuest: p['isGuest'] ?? true,
        connection: (p['connected'] ?? true)
            ? ConnectionState.connected
            : ConnectionState.disconnected,
        ownerUid: p['ownerUid'],
      );
    }).toList();
  }


  Future<void> removePlayer(String playerId) async {
    if (_isSpectator) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final targetIndex = state.players.indexWhere((p) => p.id == playerId);
    if (targetIndex == -1) return;

    final target = state.players[targetIndex];

    final isHost = currentUid == _hostId;
    final isOwner = target.ownerUid == currentUid;

    if (!isHost && !isOwner) return;
    if (playerId == _hostId) return;

    _debugDump('player_removed');

    final next = state.players.where((p) => p.id != playerId).toList();
    state = state.copyWith(players: next);

    final roomId = state.roomId;
    if (roomId == null) return;

    if (!await _refreshBackendConnection()) {
      _setOffline();
      return;
    }

    final authUid = playerId.startsWith('guest_ext_')
        ? playerId.replaceFirst('guest_ext_', '')
        : (!target.isGuest ? playerId : null);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final roomRef = db.collection('rooms').doc(roomId);
      batch.update(roomRef, {
        'players.$playerId': FieldValue.delete(),
      });

      if (authUid != null && authUid.isNotEmpty) {
        batch.delete(db.collection('user_rooms').doc(authUid));
      }

      await batch.commit();
    } catch (_) {
      _setOffline();
    }
  }

  Future<void> addLocalGuest(String name) async {
    if (_isSpectator) return;
    _debugDump('player_added_local');
    await createGuestPlayer(name);
  }
  Future<void> participateInRoom() async {
    if (_isSpectator) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (state.roomId == null) return;

    final id = 'guest_ext_${user.uid}';

    final exists = state.players.any((p) => p.id == id);
    if (exists) {
      state = state.copyWith(loading: OverlayState.error);

      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(clearLoading: true);
      });

      return;
    }
    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: user.displayName ?? user.email ?? 'Player',
          isGuest: true, // 👈 è guest esterno
          connection: ConnectionState.connected,
          ownerUid: user.uid,
        ),
      ],
    );

    await _syncPlayers();

    // salva per resume
    try {
      await FirebaseFirestore.instance
          .collection('user_rooms')
          .doc(user.uid)
          .set({
        'roomId': state.roomId,
        'joinedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
  Future<void> addAuthenticatedUser() async {
// SOLO per host iniziale. Non usare per aggiungere altri player.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = user.uid;

    final exists = state.players.any((p) => p.id == id);
    if (exists) return;

    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: user.displayName ?? user.email ?? 'Player',
          isGuest: false,
          connection: ConnectionState.connected,
          ownerUid: id,
        ),
      ],
    );

    await _syncPlayers();
  }


  Future<void> createGuestPlayer(String name) async {
    final guestName = name.trim();
    if (guestName.isEmpty) return;

    final id = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;

    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: guestName,
          isGuest: true,
          connection: ConnectionState.connected,
          ownerUid: ownerUid,
        ),
      ],
    );

    await _syncPlayers();
  }

  void updateConfig({
    X01Variant? variant,
    InMode? inMode,
    OutMode? outMode,
    int? legs,
    int? sets,
    String? gameType,
  }) {
    if (_isSpectator) return;
    _debugDump('config_changed');

    // 👇 BLOCCO HOST
    if (!isCurrentUserHost) return;

    final next = state.config.copyWith(
      variant: variant,
      inMode: inMode,
      outMode: outMode,
      legs: legs,
      sets: sets,
      gameType: gameType,
    );

    state = state.copyWith(config: next);

    _syncConfig(); // 👈 AGGIUNGI
  }


  Future<void> closeRoom() async {
    _debugDump('room_closed');

    final roomId = state.roomId; // ✅ salva subito
    final canCallBackend =
        roomId != null && await _refreshBackendConnection();

    _roomSub?.cancel();
    _isSpectator = false;
    state = _initialState();
    await _autoAddAuthenticatedUser();

    if (!canCallBackend || roomId == null) return;

    try {
      final db = FirebaseFirestore.instance;

      // 1. snapshot prima del delete
      final snap = await db.collection('rooms').doc(roomId).get();
      final data = snap.data();

      final playersMap = Map<String, dynamic>.from(
        data?['players'] ?? {},
      );

      // 2. batch (meglio)
      final batch = db.batch();

      batch.delete(db.collection('rooms').doc(roomId));

      for (final entry in playersMap.entries) {
        final p = entry.value as Map<String, dynamic>;
        final uid = p['authUid'];

        if (uid != null) {
          batch.delete(db.collection('user_rooms').doc(uid));
        }
      }

      await batch.commit();

    } catch (_) {
      _setOffline();
    }

    state = state.copyWith(clearLoading: true);
  }

  Future<Match?> loadCurrentMatch() async {
    final roomId = state.roomId;
    if (roomId == null) return null;
    try {
      final roomSnap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();
      final data = roomSnap.data();
      if (data == null) return null;
      final rawMatchId = data['currentMatchId'] as String?;
      if (rawMatchId == null || rawMatchId.isEmpty) return null;
      return _ref
          .read(matchRepositoryProvider)
          .getMatch(RoomId(roomId), MatchId(rawMatchId));
    } catch (_) {
      return null;
    }
  }

  Future<void> reopenRoomFromResult() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    if (!await _refreshBackendConnection()) return;
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        'status': 'inRoom',
        'currentMatchId': FieldValue.delete(),
        'startedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      state = state.copyWith(roomState: RoomState.waiting);
    } catch (_) {
      _setOffline();
    }
  }

  Future<void> markRoomTerminated() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    if (!await _refreshBackendConnection()) return;
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        'status': 'terminato',
      }, SetOptions(merge: true));
      state = state.copyWith(roomState: RoomState.finished);
    } catch (_) {
      _setOffline();
    }
  }

  Future<void> invite() async {
    if (_isSpectator) return;
    final online = await _refreshBackendConnection();
    if (!online) {
      // modalità locale → niente DB
      final roomId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      state = state.copyWith(
        roomId: roomId,
        inviteLink: null,
        isOnline: false,
        clearLoading: true,
      );

      return;
    }
    // se già online → solo refresh link
    if (state.roomId != null && !_isSpectator) {
      state = state.copyWith(
        isOnline: true,
        inviteLink: _buildInviteLink(state.roomId!),
      );
      return;
    }

    _setLoading('create-room');

    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';

    // 👇 NON toccare players
    final players = state.players;

    // 👇 host già definito prima
    final hostId = _hostId;

    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
        'id': roomId,
        'createdAt': DateTime.now().toIso8601String(),
        'hostId': hostId,
        'players': _playersToMap(players),
        'status': 'inRoom',
      });
    } catch (_) {
      _setOffline();
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('user_rooms')
          .doc(uid)
          .set({'roomId': roomId});
    }
    state = state.copyWith(
      roomId: roomId,
      isOnline: true,
      inviteLink: _buildInviteLink(roomId),
      watchLink: _buildWatchLink(roomId),
      clearLoading: true,
    );

    await _watchRoom(roomId);
  }
  Future<void> _syncPlayers() async {
    if (state.roomId == null) return;
    if (!await _refreshBackendConnection()) return;
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(state.roomId!).set({
        'players': _playersToMap(state.players),
      }, SetOptions(merge: true));
    } catch (_) {
      _setOffline();
    }
  }
  Future<void> _syncConfig() async {
    if (state.roomId == null) return;
    if (!await _refreshBackendConnection()) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(state.roomId!)
          .set({
        'config': {
          'variant': state.config.variant.name,
          'inMode': state.config.inMode.name,
          'outMode': state.config.outMode.name,
          'legs': state.config.legs,
          'sets': state.config.sets,
          'gameType': state.config.gameType,
        }
      }, SetOptions(merge: true));
    } catch (_) {
      _setOffline();
    }
  }


  Map<String, dynamic> _playersToMap(List<LobbyPlayerVm> players) {
    return {
      for (final p in players)
        p.id: {
          'name': p.name,
          'isGuest': p.isGuest,
          'connected': p.connection == ConnectionState.connected,
          'ownerUid': p.ownerUid,
          'authUid': p.id.startsWith('guest_ext_')
              ? p.id.replaceFirst('guest_ext_', '')
              : (p.isGuest ? null : p.id),
        }
    };
  }

/*
  String _buildInviteLink(String roomId) {
    final uri = Uri(
      scheme: 'https',
      host: 'dartsroses.netlify.app',
      path: '/room',
      queryParameters: {
        'roomId': roomId,
      },
    );
    return uri.toString();
  }*/
  String _buildInviteLink(String roomId) {
    final uri = Uri(
      scheme: 'https',
      host: 'dartsroses.netlify.app',
      queryParameters: {
        'roomId': roomId,
      },
    );
    return uri.toString();
  }
  String _buildWatchLink(String roomId) {
    final uri = Uri(
      scheme: 'https',
      host: 'dartsroses.netlify.app',
      queryParameters: {
        'watchRoomId': roomId,
      },
    );
    return uri.toString();
  }
  Future<Match?> startMatch() async {
    if (_isSpectator) return null;
    _debugDump('match_started');
    if (!state.canStart) return null;
    _setLoading('start');
    final roomId = RoomId(state.roomId ?? 'local_room');
    final matchId = MatchId('match_${DateTime.now().millisecondsSinceEpoch}');
    final slots = <PlayerSlot>[];
    final scores = <PlayerId, int>{};
    for (var i = 0; i < state.players.length; i++) {
      final playerId = PlayerId(state.players[i].id);
      slots.add(PlayerSlot(playerId: playerId, order: i));
      scores[playerId] = state.config.variant == X01Variant.x301
          ? 301
          : state.config.variant == X01Variant.x101
              ? 101
              : 501;
    }
    final inputSnapshot = <PlayerId, InputModeSnapshot>{};
    for (final p in state.players) {
      final playerId = PlayerId(p.id);
      inputSnapshot[playerId] = InputModeSnapshot(
        mode: InputMode.totalTurnInput,
      );
    }
    final match = Match(
      id: matchId,
      roomId: roomId,
      config: MatchConfig(
        gameType: GameType.x01,
        variant: state.config.variant,
        inMode: state.config.inMode,
        outMode: state.config.outMode,
        matchMode: state.config.sets > 1 ? MatchMode.setsAndLegs : MatchMode.legsOnly,
        legsTargetType: MatchTargetType.firstTo,
        legsTargetValue: state.config.legs,
        setsTargetType: state.config.sets > 1 ? MatchTargetType.firstTo : null,
        setsTargetValue: state.config.sets > 1 ? state.config.sets : null,
        teamMode: TeamMode.solo,
        teamSharedScore: false,
        finishConstraintEnabled: false,
        undoRequiresHost: false,
        inputSnapshot: inputSnapshot,
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
          currentTurnPlayerId: PlayerId(state.players.first.id),
        ),
        lastTurns: const [],
      ),
      legs: const [],
      sets: const [],
      result: null,
      createdAt: DateTime.now(),
    );

    final useCase = StartMatchUseCase(_ref.read(matchRepositoryProvider));
    await useCase.call(match);
    // segna la room come iniziata
    if (state.roomId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(state.roomId!)
        .set({
          'status': 'inGame',
          'currentMatchId': matchId.value,
          'startedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    _ref.read(matchControllerProvider.notifier).bindMatch(match: match, isOnline: state.isOnline);
    state = state.copyWith(clearLoading: true);
    return match;
  }

  @override
  void dispose() {
    _connectionTimer?.cancel(); // 👈 AGGIUNGI
    _roomSub?.cancel();
    super.dispose();
  }

}

final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController(ref));
