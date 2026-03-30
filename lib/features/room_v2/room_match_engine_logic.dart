import 'games_darts.dart';
import 'room_data.dart';

class RoomMatchEngineLogic {
  static RoomData applyScore(
      RoomData state,
      String playerId,
      int points, {
        bool skipHistory = false,
      }) {
    if (skipHistory) return state;
    return applyTurn(state, playerId, points);
  }

  static RoomData applyThrow(
      RoomData data,
      String playerId,
      int value,
      ) {
    final currentPlayer = _currentTurnPlayer(data);
    if (currentPlayer == null) return data;
    if (currentPlayer['id'] != playerId) return data;

    final throws = List<int?>.from(currentPlayer['throws'] ?? []);
    if (throws.length >= 3) return data;
    final score = (currentPlayer['score'] as int?) ?? 0;

    final newThrows = List<int?>.from(throws)..add(value);
    final newScore = score - value;

    // aggiorna player live
    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final player = Map<String, dynamic>.from(players[index]);
    player['throws'] = newThrows;
    player['dart'] = newThrows.length;
    player['score'] = newScore;
    players[index] = player;

    // fine turno?
    bool isEnd = false;
    String endKind = 'normal';

    if (newScore < 0) {
      isEnd = true;
      endKind = 'bust';
    } else if (newScore == 0) {
      isEnd = true;
      endKind = 'checkout';
    } else if (newThrows.length == 3) {
      isEnd = true;
      endKind = 'normal';
    }

    if (!isEnd) {
      return data.copyWith(players: players);
    }

    final turn = {
      'playerId': playerId,
      'startScore': (player['turnStartScore'] as int?) ?? player['score'],
      'throws': newThrows,
      'total': newThrows.fold<int>(0, (s, e) => s + ((e as int?) ?? 0)),
      'inputMode': 'dart',
      'endKind': endKind,
    };

    final history = List<Map<String, dynamic>>.from(data.history)..add(turn);

    return _applyTurnResult(
      data.copyWith(players: players, history: history),
      index,
      endKind,
    );
  }

  static RoomData applyTurn(
      RoomData data,
      String playerId,
      int total,
      ) {
    final currentPlayer = _currentTurnPlayer(data);
    if (currentPlayer == null) return data;
    if (currentPlayer['id'] != playerId) return data;

    final score = (currentPlayer['score'] as int?) ?? 0;
    final newScore = score - total;

    String endKind = 'normal';

    if (newScore < 0) {
      endKind = 'bust';
    } else if (newScore == 0) {
      endKind = 'checkout';
    }

    final turn = {
      'playerId': playerId,
      'startScore': (currentPlayer['turnStartScore'] as int?) ?? currentPlayer['score'],
      'throws': [null, null, null],
      'total': total,
      'inputMode': 'total',
      'endKind': endKind,
    };

    final history = List<Map<String, dynamic>>.from(data.history)..add(turn);

    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final player = Map<String, dynamic>.from(players[index]);

    if (endKind == 'bust') {
      player['score'] = player['turnStartScore'];
    } else {
      player['score'] = newScore;
    }

    player['throws'] = <int?>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;

    players[index] = player;

    return _applyTurnResult(
      data.copyWith(players: players, history: history),
      index,
      endKind,
    );
  }


