import 'room_data.dart';

class RoomMatchEngineLogic {
  static RoomData applyScore(
      RoomData state,
      String playerId,
      int points,
      ) {
    final players = List<Map<String, dynamic>>.from(state.players);

    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    final currentScore = player['score'] ?? 0;
    final newScore = currentScore - points;

    // 🔥 HISTORY (sempre prima)
    final newHistory = List<Map<String, dynamic>>.from(state.history)
      ..add({
        'playerId': playerId,
        'points': points,
      });

    // =========================
    // BUST
    // =========================
    if (newScore < 0) {
      final newState = _nextTurn(state, players, index);
      return newState.copyWith(history: newHistory);
    }

    // =========================
    // APPLY SCORE
    // =========================
    player['score'] = newScore;
    player['throws'] = [];

    players[index] = player;

    // =========================
    // WIN LEG
    // =========================
    if (newScore == 0) {
      final newState = _winLeg(state, players, index);
      return newState.copyWith(history: newHistory);
    }

    // =========================
    // NEXT TURN
    // =========================
    final newState = _nextTurn(state, players, index);
    return newState.copyWith(history: newHistory);
  }
  static RoomData applyThrow(
      RoomData state,
      String playerId,
      int value,
      ) {
    final players = List<Map<String, dynamic>>.from(state.players);

    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    final throws = List<int>.from(player['throws'] ?? []);
    final score = player['score'] ?? 0;

    // HISTORY (1 freccetta)
    final newHistory = List<Map<String, dynamic>>.from(state.history)
      ..add({
        'playerId': playerId,
        'value': value,
      });

    // aggiorna throws
    throws.add(value);
    player['throws'] = throws;

    final newScore = score - value;

    // BUST
    if (newScore < 0) {
      player['throws'] = [];
      players[index] = player;

      final next = _nextTurn(state, players, index);
      return next.copyWith(history: newHistory);
    }

    player['score'] = newScore;
    players[index] = player;

    // WIN
    if (newScore == 0) {
      final win = _winLeg(state, players, index);
      return win.copyWith(history: newHistory);
    }

    // 3 freccette → cambio turno
    if (throws.length == 3) {
      player['throws'] = [];
      players[index] = player;

      final next = _nextTurn(state, players, index);
      return next.copyWith(history: newHistory);
    }

    return state.copyWith(
      players: players,
      history: newHistory,
    );
  }

  static RoomData undo(RoomData state) {
    final history = List<Map<String, dynamic>>.from(state.history);
    if (history.isEmpty) return state;

    history.removeLast();

    var rebuilt = state.copyWith(
      history: [],
      players: state.initMatch().players,
    );

    for (final h in history) {
      if (h['type'] == 'dart') {
        rebuilt = applyThrow(
          rebuilt,
          h['playerId'],
          h['value'],
        );
      } else {
        rebuilt = applyTurn(
          rebuilt,
          h['playerId'],
          h['total'],
        );
      }
    }

    return rebuilt.copyWith(history: history);
  }

  static RoomData applyTurn(
      RoomData state,
      String playerId,
      int total,
      ) {
    final players = List<Map<String, dynamic>>.from(state.players);

    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    final score = player['score'] ?? 0;
    final newScore = score - total;

    final newHistory = List<Map<String, dynamic>>.from(state.history)
      ..add({
        'playerId': playerId,
        'type': 'turn',
        'total': total,
      });

    // BUST
    if (newScore < 0) {
      player['throws'] = [];
      players[index] = player;

      final next = _nextTurn(state, players, index);
      return next.copyWith(history: newHistory);
    }

    player['score'] = newScore;
    player['throws'] = [];

    players[index] = player;

    // WIN
    if (newScore == 0) {
      final win = _winLeg(state, players, index);
      return win.copyWith(history: newHistory);
    }

    final next = _nextTurn(state, players, index);
    return next.copyWith(history: newHistory);
  }


  static RoomData _winLeg(
      RoomData state,
      List<Map<String, dynamic>> players,
      int winnerIndex,
      ) {
    final updated = <Map<String, dynamic>>[];

    for (int i = 0; i < players.length; i++) {
      final p = Map<String, dynamic>.from(players[i]);

      if (i == winnerIndex) {
        p['legs'] = (p['legs'] ?? 0) + 1;
      }

      // reset score
      p['score'] = state.game.startingScore ?? 501;
      p['turn'] = i == winnerIndex;

      p['throws'] = [];

      updated.add(p);
    }

    return state.copyWith(players: updated);
  }

  static RoomData _nextTurn(
      RoomData state,
      List<Map<String, dynamic>> players,
      int currentIndex,
      ) {
    // =========================
    // BUILD TURN ORDER
    // =========================

    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final List<Map<String, dynamic>> turnOrder = [];

    if (state.teamSize > 1) {
      // build teams
      final teams = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < sorted.length; i += state.teamSize) {
        if (i + state.teamSize <= sorted.length) {
          teams.add(sorted.sublist(i, i + state.teamSize));
        }
      }

      // interleave players: team1 p1, team2 p1, team1 p2, team2 p2...
      final maxPlayersPerTeam = state.teamSize;

      for (int i = 0; i < maxPlayersPerTeam; i++) {
        for (final team in teams) {
          if (i < team.length) {
            turnOrder.add(team[i]);
          }
        }
      }
    } else {
      // FFA normale
      turnOrder.addAll(sorted);
    }

    // =========================
    // FIND CURRENT IN ORDER
    // =========================

    final currentPlayer = players[currentIndex];

    final orderIndex = turnOrder.indexWhere(
          (p) => p['id'] == currentPlayer['id'],
    );

    final nextOrderIndex = (orderIndex + 1) % turnOrder.length;

    final nextPlayerId = turnOrder[nextOrderIndex]['id'];

    // =========================
    // APPLY TURN
    // =========================

    final updated = <Map<String, dynamic>>[];

    for (final p in players) {
      final copy = Map<String, dynamic>.from(p);
      copy['turn'] = p['id'] == nextPlayerId;
      updated.add(copy);
    }

    return state.copyWith(players: updated);
  }
}