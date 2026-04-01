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

    final liveThrows = List<int?>.from(currentPlayer['throws'] ?? const <int?>[]);
    if (liveThrows.length >= 3) return data;

    final currentScore = (currentPlayer['score'] as int?) ?? 0;
    final nextThrows = List<int?>.from(liveThrows)..add(value);
    final newScore = currentScore - value;

    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final player = Map<String, dynamic>.from(players[index]);
    player['throws'] = nextThrows;
    player['dart'] = nextThrows.length;
    player['score'] = newScore;
    player['inputMode'] = 'dart';
    players[index] = player;

    bool isEnd = false;
    String endKind = 'normal';

    if (newScore < 0) {
      isEnd = true;
      endKind = 'bust';
    } else if (newScore == 0) {
      isEnd = true;
      endKind = 'checkout';
    } else if (nextThrows.length == 3) {
      isEnd = true;
      endKind = 'normal';
    }

    if (!isEnd) {
      return data.copyWith(players: players);
    }

    final turn = <String, dynamic>{
      'playerId': playerId,
      'startScore': (player['turnStartScore'] as int?) ?? currentScore,
      'throws': nextThrows,
      'total': nextThrows.fold<int>(0, (sum, e) => sum + (e ?? 0)),
      'inputMode': 'dart',
      'endKind': endKind,
    };

    final updatedMatch = _appendTurnToMatch(
      data,
      turn,
      winnerIndex: index,
      endKind: endKind,
    );

    return _rebuildStateFromMatch(
      data.copyWith(
        match: updatedMatch,
        history: _flattenMatchToHistory(updatedMatch),
      ),
      updatedMatch,
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

    final currentScore = (currentPlayer['score'] as int?) ?? 0;
    final newScore = currentScore - total;

    String endKind = 'normal';
    if (newScore < 0) {
      endKind = 'bust';
    } else if (newScore == 0) {
      endKind = 'checkout';
    }

    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final player = Map<String, dynamic>.from(players[index]);
    player['inputMode'] = 'total';
    players[index] = player;

    final turn = <String, dynamic>{
      'playerId': playerId,
      'startScore': (currentPlayer['turnStartScore'] as int?) ?? currentScore,
      'throws': <int?>[null, null, null],
      'total': total,
      'inputMode': 'total',
      'endKind': endKind,
    };

    final updatedMatch = _appendTurnToMatch(
      data.copyWith(players: players),
      turn,
      winnerIndex: index,
      endKind: endKind,
    );

    return _rebuildStateFromMatch(
      data.copyWith(
        match: updatedMatch,
        history: _flattenMatchToHistory(updatedMatch),
      ),
      updatedMatch,
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

        final newTotal = throws.fold<int>(0, (sum, e) => sum + (e ?? 0));

        player['throws'] = throws;
        player['dart'] = throws.length;
        player['score'] = turnStart - newTotal;

        players[index] = player;

        return state.copyWith(players: players);
      }
    }

    // =========================
    // 2. UNDO ULTIMO INPUT CHIUSO
    // mantiene la logica attuale:
    // dart chiuso -> ripristina il turno live senza ultima freccetta
    // total chiuso -> ripristina inizio turno
    // checkout -> ripristina correttamente punteggi/turni di TUTTI
    // =========================
    final last = _peekLastClosedTurn(state.match);
    if (last == null) return state;

    final nextMatch = _removeLastClosedTurnFromMatch(state.match);

    RoomData rebuilt = _rebuildStateFromMatch(
      state.copyWith(
        match: nextMatch,
        history: _flattenMatchToHistory(nextMatch),
        phase: RoomPhase.match,
      ),
      nextMatch,
    );

    final playerId = last['playerId'];
    final inputMode = last['inputMode'] ?? 'total';
    final startScore = (last['startScore'] as int?) ?? 0;
    final lastThrows = List<int?>.from(last['throws'] ?? const <int?>[]);

    final players = List<Map<String, dynamic>>.from(rebuilt.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return rebuilt;

    for (int i = 0; i < players.length; i++) {
      final copy = Map<String, dynamic>.from(players[i]);
      copy['turn'] = i == index;
      players[i] = copy;
    }

    final player = Map<String, dynamic>.from(players[index]);
    player['inputMode'] = inputMode;
    player['turnStartScore'] = startScore;

    if (inputMode == 'dart') {
      final restored = List<int?>.from(lastThrows);
      if (restored.isNotEmpty) {
        restored.removeLast();
      }

      final partialTotal = restored.fold<int>(0, (sum, e) => sum + (e ?? 0));

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
      history: _flattenMatchToHistory(nextMatch),
      match: nextMatch,
      phase: RoomPhase.match,
    );
  }

  static RoomData _rebuildStateFromMatch(
      RoomData base,
      List<Map<String, dynamic>> match,
      ) {
    final normalizedMatch = _ensureMatchTree(match);
    final flatTurns = _flattenMatchToHistory(normalizedMatch);

    RoomData state = base.copyWith(
      players: _resetPlayers(base),
      history: flatTurns,
      match: normalizedMatch,
      legStarterOrder: 0,
      phase: RoomPhase.match,
    );

    for (final rawTurn in flatTurns) {
      final turn = Map<String, dynamic>.from(rawTurn);
      state = _applyClosedTurn(state, turn);
    }

    return state.copyWith(
      history: flatTurns,
      match: normalizedMatch,
    );
  }

  static RoomData _applyClosedTurn(
      RoomData state,
      Map<String, dynamic> turn,
      ) {
    final playerId = turn['playerId'];
    final startScore = (turn['startScore'] as int?) ?? 0;
    final total = (turn['total'] as int?) ?? 0;
    final endKind = (turn['endKind'] as String?) ?? 'normal';

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);
    player['inputMode'] = turn['inputMode'] ?? 'dart';
    if (endKind == 'bust') {
      player['score'] = startScore;
      player['throws'] = <int?>[];
      player['dart'] = 0;
      player['round'] = ((player['round'] as int?) ?? 1) + 1;
      players[index] = player;

      final moved = _nextTurn(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(moved);
    }

    if (endKind == 'checkout') {
      player['score'] = 0;
      player['throws'] = <int?>[];
      player['dart'] = 0;
      players[index] = player;

      return _advanceAfterCheckout(state, players, index);
    }

    player['score'] = startScore - total;
    player['throws'] = <int?>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;
    players[index] = player;

    final moved = _nextTurn(state, players, index);
    return _syncTurnStartScoreFromCurrentScore(moved);
  }

  static List<Map<String, dynamic>> _appendTurnToMatch(
      RoomData data,
      Map<String, dynamic> turn, {
        required int winnerIndex,
        required String endKind,
      }) {
    final match = _ensureMatchTree(data.match);
    final copied = _deepCopyMatch(match);

    if (copied.isEmpty) {
      return _ensureMatchTree(copied);
    }

    final setIndex = copied.length - 1;
    final currentSet = Map<String, dynamic>.from(copied[setIndex]);
    final legs = List<Map<String, dynamic>>.from(currentSet['legs'] ?? const []);

    if (legs.isEmpty) {
      legs.add({
        'legNumber': 1,
        'turns': <Map<String, dynamic>>[],
      });
    }

    final legIndex = legs.length - 1;
    final currentLeg = Map<String, dynamic>.from(legs[legIndex]);
    final turns = List<Map<String, dynamic>>.from(currentLeg['turns'] ?? const []);

    turns.add(Map<String, dynamic>.from(turn));
    currentLeg['turns'] = turns;
    legs[legIndex] = currentLeg;
    currentSet['legs'] = legs;
    copied[setIndex] = currentSet;

    if (endKind != 'checkout') {
      return copied;
    }

    final winner = Map<String, dynamic>.from(data.players[winnerIndex]);
    final winnerLegsAfter = ((winner['legs'] as int?) ?? 0) + 1;
    final setWon = winnerLegsAfter >= data.matchConfig.legsToWin;
    final winnerSetsAfter =
        ((winner['sets'] as int?) ?? 0) + (setWon ? 1 : 0);
    final matchWon = winnerSetsAfter >= data.matchConfig.setsToWin;

    if (matchWon) {
      return copied;
    }

    if (setWon) {
      copied.add({
        'setNumber': copied.length + 1,
        'legs': [
          {
            'legNumber': 1,
            'turns': <Map<String, dynamic>>[],
          },
        ],
      });
      return copied;
    }

    final refreshedSet = Map<String, dynamic>.from(copied[setIndex]);
    final refreshedLegs =
    List<Map<String, dynamic>>.from(refreshedSet['legs'] ?? const []);

    refreshedLegs.add({
      'legNumber': refreshedLegs.length + 1,
      'turns': <Map<String, dynamic>>[],
    });

    refreshedSet['legs'] = refreshedLegs;
    copied[setIndex] = refreshedSet;

    return copied;
  }

  static Map<String, dynamic>? _peekLastClosedTurn(
      List<Map<String, dynamic>> match,
      ) {
    final normalized = _ensureMatchTree(match);

    for (int setIndex = normalized.length - 1; setIndex >= 0; setIndex--) {
      final set = Map<String, dynamic>.from(normalized[setIndex]);
      final legs = List<Map<String, dynamic>>.from(set['legs'] ?? const []);

      for (int legIndex = legs.length - 1; legIndex >= 0; legIndex--) {
        final leg = Map<String, dynamic>.from(legs[legIndex]);
        final turns = List<Map<String, dynamic>>.from(leg['turns'] ?? const []);

        if (turns.isNotEmpty) {
          return Map<String, dynamic>.from(turns.last);
        }
      }
    }

    return null;
  }

  static List<Map<String, dynamic>> _removeLastClosedTurnFromMatch(
      List<Map<String, dynamic>> match,
      ) {
    final copied = _deepCopyMatch(_ensureMatchTree(match));

    while (copied.isNotEmpty) {
      final setIndex = copied.length - 1;
      final currentSet = Map<String, dynamic>.from(copied[setIndex]);
      final legs = List<Map<String, dynamic>>.from(currentSet['legs'] ?? const []);

      if (legs.isEmpty) {
        if (copied.length == 1) {
          return _ensureMatchTree(const []);
        }
        copied.removeLast();
        continue;
      }

      final legIndex = legs.length - 1;
      final currentLeg = Map<String, dynamic>.from(legs[legIndex]);
      final turns = List<Map<String, dynamic>>.from(currentLeg['turns'] ?? const []);

      if (turns.isEmpty) {
        if (legs.length > 1) {
          legs.removeLast();
          currentSet['legs'] = legs;
          copied[setIndex] = currentSet;
          continue;
        }

        if (copied.length > 1) {
          copied.removeLast();
          continue;
        }

        return _ensureMatchTree(const []);
      }

      turns.removeLast();
      currentLeg['turns'] = turns;
      legs[legIndex] = currentLeg;
      currentSet['legs'] = legs;
      copied[setIndex] = currentSet;
      return copied;
    }

    return _ensureMatchTree(const []);
  }

  static List<Map<String, dynamic>> _flattenMatchToHistory(
      List<Map<String, dynamic>> match,
      ) {
    final normalized = _ensureMatchTree(match);
    final flat = <Map<String, dynamic>>[];

    for (final rawSet in normalized) {
      final set = Map<String, dynamic>.from(rawSet);
      final legs = List<Map<String, dynamic>>.from(set['legs'] ?? const []);

      for (final rawLeg in legs) {
        final leg = Map<String, dynamic>.from(rawLeg);
        final turns = List<Map<String, dynamic>>.from(leg['turns'] ?? const []);

        for (final rawTurn in turns) {
          flat.add(Map<String, dynamic>.from(rawTurn));
        }
      }
    }

    return flat;
  }

  static List<Map<String, dynamic>> _ensureMatchTree(
      List<Map<String, dynamic>> match,
      ) {
    if (match.isNotEmpty) {
      return _deepCopyMatch(match);
    }

    return [
      {
        'setNumber': 1,
        'legs': [
          {
            'legNumber': 1,
            'turns': <Map<String, dynamic>>[],
          },
        ],
      },
    ];
  }

  static List<Map<String, dynamic>> _deepCopyMatch(
      List<Map<String, dynamic>> match,
      ) {
    final copied = <Map<String, dynamic>>[];

    for (final rawSet in match) {
      final set = Map<String, dynamic>.from(rawSet);
      final rawLegs = List<Map<String, dynamic>>.from(set['legs'] ?? const []);
      final copiedLegs = <Map<String, dynamic>>[];

      for (final rawLeg in rawLegs) {
        final leg = Map<String, dynamic>.from(rawLeg);
        final rawTurns = List<Map<String, dynamic>>.from(leg['turns'] ?? const []);
        final copiedTurns = <Map<String, dynamic>>[];

        for (final rawTurn in rawTurns) {
          copiedTurns.add(Map<String, dynamic>.from(rawTurn));
        }

        leg['turns'] = copiedTurns;
        copiedLegs.add(leg);
      }

      set['legs'] = copiedLegs;
      copied.add(set);
    }

    return copied;
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

  static RoomData _advanceAfterCheckout(
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

    final winner = Map<String, dynamic>.from(players[winnerIndex]);
    final winnerOrder = (winner['order'] ?? 0) as int;

    final winningTeamStart = state.teamSize > 1
        ? (winnerOrder ~/ state.teamSize) * state.teamSize
        : winnerOrder;
    final winningTeamEnd = state.teamSize > 1
        ? winningTeamStart + state.teamSize
        : winnerOrder + 1;

    final isWinningTeamPlayer = (Map<String, dynamic> p) {
      final order = (p['order'] ?? 0) as int;
      return order >= winningTeamStart && order < winningTeamEnd;
    };

    int teamLegsBefore = 0;
    int teamSetsBefore = 0;

    if (state.teamSize > 1) {
      for (final p in players) {
        if (isWinningTeamPlayer(p)) {
          teamLegsBefore = (p['legs'] as int?) ?? 0;
          teamSetsBefore = (p['sets'] as int?) ?? 0;
          break;
        }
      }
    } else {
      teamLegsBefore = (winner['legs'] as int?) ?? 0;
      teamSetsBefore = (winner['sets'] as int?) ?? 0;
    }

    final winnerLegsAfter = teamLegsBefore + 1;
    final setWon = winnerLegsAfter >= state.matchConfig.legsToWin;
    final winnerSetsAfter = teamSetsBefore + (setWon ? 1 : 0);
    final matchWon = winnerSetsAfter >= state.matchConfig.setsToWin;

    final updated = <Map<String, dynamic>>[];

    for (int i = 0; i < players.length; i++) {
      final p = Map<String, dynamic>.from(players[i]);
      final belongsToWinningTeam = isWinningTeamPlayer(p);

      if (belongsToWinningTeam) {
        if (setWon) {
          p['sets'] = winnerSetsAfter;
          p['legs'] = 0;
        } else {
          p['legs'] = winnerLegsAfter;
        }
      } else if (setWon) {
        p['legs'] = 0;
      }

      p['score'] = state.game.startingScore ?? 501;
      p['turn'] = matchWon ? false : (p['order'] ?? 0) == nextStarterOrder;
      p['throws'] = <int?>[];
      p['dart'] = 0;
      p['round'] = 1;
      p['turnStartScore'] = p['score'];
      updated.add(p);
    }

    return state.copyWith(
      players: updated,
      legStarterOrder: nextStarterOrder,
      phase: RoomPhase.match,
    );
  }

  static RoomData _nextTurn(
      RoomData state,
      List<Map<String, dynamic>> players,
      int currentIndex,
      ) {
    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo((b['order'] ?? 0)));

    final turnOrder = <Map<String, dynamic>>[];

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

      if (p['id'] == nextPlayerId) {
        copy['inputMode'] = copy['inputMode'] ?? 'dart';
      }

      copy['throws'] = p['id'] == currentPlayer['id']
          ? <int?>[]
          : List<int?>.from(copy['throws'] ?? const <int?>[]);
      copy['dart'] =
      p['id'] == currentPlayer['id'] ? 0 : ((copy['dart'] as int?) ?? 0);
      updated.add(copy);
    }

    return state.copyWith(players: updated);
  }
}