  static RoomData undo(RoomData state) {
    final currentPlayer = _currentTurnPlayer(state);

    // =========================
    // 1. UNDO DART LIVE
    // =========================
    if (currentPlayer != null) {
      final throws = List<int?>.from(currentPlayer['throws'] ?? const <int?>[]);

      if (throws.isNotEmpty) {
        final players = List<Map<String, dynamic>>.from(state.players);
        final index = players.indexWhere((p) => p['id'] == currentPlayer['id']);
        if (index == -1) return state;

        final player = Map<String, dynamic>.from(players[index]);
        final turnStart = (player['turnStartScore'] as int?) ?? 0;

        throws.removeLast();

        final newTotal = throws.fold<int>(0, (s, e) => s + (e ?? 0));

        player['throws'] = throws;
        player['dart'] = throws.length;
        player['score'] = turnStart - newTotal;

        players[index] = player;

        return state.copyWith(players: players);
      }
    }

    // =========================
    // 2. UNDO TURNO CHIUSO
    // =========================
    final history = List<Map<String, dynamic>>.from(state.history);
    if (history.isEmpty) return state;

    final last = Map<String, dynamic>.from(history.removeLast());

    final playerId = last['playerId'];
    final inputMode = last['inputMode'] ?? 'total';
    final endKind = last['endKind'] ?? 'normal';
    final lastThrows = List<int?>.from(last['throws'] ?? const <int?>[]);
    final startScore = (last['startScore'] as int?) ?? 0;

    // =========================
    // CHECKOUT:
    // _winLeg ha già resettato tutti i player.
    // Quindi prima si torna allo stato corretto del leg precedente
    // rigiocando la history residua, poi si ripristina il turno chiuso
    // come turno live SENZA l'ultima freccetta.
    // =========================
    if (endKind == 'checkout') {
      RoomData rebuilt = _rebuildFromTurnHistory(state, history);

      final players = List<Map<String, dynamic>>.from(rebuilt.players);
      final index = players.indexWhere((p) => p['id'] == playerId);
      if (index == -1) return rebuilt;

      final player = Map<String, dynamic>.from(players[index]);

      for (int i = 0; i < players.length; i++) {
        final copy = Map<String, dynamic>.from(players[i]);
        copy['turn'] = i == index;
        players[i] = copy;
      }

      player['inputMode'] = inputMode;
      player['turnStartScore'] = startScore;

      if (inputMode == 'dart') {
        final restored = List<int?>.from(lastThrows);
        if (restored.isNotEmpty) {
          restored.removeLast();
        }

        final partialTotal = restored.fold<int>(0, (s, e) => s + (e ?? 0));

        player['throws'] = restored;
        player['dart'] = restored.length;
        player['score'] = startScore - partialTotal;
      } else {
        player['throws'] = <int?>[];
        player['dart'] = 0;
        player['score'] = startScore;
      }

      players[index] = player;

      return rebuilt.copyWith(
        players: players,
        history: history,
      );
    }

    // =========================
    // NORMAL / BUST / TOTAL
    // mantiene la logica attuale:
    // turno chiuso dart -> ripristina il turno live senza ultima freccetta
    // turno total -> ripristina inizio turno
    // =========================
    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);
    final turnStart = (player['turnStartScore'] as int?) ?? startScore;

    if (inputMode == 'dart') {
      final restored = List<int?>.from(lastThrows);

      if (restored.isNotEmpty) {
        restored.removeLast();
      }

      final newTotal = restored.fold<int>(0, (s, e) => s + (e ?? 0));

      player['throws'] = restored;
      player['dart'] = restored.length;
      player['score'] = turnStart - newTotal;
    } else {
      player['throws'] = <int?>[];
      player['dart'] = 0;
      player['score'] = turnStart;
    }

    final round = (player['round'] as int?) ?? 1;
    player['round'] = round > 1 ? round - 1 : 1;

    players[index] = player;

    final updated = <Map<String, dynamic>>[];
    for (final p in players) {
      final copy = Map<String, dynamic>.from(p);
      copy['turn'] = p['id'] == playerId;
      updated.add(copy);
    }

