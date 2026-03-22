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
import '../../match/controllers/match_controller.dart';
import '../../../domain/policies/input_fidelity_policy.dart';
class LobbyPlayerVm {
  const LobbyPlayerVm({
    required this.id,
    required this.name,
    required this.isGuest,
    required this.connection,
  });

  final String id;
  final String name;
  final bool isGuest;
  final ConnectionState connection;
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
  bool _isSpectator = false;
  bool get isSpectator => _isSpectator;
  Timer? _connectionTimer;
  // 👇 NUOVO: guest "autenticato proxy" (NON usa FirebaseAuth app)
  Future<void> addGuestFromExternalAuth({
    required String externalId,
    required String name,
    String? email,
  }) async {
    final id = 'guest_ext_$externalId';

    final exists = state.players.any((p) => p.id == id);
    if (exists) return;

    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: name.isNotEmpty ? name : (email ?? 'Guest'),
          isGuest: true, // 👈 sempre guest nella room
          connection: ConnectionState.connected,
        ),
      ],
    );

    await _syncPlayers();
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


  Future<void> leaveRoom() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currentRoomId = state.roomId;
    final guestExternalId = 'guest_ext_$uid';

    final next = state.players
        .where((p) => p.id != uid && p.id != guestExternalId)
        .toList();

    if (currentRoomId != null && await _refreshBackendConnection()) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(currentRoomId)
            .set({
          'players': _playersToMap(next),
        }, SetOptions(merge: true));
      } catch (_) {
        _setOffline();
      }
    }

    _roomSub?.cancel();
    _hostId = null;
    state = _initialState();
    await _autoAddAuthenticatedUser();
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
      ),
    ];

    state = state.copyWith(players: updatedPlayers);

    // 👇 QUI diventi host subito
    if (_hostId == null) {
      _hostId = id;
    }
  }
  Future<void> joinAsSpectator(String roomId) async {
    _isSpectator = true;

    final snap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .get();

    if (!snap.exists) return;

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .set({
      'spectators': FieldValue.arrayUnion([
        {
          'id': FirebaseAuth.instance.currentUser?.uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}',
          'ts': DateTime.now().toIso8601String(),
        }
      ])
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
        final guestExternalId = uid != null ? 'guest_ext_$uid' : null;

        final next = state.players
            .where((p) => p.id != uid && p.id != guestExternalId)
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
        state = state.copyWith(clearLoading: true);
        return;
      }

      final data = snap.data() ?? const <String, dynamic>{};

      if (data['closed'] == true) {
        state = state.copyWith(clearLoading: true);
        return;
      }

      final players = _mapPlayers(data['players'] as List?);
      _hostId = data['hostId'] as String?;

      state = state.copyWith(
        roomId: targetRoomId,
        isOnline: true,
        inviteLink: _buildInviteLink(targetRoomId),
        watchLink: _buildWatchLink(targetRoomId),
        players: players,
        clearLoading: true,
      );

      await _watchRoom(targetRoomId);

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await addGuestFromExternalAuth(
          externalId: user.uid,
          name: user.displayName ?? '',
          email: user.email,
        );
      }
    } finally {
      _joiningRoomId = null;
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
        .listen((doc) {
      final data = doc.data();
      if (data == null) return;

      if (data['closed'] == true) {
        _roomSub?.cancel();
        _roomSub = null;
        state = _initialState();
        return;
      }

      final players = _mapPlayers(data['players'] as List?);
      _hostId = data['hostId'] as String?;

      state = state.copyWith(
        players: players,
        connection: ConnectionState.connected,
        isOnline: true,
      );
    }, onError: (_) {
      _setOffline();
    });
  }


  List<LobbyPlayerVm> _mapPlayers(List? rawPlayers) {
    return List<Map<String, dynamic>>.from(rawPlayers ?? const [])
        .map(
          (p) => LobbyPlayerVm(
            id: (p['id'] ?? '') as String,
            name: (p['name'] ?? 'Guest') as String,
            isGuest: (p['isGuest'] ?? true) as bool,
            connection: (p['connected'] ?? true) ? ConnectionState.connected : ConnectionState.disconnected,
          ),
        )
        .toList();
  }
  Future<void> removePlayer(String playerId) async {
    if (playerId == _hostId) return;

    final next = state.players.where((p) => p.id != playerId).toList();
    state = state.copyWith(players: next);
    await _syncPlayers();
  }
  Future<void> addLocalGuest(String name) async {
    await createGuestPlayer(name);
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
        ),
      ],
    );

    await _syncPlayers();
  }

  Future<void> createGuestPlayer(String name) async {
    final guestName = name.trim();
    if (guestName.isEmpty) return;

    final id = 'guest_${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: guestName,
          isGuest: true,
          connection: ConnectionState.connected,
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
    state = state.copyWith(
      config: state.config.copyWith(
        variant: variant,
        inMode: inMode,
        outMode: outMode,
        legs: legs,
        sets: sets,
        gameType: gameType,
      ),
    );
  }
  Future<void> closeRoom() async {
    final roomId = state.roomId;
    final canCallBackend = roomId != null && await _refreshBackendConnection();

    _roomSub?.cancel();

    // reset locale immediato
    state = _initialState();
    await _autoAddAuthenticatedUser();

    // se online → segna chiusa, STOP
    if (canCallBackend) {
      try {
        await FirebaseFirestore.instance.collection('rooms').doc(roomId!).set({
          'closed': true,
          'closedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));

        // cleanup silenzioso
        Future.delayed(const Duration(seconds: 20), () async {
          try {
            await FirebaseFirestore.instance.collection('rooms').doc(roomId!).delete();
          } catch (_) {}
        });
      } catch (_) {
        _setOffline();
      }
    }
  }
  Future<void> invite() async {
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
    if (state.roomId != null) {
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
        'isStarted': false,
      });
    } catch (_) {
      _setOffline();
      return;
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

  List<Map<String, dynamic>> _playersToMap(List<LobbyPlayerVm> players) {
    return players
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'isGuest': p.isGuest,
              'connected': p.connection == ConnectionState.connected,
            })
        .toList();
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
          'isStarted': true,
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
