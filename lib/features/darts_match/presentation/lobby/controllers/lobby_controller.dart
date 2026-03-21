import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/blocking_overlay.dart';
import '../../../application/usecases/providers.dart';
import '../../../application/usecases/start_match_usecase.dart';
import '../../../domain/entities/identity.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/room.dart';
import '../../../domain/value_objects/identifiers.dart';
import '../../match/controllers/match_controller.dart';

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
    required this.loading,
  });

  final RoomState roomState;
  final ConnectionState connection;
  final List<LobbyPlayerVm> players;
  final LobbyConfigVm config;
  final bool isOnline;
  final String? roomId;
  final String? inviteLink;
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
      loading: clearLoading ? null : (loading ?? this.loading),
    );
  }
}

class LobbyController extends StateNotifier<LobbyViewModel> {
  LobbyController(this._ref)
      : super(
          const LobbyViewModel(
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
            loading: null,
          ),
        ) {
    _checkLinkJoin();
    _autoAddAuthenticatedUser();
  }

  final Ref _ref;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  void _setLoading(String step) {
    state = state.copyWith(loading: OverlayState.loading, roomState: RoomState.waiting);
  }

  Future<void> _checkLinkJoin() async {
    final roomId = Uri.base.queryParameters['roomId'];
    if (roomId == null || roomId.isEmpty) return;
    await joinFromLink(roomId);
  }

  Future<void> _autoAddAuthenticatedUser() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    await addCurrentUser();
  }

  Future<void> joinFromLink(String roomId) async {
    _setLoading('join');
    final snap = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
    if (!snap.exists) {
      state = state.copyWith(clearLoading: true);
      return;
    }
    state = state.copyWith(
      roomId: roomId,
      isOnline: true,
      inviteLink: _buildInviteLink(roomId),
      clearLoading: true,
    );
    _watchRoom(roomId);
  }

  void _watchRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = FirebaseFirestore.instance.collection('rooms').doc(roomId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final rawPlayers = List<Map<String, dynamic>>.from(data['players'] as List? ?? const []);
      final players = rawPlayers
          .map(
            (p) => LobbyPlayerVm(
              id: (p['id'] ?? '') as String,
              name: (p['name'] ?? 'Guest') as String,
              isGuest: (p['isGuest'] ?? true) as bool,
              connection: (p['connected'] ?? true) ? ConnectionState.connected : ConnectionState.disconnected,
            ),
          )
          .toList();
      state = state.copyWith(players: players, connection: ConnectionState.connected);
    });
  }

  Future<void> addLocalGuest(String name) async {
    if (name.trim().isEmpty) return;
    final id = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final next = [
      ...state.players,
      LobbyPlayerVm(id: id, name: name.trim(), isGuest: true, connection: ConnectionState.connected),
    ];
    state = state.copyWith(players: next);
    await _syncPlayers();
  }

  Future<void> addCurrentUser({String? guestName}) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email ?? guestName ?? 'Guest';
    final id = user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final exists = state.players.any((p) => p.id == id);
    if (exists) return;
    state = state.copyWith(
      players: [
        ...state.players,
        LobbyPlayerVm(
          id: id,
          name: name,
          isGuest: user == null,
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

  Future<void> invite() async {
    if (state.roomId != null) {
      state = state.copyWith(isOnline: true, inviteLink: _buildInviteLink(state.roomId!));
      return;
    }
    _setLoading('create-room');
    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
    await FirebaseFirestore.instance.collection('rooms').doc(roomId).set({
      'id': roomId,
      'createdAt': DateTime.now().toIso8601String(),
      'players': _playersToMap(state.players),
    });
    state = state.copyWith(
      roomId: roomId,
      isOnline: true,
      inviteLink: _buildInviteLink(roomId),
      clearLoading: true,
    );
    _watchRoom(roomId);
  }

  Future<void> _syncPlayers() async {
    if (!state.isOnline || state.roomId == null) return;
    await FirebaseFirestore.instance.collection('rooms').doc(state.roomId!).set({
      'players': _playersToMap(state.players),
    }, SetOptions(merge: true));
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

  String _buildInviteLink(String roomId) {
    final uri = Uri.base.replace(queryParameters: {'roomId': roomId});
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
    _ref.read(matchControllerProvider.notifier).bindMatch(match: match, isOnline: state.isOnline);
    state = state.copyWith(clearLoading: true);
    return match;
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }
}

final lobbyControllerProvider = StateNotifierProvider<LobbyController, LobbyViewModel>((ref) => LobbyController(ref));
