/// File: player_order_controller.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'lobby_controller.dart';

// -----------------------
// STATE
// -----------------------

class PlayerOrderState {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const PlayerOrderState({
    required this.ordered,
    this.teamsEnabled = false,
    this.teamSize = 1,
  });

  final List<LobbyPlayerVm> ordered;
  final bool teamsEnabled;
  final int teamSize;


  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> addPlayer(LobbyPlayerVm player) async {
    final list = [...state.ordered, player];

    await _applyLayoutChange(
      teamSize: state.teamSize,
      reorderList: list,
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> removePlayerById(String playerId) async {
    final list = state.ordered.where((p) => p.id != playerId).toList();

// SOLO aggiornamento locale, NO DB
    final updated = [
      for (int i = 0; i < list.length; i++)
        LobbyPlayerVm(
          id: list[i].id,
          name: list[i].name,
          isGuest: list[i].isGuest,
          connection: list[i].connection,
          ownerUid: list[i].ownerUid,
          order: i,
          teamId: state.teamSize == 1 ? null : 'team_${i ~/ state.teamSize}',
        )
    ];

    state = state.copyWith(ordered: updated);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

    final roomId = _ref.read(lobbyControllerProvider).roomId;

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


  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void beginRemoteMutation() {
    _isReordering = true;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void endRemoteMutation() {
    _isReordering = false;
  }
  // -----------------------
  // INIT FROM LOBBY
  // -----------------------

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void syncFromLobby(List<LobbyPlayerVm> players) {
// Se stiamo facendo un drag&drop manuale, non interrompiamo l'animazione
    if (_isReordering) return;

// Ordiniamo in base al campo 'order' del DB
    final incomingList = [...players]..sort((a, b) => a.order.compareTo(b.order));

// Controllo di Integrità: Se la lista è identica per ID e Ordine, non facciamo nulla
    if (state.ordered.length == incomingList.length) {
      bool isExactlySame = true;
      for (int i = 0; i < incomingList.length; i++) {
        if (state.ordered[i].id != incomingList[i].id ||
            state.ordered[i].teamId != incomingList[i].teamId ||
            state.ordered[i].order != incomingList[i].order) {
          isExactlySame = false;
          break;
        }
      }
      if (isExactlySame) return;
    }

// Se arriviamo qui, il DB è cambiato (es. un giocatore è stato eliminato)
// Forziamo l'aggiornamento dello stato per far sparire il giocatore rimosso
    final allHaveTeam = incomingList.every((p) => p.teamId != null);

    if (!allHaveTeam && state.teamsEnabled && state.teamSize > 1) {
      final size = state.teamSize;
      final rebuilt = [
        for (int i = 0; i < incomingList.length; i++)
          LobbyPlayerVm(
            id: incomingList[i].id,
            name: incomingList[i].name,
            isGuest: incomingList[i].isGuest,
            connection: incomingList[i].connection,
            ownerUid: incomingList[i].ownerUid,
            order: i,
            teamId: 'team_${i ~/ size}',
          )
      ];
      state = state.copyWith(ordered: rebuilt);
    } else {
      state = state.copyWith(ordered: incomingList);
    }
  }

  // -----------------------
  // DRAG LOCAL (UI ONLY)
  // -----------------------

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> reorderLocal(int oldIndex, int newIndex) async {
    if (_isReordering) return;
    _isReordering = true;

    try {
      final list = [...state.ordered];
      if (newIndex > oldIndex) newIndex--;

      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      // Ricalcoliamo gli ordini localmente per la UI immediata
      final updatedList = List<LobbyPlayerVm>.generate(list.length, (i) {
        return LobbyPlayerVm(
          id: list[i].id,
          name: list[i].name,
          isGuest: list[i].isGuest,
          connection: list[i].connection,
          ownerUid: list[i].ownerUid,
          order: i,
          teamId: state.teamsEnabled ? 'team_${i ~/ state.teamSize}' : null,
        );
      });

      state = state.copyWith(ordered: updatedList);

      // Sincronizzazione remota transazionale
      final lobbyCtrl = _ref.read(lobbyControllerProvider.notifier);
      final roomId = _ref.read(lobbyControllerProvider).roomId;

      if (roomId != null) {
        final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(roomRef);
          if (!snapshot.exists) return;

          Map<String, dynamic> remotePlayers = Map<String, dynamic>.from(snapshot.data()?['players'] ?? {});

          // Applichiamo i nuovi ordini solo ai player ancora esistenti nel DB
          for (var updatedPlayer in updatedList) {
            if (remotePlayers.containsKey(updatedPlayer.id)) {
              remotePlayers[updatedPlayer.id]['order'] = updatedPlayer.order;
              remotePlayers[updatedPlayer.id]['teamId'] = updatedPlayer.teamId;
            }
          }

          transaction.update(roomRef, {'players': remotePlayers});
        });
      }
    } finally {
      _isReordering = false;
    }
  }

}

// -----------------------
// PROVIDER
// -----------------------

final playerOrderControllerProvider =
StateNotifierProvider<PlayerOrderController, PlayerOrderState>(
      (ref) => PlayerOrderController(ref),
);
