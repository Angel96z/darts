import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'lobby_controller.dart';

// -----------------------
// STATE
// -----------------------

class PlayerOrderState {
  const PlayerOrderState({
    required this.ordered,
    this.teamsEnabled = false,
    this.teamSize = 1,
  });

  final List<LobbyPlayerVm> ordered;
  final bool teamsEnabled;
  final int teamSize;


  PlayerOrderState copyWith({
    List<LobbyPlayerVm>? ordered,
    bool? teamsEnabled,
    int? teamSize,
  }) {
    return PlayerOrderState(
      ordered: ordered ?? this.ordered,
      teamsEnabled: teamsEnabled ?? this.teamsEnabled,
      teamSize: teamSize ?? this.teamSize,
    );
  }
}

// -----------------------
// CONTROLLER
// -----------------------

class PlayerOrderController extends StateNotifier<PlayerOrderState> {
  List<int> computeValidTeamSizes(int playerCount) {
    final result = <int>[];

    for (int size = 1; size <= playerCount; size++) {
      if (playerCount % size == 0) {
        result.add(size);
      }
    }

    return result;
  }

  void setTeamMode(int teamSize) {
    final players = [...state.ordered];

    for (int i = 0; i < players.length; i++) {
      final teamIndex = i ~/ teamSize;
      final teamId = teamSize == 1 ? null : 'team_$teamIndex';

      final p = players[i];

      players[i] = LobbyPlayerVm(
        id: p.id,
        name: p.name,
        isGuest: p.isGuest,
        connection: p.connection,
        ownerUid: p.ownerUid,
        order: i,
        teamId: teamId,
      );
    }

    state = state.copyWith(
      ordered: players,
      teamsEnabled: teamSize > 1,
      teamSize: teamSize,
    );
  }
  PlayerOrderController(this._ref)
      : super(const PlayerOrderState(ordered: []));

  final Ref _ref;

  // 🔴 FLAG BLOCCO SNAPSHOT
  bool _isReordering = false;

  // -----------------------
  // INIT FROM LOBBY
  // -----------------------

  void syncFromLobby(List<LobbyPlayerVm> players) {
    if (_isReordering) return;

    final sorted = [...players]
      ..sort((a, b) => a.order.compareTo(b.order));

    // 🔥 se team attivi → ricalcola SEMPRE
    if (state.teamsEnabled && state.teamSize > 1) {
      final size = state.teamSize;

      final rebuilt = [
        for (int i = 0; i < sorted.length; i++)
          LobbyPlayerVm(
            id: sorted[i].id,
            name: sorted[i].name,
            isGuest: sorted[i].isGuest,
            connection: sorted[i].connection,
            ownerUid: sorted[i].ownerUid,
            order: i,
            teamId: 'team_${i ~/ size}',
          )
      ];

      state = state.copyWith(ordered: rebuilt);
    } else {
      state = state.copyWith(ordered: sorted);
    }
  }

  // -----------------------
  // DRAG LOCAL (UI ONLY)
  // -----------------------

  void reorderLocal(int oldIndex, int newIndex) {
    _isReordering = true;

    final list = [...state.ordered];

    if (newIndex > oldIndex) newIndex--;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // 🔥 RICALCOLO TEAM
    final teamSize = state.teamSize;

    final updated = [
      for (int i = 0; i < list.length; i++)
        LobbyPlayerVm(
          id: list[i].id,
          name: list[i].name,
          isGuest: list[i].isGuest,
          connection: list[i].connection,
          ownerUid: list[i].ownerUid,
          order: i,
          teamId: teamSize == 1
              ? null
              : 'team_${i ~/ teamSize}',
        )
    ];

    state = state.copyWith(ordered: updated);
  }

  // -----------------------
  // COMMIT TO DB
  // -----------------------

  Future<void> commitOrder() async {
    final lobby = _ref.read(lobbyControllerProvider);
    final roomId = lobby.roomId;

    if (roomId == null) {
      _isReordering = false;
      return;
    }

    await _ref.read(lobbyControllerProvider.notifier)
        .updatePlayersFromOrder(state.ordered);

    // 🔑 sblocca dopo commit
    _isReordering = false;
  }

  // -----------------------
  // ASSIGN TEAM
  // -----------------------

  Future<void> assignTeam(String playerId, String? teamId) async {
    final lobby = _ref.read(lobbyControllerProvider);
    final roomId = lobby.roomId;

    if (roomId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .update({
        'players.$playerId.teamId': teamId,
      });
    } catch (_) {}
  }
}

// -----------------------
// PROVIDER
// -----------------------

final playerOrderControllerProvider =
StateNotifierProvider<PlayerOrderController, PlayerOrderState>(
      (ref) => PlayerOrderController(ref),
);