    return state.copyWith(
      players: updated,
      history: history,
    );
  }

  static RoomData _rebuildFromHistory(
      RoomData base,
      List<Map<String, dynamic>> history,
      ) {
    RoomData state = base.copyWith(
      players: _resetPlayers(base),
      history: [],
      legStarterOrder: 0,
    );

    for (final rawEvent in history) {
      final event = Map<String, dynamic>.from(rawEvent);
      final type = event['type'];

      if (type == 'dart') {
        state = _applyDartEvent(state, event);
        continue;
      }

      if (type == 'turn_end') {
        state = _applyTurnEndEvent(state, event);
        continue;
      }

      if (type == 'turn_total_input') {
        state = _applyTurnTotalInputEvent(state, event);
        continue;
      }
    }

    return state.copyWith(history: history);
  }

  static RoomData _applyDartEvent(
      RoomData state,
      Map<String, dynamic> event,
      ) {
    final playerId = event['playerId'];
    final value = (event['value'] as int?) ?? 0;

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);
    final throws = List<int?>.from(player['throws'] ?? const <int?>[])..add(value);

    player['throws'] = throws;
    player['dart'] = throws.length;
    player['score'] = ((player['score'] as int?) ?? 0) - value;

    players[index] = player;

    return state.copyWith(players: players);
  }

  static RoomData _applyTurnEndEvent(
      RoomData state,
      Map<String, dynamic> event,
      ) {
    final playerId = event['playerId'];
    final endKind = event['endKind'] ?? 'normal';

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    if (endKind == 'bust') {
      player['score'] = player['turnStartScore'];
      player['throws'] = <int?>[];
      player['dart'] = 0;
      player['round'] = ((player['round'] as int?) ?? 1) + 1;

      players[index] = player;

      final moved = _nextTurn(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(moved);
    }

    if (endKind == 'checkout') {
      player['score'] = 0;
      players[index] = player;

      final won = _winLeg(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(won);
    }

    player['throws'] = <int?>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;

    players[index] = player;

    final moved = _nextTurn(state, players, index);
    return _syncTurnStartScoreFromCurrentScore(moved);
  }

  static RoomData _applyTurnTotalInputEvent(
      RoomData state,
      Map<String, dynamic> event,
      ) {
    final playerId = event['playerId'];
    final total = (event['total'] as int?) ?? 0;

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);
    final currentScore = (player['score'] as int?) ?? 0;
    final newScore = currentScore - total;

    if (newScore < 0) {
      player['score'] = player['turnStartScore'];
      player['throws'] = <int?>[];
      player['dart'] = 0;
      player['round'] = ((player['round'] as int?) ?? 1) + 1;

      players[index] = player;

      final moved = _nextTurn(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(moved);
    }

    if (newScore == 0) {
      player['score'] = 0;
      player['throws'] = <int?>[];
      player['dart'] = 0;

      players[index] = player;

      final won = _winLeg(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(won);
    }

    player['score'] = newScore;
    player['throws'] = <int?>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;

    players[index] = player;

    final moved = _nextTurn(state, players, index);
    return _syncTurnStartScoreFromCurrentScore(moved);
  }
  static RoomData _applyTurnResult(
      RoomData state,
      int playerIndex,
      String endKind,
      ) {
    final players = List<Map<String, dynamic>>.from(state.players);

    if (endKind == 'checkout') {
      final won = _winLeg(state, players, playerIndex);
      return _syncTurnStartScoreFromCurrentScore(won);
    }

    final moved = _nextTurn(state, players, playerIndex);
    return _syncTurnStartScoreFromCurrentScore(moved);
  }

  static RoomData _rebuildFromTurnHistory(
      RoomData base,
      List<Map<String, dynamic>> history,
      ) {
    RoomData state = base.copyWith(
      players: _resetPlayers(base),
      history: [],
      legStarterOrder: 0,
    );

    for (final rawTurn in history) {
      final turn = Map<String, dynamic>.from(rawTurn);

      final playerId = turn['playerId'];
      final total = (turn['total'] as int?) ?? 0;
      final startScore = (turn['startScore'] as int?) ?? 0;
      final endKind = (turn['endKind'] as String?) ?? 'normal';

      final players = List<Map<String, dynamic>>.from(state.players);
      final index = players.indexWhere((p) => p['id'] == playerId);
      if (index == -1) {
        continue;
      }

      final player = Map<String, dynamic>.from(players[index]);

      if (endKind == 'bust') {
        player['score'] = player['turnStartScore'];
        player['throws'] = <int?>[];
        player['dart'] = 0;
        player['round'] = ((player['round'] as int?) ?? 1) + 1;

        players[index] = player;

        final moved = _nextTurn(state, players, index);
        state = _syncTurnStartScoreFromCurrentScore(moved);
        continue;
      }

      if (endKind == 'checkout') {
        player['score'] = 0;
        player['throws'] = <int?>[];
        player['dart'] = 0;

        players[index] = player;

        final won = _winLeg(state, players, index);
        state = _syncTurnStartScoreFromCurrentScore(won);
        continue;
      }

      player['score'] = startScore - total;
      player['throws'] = <int?>[];
      player['dart'] = 0;
      player['round'] = ((player['round'] as int?) ?? 1) + 1;

      players[index] = player;

      final moved = _nextTurn(state, players, index);
      state = _syncTurnStartScoreFromCurrentScore(moved);
    }

    return state.copyWith(history: history);
  }

  static Map<String, dynamic>? _currentTurnPlayer(RoomData data) {
    for (final p in data.players) {
      if (p['turn'] == true) return p;
    }
    return null;
  }

  static RoomData _syncTurnStartScoreFromCurrentScore(RoomData state) {
    final updated = <Map<String, dynamic>>[];

    for (final raw in state.players) {
      final p = Map<String, dynamic>.from(raw);

      if (p['turn'] == true) {
        p['turnStartScore'] = p['score'];
      }

      updated.add(p);
    }

    return state.copyWith(players: updated);
  }

  static List<Map<String, dynamic>> _resetPlayers(RoomData state) {
    final isX01 = state.game.type == GameType.x01;
    final isCricket = state.game.type == GameType.cricket;
    final startScore = state.game.startingScore ?? 501;

    final sorted = List<Map<String, dynamic>>.from(state.players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];

      final base = <String, dynamic>{
        'id': p['id'],
        'name': p['name'],
        'ownerId': p['ownerId'],
        'isGuest': p['isGuest'],
        'order': i,
        'lastSeen': p['lastSeen'],
        'legs': 0,
        'sets': 0,
        'turn': i == 0,
        'throws': <int?>[],
        'round': 1,
        'dart': 0,
        'inputMode': 'dart',
        'lastDartMultiplier': 1,
      };

      if (isX01) {
        base['score'] = startScore;
        base['turnStartScore'] = startScore;
      }

      if (isCricket) {
        base['score'] = 0;
        base['turnStartScore'] = 0;
        base['cricket'] = {
          '20': 0,
          '19': 0,
          '18': 0,
          '17': 0,
          '16': 0,
          '15': 0,
          '25': 0,
        };
      }

      result.add(base);
    }

    return result;
  }

  static RoomData _winLeg(
      RoomData state,
      List<Map<String, dynamic>> players,
      int winnerIndex,
      ) {
    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo((b['order'] ?? 0)));

    if (sorted.isEmpty) {
      return state.copyWith(players: players);
    }

    int nextStarterOrder;

    if (state.teamSize > 1) {
      final teams = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < sorted.length; i += state.teamSize) {
        if (i + state.teamSize <= sorted.length) {
          teams.add(sorted.sublist(i, i + state.teamSize));
        }
      }

      final currentStarterTeamIndex =
          (state.legStarterOrder ~/ state.teamSize) % teams.length;
      final nextTeamIndex = (currentStarterTeamIndex + 1) % teams.length;
      final nextTeam = teams[nextTeamIndex];

      nextStarterOrder = nextTeam.first['order'];
    } else {
      nextStarterOrder = (state.legStarterOrder + 1) % sorted.length;
    }

    final updated = <Map<String, dynamic>>[];

    for (int i = 0; i < players.length; i++) {
      final p = Map<String, dynamic>.from(players[i]);

      if (i == winnerIndex) {
        p['legs'] = ((p['legs'] as int?) ?? 0) + 1;
      }

      p['score'] = state.game.startingScore ?? 501;
      p['turn'] = (p['order'] ?? 0) == nextStarterOrder;
      p['throws'] = <int?>[];
      p['dart'] = 0;
      p['round'] = 1;
      p['turnStartScore'] = p['score'];

      updated.add(p);
    }

    return state.copyWith(
      players: updated,
      legStarterOrder: nextStarterOrder,
    );
  }

  static RoomData _nextTurn(
      RoomData state,
      List<Map<String, dynamic>> players,
      int currentIndex,
      ) {
    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo((b['order'] ?? 0)));

    final List<Map<String, dynamic>> turnOrder = [];

    if (state.teamSize > 1) {
      final teams = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < sorted.length; i += state.teamSize) {
        if (i + state.teamSize <= sorted.length) {
          teams.add(sorted.sublist(i, i + state.teamSize));
        }
      }

      final maxPlayersPerTeam = state.teamSize;

      for (int i = 0; i < maxPlayersPerTeam; i++) {
        for (final team in teams) {
          if (i < team.length) {
            turnOrder.add(team[i]);
          }
        }
      }
    } else {
      turnOrder.addAll(sorted);
    }

    final currentPlayer = players[currentIndex];

    final orderIndex = turnOrder.indexWhere(
          (p) => p['id'] == currentPlayer['id'],
    );

    if (orderIndex == -1 || turnOrder.isEmpty) {
      return state.copyWith(players: players);
    }

    final nextOrderIndex = (orderIndex + 1) % turnOrder.length;
    final nextPlayerId = turnOrder[nextOrderIndex]['id'];

    final updated = <Map<String, dynamic>>[];

    for (final p in players) {
      final copy = Map<String, dynamic>.from(p);
      copy['turn'] = p['id'] == nextPlayerId;
      copy['throws'] = p['id'] == currentPlayer['id']
          ? <int?>[]
          : List<int?>.from(copy['throws'] ?? const <int?>[]);
      copy['dart'] = p['id'] == currentPlayer['id']
          ? 0
          : ((copy['dart'] as int?) ?? 0);
      updated.add(copy);
    }

    return state.copyWith(players: updated);
  }
}