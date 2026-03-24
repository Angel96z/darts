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
  Future<void> addPlayer(LobbyPlayerVm player) async {
    final list = [...state.ordered, player];

    await _applyLayoutChange(
      teamSize: state.teamSize,
      reorderList: list,
    );
  }

  Future<void> removePlayerById(String playerId) async {
    final list = state.ordered.where((p) => p.id != playerId).toList();

    await _applyLayoutChange(
      teamSize: state.teamSize,
      reorderList: list,
    );
  }
  Future<void> _applyLayoutChange({
    required int teamSize,
    required List<LobbyPlayerVm> reorderList,
  }) async {
    final currentIds = state.ordered.map((e) => e.id).toList();
    final newIds = reorderList.map((e) => e.id).toList();

    if (currentIds.length == newIds.length) {
      bool same = true;
      for (int i = 0; i < currentIds.length; i++) {
        if (currentIds[i] != newIds[i]) {
          same = false;
          break;
        }
      }
      if (same && teamSize == state.teamSize) return;
    }
    final lobbyCtrl =
    _ref.read(lobbyControllerProvider.notifier);

    final roomId = _ref.read(lobbyControllerProvider).roomId;

    if (roomId != null && !lobbyCtrl.isCurrentUserHost) {
      _isReordering = false;
      return;
    }
    _isReordering = true;

    final updated = [
      for (int i = 0; i < reorderList.length; i++)
        LobbyPlayerVm(
          id: reorderList[i].id,
          name: reorderList[i].name,
          isGuest: reorderList[i].isGuest,
          connection: reorderList[i].connection,
          ownerUid: reorderList[i].ownerUid,
          order: i,
          teamId: teamSize == 1 ? null : 'team_${i ~/ teamSize}',
        )
    ];

    state = state.copyWith(
      ordered: updated,
      teamSize: teamSize,
      teamsEnabled: teamSize > 1,
    );

    if (roomId != null) {
      await _ref
          .read(lobbyControllerProvider.notifier)
          .updatePlayersFromOrder(updated);
    }

    _isReordering = false;
  }


  List<int> computeValidTeamSizes(int playerCount) {
    if (playerCount <= 1) return const [1];

    final result = <int>[1];

    for (int size = 2; size < playerCount; size++) {
      final teamsCount = playerCount ~/ size;

      final dividesExactly = playerCount % size == 0;
      final hasAtLeastTwoTeams = teamsCount >= 2;

      if (dividesExactly && hasAtLeastTwoTeams) {
        result.add(size);
      }
    }

    return result;
  }

  Future<void> setTeamMode(int teamSize) async {
    await _applyLayoutChange(
      teamSize: teamSize,
      reorderList: state.ordered,
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

    final allHaveTeam = sorted.every((p) => p.teamId != null);

    if (!allHaveTeam && state.teamsEnabled && state.teamSize > 1) {
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

  Future<void> reorderLocal(int oldIndex, int newIndex) async {
    final list = [...state.ordered];

    if (newIndex > oldIndex) newIndex--;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    await _applyLayoutChange(
      teamSize: state.teamSize,
      reorderList: list,
    );
  }


}

// -----------------------
// PROVIDER
// -----------------------

final playerOrderControllerProvider =
StateNotifierProvider<PlayerOrderController, PlayerOrderState>(
      (ref) => PlayerOrderController(ref),
);