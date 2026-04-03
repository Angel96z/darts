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

  static RoomData applyIntent(
      RoomData state,
      String playerId,
      Map<String, dynamic> intent,
      ) {
    if (state.game.type == GameType.x01) {
      return _applyX01Intent(state, playerId, intent);
    }

    if (state.game.type == GameType.cricket) {
      return _applyCricketIntent(state, playerId, intent);
    }

    return state;
  }

  static RoomData applyThrow(
      RoomData data,
      String playerId,
      dynamic rawIntent,
      ) {
    final intent = _normalizeThrowIntent(rawIntent);
    if (intent == null) return data;

    if (data.game.type == GameType.x01) {
      return _applyX01Throw(data, playerId, intent);
    }

    if (data.game.type == GameType.cricket) {
      return _applyCricketThrow(data, playerId, intent);
    }

    return data;
  }

  static RoomData applyTurn(
      RoomData data,
      String playerId,
      int total, {
        bool isBust = false,
      }) {
    if (data.game.type == GameType.x01) {
      return _applyX01TotalTurn(
        data,
        playerId,
        total,
        isBust: isBust,
      );
    }

    return data;
  }

  static RoomData undo(RoomData state) {
    return undoLastThrow(state);
  }

  static RoomData undoLastThrow(RoomData state) {
    final livePlayer = _findPlayerWithLiveThrows(state);

    if (livePlayer != null) {
      return _undoLiveThrow(state, livePlayer);
    }

    final last = _peekLastClosedTurn(state.match);
    if (last == null) return state;

    final lastTurn = Map<String, dynamic>.from(last);
    final inputMode = (lastTurn['inputMode'] as String?) ?? 'dart';

    if (inputMode != 'dart') {
      final nextMatch = _removeLastClosedTurnFromMatch(state.match);
      return _rebuildStateFromMatch(
        state.copyWith(
          match: nextMatch,
          history: _flattenMatchToHistory(nextMatch),
        ),
        nextMatch,
      );
    }

    final originalThrows = _normalizeStoredThrows(lastTurn['throws']);
    final originalMeta = _normalizeMeta(lastTurn['throwMeta']);

    if (originalThrows.isEmpty) {
      final nextMatch = _removeLastClosedTurnFromMatch(state.match);
      return _rebuildStateFromMatch(
        state.copyWith(
          match: nextMatch,
          history: _flattenMatchToHistory(nextMatch),
        ),
        nextMatch,
      );
    }

    final reopenedThrows = List<Map<String, dynamic>>.from(originalThrows)
      ..removeLast();
    final reopenedMeta = List<String>.from(originalMeta);
    if (reopenedMeta.isNotEmpty) {
      reopenedMeta.removeLast();
    }

    final nextMatch = _removeLastClosedTurnFromMatch(state.match);

    RoomData rebuilt = _rebuildStateFromMatch(
      state.copyWith(
        match: nextMatch,
        history: _flattenMatchToHistory(nextMatch),
      ),
      nextMatch,
    );

    if (reopenedThrows.isEmpty) {
      return rebuilt;
    }

    final reopenedPlayerId = lastTurn['playerId'];
    final players = List<Map<String, dynamic>>.from(rebuilt.players);
    final index = players.indexWhere((p) => p['id'] == reopenedPlayerId);
    if (index == -1) return rebuilt;

    for (int i = 0; i < players.length; i++) {
      final p = Map<String, dynamic>.from(players[i]);
      p['turn'] = i == index;
      players[i] = p;
    }

    final player = Map<String, dynamic>.from(players[index]);
    final startScore = (lastTurn['startScore'] as int?) ??
        ((player['turnStartScore'] as int?) ?? 0);

    player['throws'] = reopenedThrows;
    player['throwMeta'] = reopenedMeta;
    player['dart'] = reopenedThrows.length;
    player['inputMode'] = 'dart';

    if (rebuilt.game.type == GameType.x01) {
      final reopenedTotal = reopenedThrows.fold<int>(
        0,
            (sum, item) => sum + _throwAppliedValue(item),
      );
      player['score'] = startScore - reopenedTotal;
      player['turnStartScore'] = startScore;
      player['opened'] = _hasPlayerOpened(
        rebuilt,
        reopenedPlayerId,
        liveThrows: reopenedThrows,
      );
    }
    if (rebuilt.game.type == GameType.cricket) {
      final liveState = _buildCricketLiveState(
        rebuilt,
        reopenedPlayerId,
        reopenedThrows,
      );

      player['cricket'] = Map<String, dynamic>.from(liveState['cricket']);
      player['cricketScore'] = liveState['cricketScore'];
      player['score'] = liveState['score'];
    }
    players[index] = player;
    return rebuilt.copyWith(players: players);
  }

  static RoomData _applyX01Intent(
      RoomData state,
      String playerId,
      Map<String, dynamic> intent,
      ) {
    switch (intent['type']) {
      case 'total':
        return _applyX01TotalTurn(
          state,
          playerId,
          (intent['value'] as int?) ?? 0,
        );
      case 'checkout':
        final current = _playerById(state, playerId);
        if (current == null) return state;
        return _applyX01TotalTurn(
          state,
          playerId,
          (current['score'] as int?) ?? 0,
        );
      case 'miss':
        return _applyX01TotalTurn(state, playerId, 0);
      case 'bust':
        return _applyX01TotalTurn(state, playerId, 0, isBust: true);
      default:
        return state;
    }
  }

  static RoomData _applyCricketIntent(
      RoomData state,
      String playerId,
      Map<String, dynamic> intent,
      ) {
    switch (intent['type']) {
      case 'miss':
        return _closeCricketTurn(state, playerId, const []);
      case 'bust':
        return _closeCricketTurn(state, playerId, const []);
      default:
        return state;
    }
  }

  static RoomData _applyX01Throw(
      RoomData data,
      String playerId,
      Map<String, dynamic> intent,
      ) {
    final currentPlayer = _currentTurnPlayer(data);
    if (currentPlayer == null) return data;
    if (currentPlayer['id'] != playerId) return data;

    final liveThrows = _normalizeStoredThrows(currentPlayer['throws']);
    final liveMeta = _normalizeMeta(currentPlayer['throwMeta']);

    if (liveThrows.length >= 3) return data;

    final currentScore = (currentPlayer['score'] as int?) ?? 0;
    final hasOpened = _hasPlayerOpened(
      data,
      playerId,
      liveThrows: liveThrows,
    );
    final requiresDoubleIn = data.game.doubleIn == true;
    final isMiss = intent['isMiss'] == true;
    final multiplier = (intent['multiplier'] as int?) ?? 1;
    final isDouble = multiplier == 2;

    int appliedValue = _throwBaseValue(intent);
    bool willOpen = false;

    if (requiresDoubleIn && !hasOpened) {
      if (!isMiss && isDouble) {
        willOpen = true;
      } else {
        appliedValue = 0;
      }
    }

    final storedThrow = Map<String, dynamic>.from(intent)
      ..['appliedValue'] = appliedValue
      ..['label'] = _throwLabel(intent);

    final nextThrows = List<Map<String, dynamic>>.from(liveThrows)
      ..add(storedThrow);
    final nextMeta = List<String>.from(liveMeta)..add(_throwLabel(intent));

    final newScore = currentScore - appliedValue;

    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final player = Map<String, dynamic>.from(players[index]);
    player['throws'] = nextThrows;
    player['throwMeta'] = nextMeta;
    player['dart'] = nextThrows.length;
    player['score'] = newScore;
    player['inputMode'] = 'dart';
    if (willOpen) {
      player['opened'] = true;
    }
    players[index] = player;

    bool isEnd = false;
    String endKind = 'normal';

    if (newScore < 0 || newScore == 1) {
      isEnd = true;
      endKind = 'bust';
    } else if (newScore == 0) {
      final valid = _validateCheckout(
        data,
        nextMeta.isEmpty ? null : nextMeta.last,
      );
      isEnd = true;
      endKind = valid ? 'checkout' : 'bust';
    } else if (nextThrows.length == 3) {
      isEnd = true;
    }

    if (!isEnd) {
      return data.copyWith(players: players);
    }

    final turn = <String, dynamic>{
      'playerId': playerId,
      'startScore': (player['turnStartScore'] as int?) ?? currentScore,
      'throws': nextThrows,
      'throwMeta': nextMeta,
      'total': nextThrows.fold<int>(0, (s, e) => s + _throwAppliedValue(e)),
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

  static RoomData _applyCricketThrow(
      RoomData data,
      String playerId,
      Map<String, dynamic> intent,
      ) {
    final currentPlayer = _currentTurnPlayer(data);
    if (currentPlayer == null) return data;
    if (currentPlayer['id'] != playerId) return data;

    final liveThrows = _normalizeStoredThrows(currentPlayer['throws']);
    final liveMeta = _normalizeMeta(currentPlayer['throwMeta']);

    if (liveThrows.length >= 3) return data;

    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final storedThrow = Map<String, dynamic>.from(intent)
      ..['label'] = _throwLabel(intent)
      ..['marks'] = _cricketMarks(intent);

    final nextThrows = List<Map<String, dynamic>>.from(liveThrows)
      ..add(storedThrow);

    final nextMeta = List<String>.from(liveMeta)
      ..add(_throwLabel(intent));

    final player = Map<String, dynamic>.from(players[index]);
    final liveState = _buildCricketLiveState(
      data,
      playerId,
      nextThrows,
    );

    player['throws'] = nextThrows;
    player['throwMeta'] = nextMeta;
    player['dart'] = nextThrows.length;
    player['inputMode'] = 'dart';
    player['cricket'] = Map<String, dynamic>.from(liveState['cricket']);
    player['cricketScore'] = liveState['cricketScore'];
    player['score'] = liveState['score'];

    players[index] = player;

    final updated = data.copyWith(players: players);

    if (nextThrows.length < 3) {
      return updated;
    }

    return _closeCricketTurn(
      updated,
      playerId,
      nextThrows,
    );
  }
  static Map<String, dynamic> _buildCricketLiveState(
      RoomData data,
      String playerId,
      List<Map<String, dynamic>> liveThrows,
      ) {
    final rebuilt = _rebuildStateFromMatch(
      data.copyWith(
        players: _resetPlayers(data),
      ),
      data.match,
    );

    final rebuiltPlayer = _playerById(rebuilt, playerId);
    if (rebuiltPlayer == null) {
      return {
        'cricket': {
          '20': 0,
          '19': 0,
          '18': 0,
          '17': 0,
          '16': 0,
          '15': 0,
          '25': 0,
        },
        'cricketScore': 0,
        'score': 0,
      };
    }

    final cricket = Map<String, dynamic>.from(rebuiltPlayer['cricket'] ?? {
      '20': 0,
      '19': 0,
      '18': 0,
      '17': 0,
      '16': 0,
      '15': 0,
      '25': 0,
    });

    int cricketScore = (rebuiltPlayer['cricketScore'] as int?) ?? 0;

    for (final t in liveThrows) {
      final target = _cricketTargetKey(t);
      final marks = (t['marks'] as int?) ?? _cricketMarks(t);

      if (target == null || marks == 0) continue;

      final current = (cricket[target] as int?) ?? 0;
      final next = current + marks;

      final prevOverflow = current > 3 ? current - 3 : 0;
      final nextOverflow = next > 3 ? next - 3 : 0;
      final gained = nextOverflow - prevOverflow;

      if (gained > 0 &&
          !_allOpponentsClosedTarget(rebuilt, playerId, target)) {
        cricketScore += _cricketNumberValue(target) * gained;
      }

      cricket[target] = next;
    }

    return {
      'cricket': cricket,
      'cricketScore': cricketScore,
      'score': cricketScore,
    };
  }
  static RoomData _applyX01TotalTurn(
      RoomData data,
      String playerId,
      int total, {
        bool isBust = false,
      }) {
    final currentPlayer = _currentTurnPlayer(data);
    if (currentPlayer == null) return data;
    if (currentPlayer['id'] != playerId) return data;

    final currentScore = (currentPlayer['score'] as int?) ?? 0;
    final newScore = currentScore - total;

    String endKind = 'normal';

    if (isBust) {
      endKind = 'bust';
    } else if (newScore < 0 || newScore == 1) {
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
      'throws': <Map<String, dynamic>>[],
      'throwMeta': <String>[],
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

  static RoomData _closeCricketTurn(
      RoomData data,
      String playerId,
      List<Map<String, dynamic>> throws,
      ) {
    final players = List<Map<String, dynamic>>.from(data.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return data;

    final turn = <String, dynamic>{
      'playerId': playerId,
      'startScore': 0,
      'throws': throws,
      'throwMeta': throws.map(_throwLabel).toList(),
      'total': throws.fold<int>(
        0,
            (sum, t) => sum + ((t['marks'] as int?) ?? _cricketMarks(t)),
      ),
      'inputMode': 'dart',
      'endKind': _cricketTurnEndKind(
        data.copyWith(players: players),
        playerId,
        throws,
      ),
    };

    final updatedMatch = _appendTurnToMatch(
      data.copyWith(players: players),
      turn,
      winnerIndex: index,
      endKind: turn['endKind'],
    );

    return _rebuildStateFromMatch(
      data.copyWith(
        match: updatedMatch,
        history: _flattenMatchToHistory(updatedMatch),
      ),
      updatedMatch,
    );
  }


  static String _cricketTurnEndKind(
      RoomData data,
      String playerId,
      List<Map<String, dynamic>> throws,
      ) {
    return _isCricketWinner(data, playerId) ? 'checkout' : 'normal';
  }


  static bool _validateCheckout(RoomData data, String? lastMeta) {
    if (lastMeta == null) return true;

    final isDouble = lastMeta.startsWith('D');
    final isTriple = lastMeta.startsWith('T');
    final config = data.game;

    if (config.doubleOut == true) return isDouble;
    if (config.tripleOut == true) return isDouble || isTriple;

    return true;
  }

  static RoomData _undoLiveThrow(
      RoomData state,
      Map<String, dynamic> livePlayer,
      ) {
    final throws = _normalizeStoredThrows(livePlayer['throws']);
    final meta = _normalizeMeta(livePlayer['throwMeta']);
    if (throws.isEmpty) return state;

    final lastThrow = throws.last;

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == livePlayer['id']);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    final turnStart = (player['turnStartScore'] as int?) ??
        (player['score'] as int?) ??
        0;

    // rimuovi ultimo throw
    throws.removeLast();
    if (meta.isNotEmpty) {
      meta.removeLast();
    }

    player['throws'] = throws;
    player['throwMeta'] = meta;
    player['dart'] = throws.length;
    player['turn'] = true;
    player['inputMode'] = 'dart';

    // ===== X01 (immutato)
    if (state.game.type == GameType.x01) {
      final newTotal = throws.fold<int>(0, (s, e) => s + _throwAppliedValue(e));
      player['score'] = turnStart - newTotal;
      player['opened'] = _hasPlayerOpened(
        state,
        player['id'],
        liveThrows: throws,
      );
    }

    // ===== CRICKET FIX
    if (state.game.type == GameType.cricket) {
      final liveState = _buildCricketLiveState(
        state,
        player['id'],
        throws,
      );

      player['cricket'] = Map<String, dynamic>.from(liveState['cricket']);
      player['cricketScore'] = liveState['cricketScore'];
      player['score'] = liveState['score'];
    }

    players[index] = player;

    // set turn corretto
    for (int i = 0; i < players.length; i++) {
      if (i == index) continue;
      final other = Map<String, dynamic>.from(players[i]);
      other['turn'] = false;
      players[i] = other;
    }

    return state.copyWith(players: players);
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
    if (state.game.type == GameType.x01) {
      return _applyClosedX01Turn(state, turn);
    }

    if (state.game.type == GameType.cricket) {
      return _applyClosedCricketTurn(state, turn);
    }

    return state;
  }

  static RoomData _applyClosedX01Turn(
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
      player['throws'] = <Map<String, dynamic>>[];
      player['throwMeta'] = <String>[];
      player['dart'] = 0;
      player['round'] = ((player['round'] as int?) ?? 1) + 1;
      players[index] = player;

      final moved = _nextTurn(state, players, index);
      return _syncTurnStartScoreFromCurrentScore(moved);
    }

    if (endKind == 'checkout') {
      player['score'] = 0;
      player['throws'] = <Map<String, dynamic>>[];
      player['throwMeta'] = <String>[];
      player['dart'] = 0;
      players[index] = player;

      return _advanceAfterLegWin(state, players, index);
    }

    player['score'] = startScore - total;
    player['throws'] = <Map<String, dynamic>>[];
    player['throwMeta'] = <String>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;
    players[index] = player;

    final moved = _nextTurn(state, players, index);
    return _syncTurnStartScoreFromCurrentScore(moved);
  }

  static RoomData _applyClosedCricketTurn(
      RoomData state,
      Map<String, dynamic> turn,
      ) {
    final playerId = turn['playerId'];
    final throws = _normalizeStoredThrows(turn['throws']);
    final endKind = (turn['endKind'] as String?) ?? 'normal';

    final players = List<Map<String, dynamic>>.from(state.players);
    final index = players.indexWhere((p) => p['id'] == playerId);
    if (index == -1) return state;

    final player = Map<String, dynamic>.from(players[index]);

    final cricket = Map<String, dynamic>.from(player['cricket'] ?? {
      '20': 0,
      '19': 0,
      '18': 0,
      '17': 0,
      '16': 0,
      '15': 0,
      '25': 0,
    });

    int cricketScore = (player['cricketScore'] as int?) ?? 0;

    for (final t in throws) {
      final target = _cricketTargetKey(t);
      final marks = (t['marks'] as int?) ?? _cricketMarks(t);

      if (target == null || marks == 0) continue;

      final current = (cricket[target] as int?) ?? 0;
      final next = current + marks;

      final prevOverflow = current > 3 ? current - 3 : 0;
      final nextOverflow = next > 3 ? next - 3 : 0;
      final gained = nextOverflow - prevOverflow;

      if (gained > 0 &&
          !_allOpponentsClosedTarget(state, playerId, target)) {
        cricketScore += _cricketNumberValue(target) * gained;
      }

      cricket[target] = next;
    }

    player['cricket'] = cricket;
    player['cricketScore'] = cricketScore;
    player['score'] = cricketScore;
    player['throws'] = <Map<String, dynamic>>[];
    player['throwMeta'] = <String>[];
    player['dart'] = 0;
    player['round'] = ((player['round'] as int?) ?? 1) + 1;
    player['inputMode'] = 'dart';

    players[index] = player;

    if (endKind == 'checkout') {
      return _advanceAfterLegWin(state, players, index);
    }

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
    final winnerSetsAfter = ((winner['sets'] as int?) ?? 0) + (setWon ? 1 : 0);
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
        final rawTurns =
        List<Map<String, dynamic>>.from(leg['turns'] ?? const []);
        final copiedTurns = <Map<String, dynamic>>[];

        for (final rawTurn in rawTurns) {
          final turn = Map<String, dynamic>.from(rawTurn);
          turn['throws'] = _normalizeStoredThrows(turn['throws']);
          turn['throwMeta'] = _normalizeMeta(turn['throwMeta']);
          copiedTurns.add(turn);
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

  static Map<String, dynamic>? _findPlayerWithLiveThrows(RoomData data) {
    final current = _currentTurnPlayer(data);
    if (current != null && _normalizeStoredThrows(current['throws']).isNotEmpty) {
      return current;
    }

    for (final raw in data.players) {
      if (_normalizeStoredThrows(raw['throws']).isNotEmpty) {
        return raw;
      }
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
        'throws': <Map<String, dynamic>>[],
        'throwMeta': <String>[],
        'round': 1,
        'dart': 0,
        'inputMode': 'dart',
        'lastDartMultiplier': 1,
        'lastThrowIntent': null,
        'opened': false,
      };

      if (isX01) {
        base['score'] = startScore;
        base['turnStartScore'] = startScore;
      }

      if (isCricket) {
        base['score'] = 0;
        base['turnStartScore'] = 0;
        base['cricketScore'] = 0;
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

  static RoomData _advanceAfterLegWin(
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
    final winningTeamEnd =
    state.teamSize > 1 ? winningTeamStart + state.teamSize : winnerOrder + 1;

    bool isWinningTeamPlayer(Map<String, dynamic> p) {
      final order = (p['order'] ?? 0) as int;
      return order >= winningTeamStart && order < winningTeamEnd;
    }

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

      if (state.game.type == GameType.x01) {
        p['score'] = state.game.startingScore ?? 501;
        p['turnStartScore'] = p['score'];
      } else if (state.game.type == GameType.cricket) {
        p['score'] = 0;
        p['turnStartScore'] = 0;
        p['cricketScore'] = 0;
        p['cricket'] = {
          '20': 0,
          '19': 0,
          '18': 0,
          '17': 0,
          '16': 0,
          '15': 0,
          '25': 0,
        };
      }

      p['turn'] = matchWon ? false : (p['order'] ?? 0) == nextStarterOrder;
      p['throws'] = <Map<String, dynamic>>[];
      p['throwMeta'] = <String>[];
      p['dart'] = 0;
      p['round'] = 1;
      p['inputMode'] = 'dart';
      p['opened'] = false;
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
      final isCurrent = p['id'] == currentPlayer['id'];
      final isNext = p['id'] == nextPlayerId;

      copy['turn'] = isNext;
      if (isNext) {
        copy['inputMode'] = copy['inputMode'] ?? 'dart';
      }

      copy['throws'] =
      isCurrent ? <Map<String, dynamic>>[] : _normalizeStoredThrows(copy['throws']);
      copy['throwMeta'] =
      isCurrent ? <String>[] : _normalizeMeta(copy['throwMeta']);
      copy['dart'] = isCurrent ? 0 : ((copy['dart'] as int?) ?? 0);

      updated.add(copy);
    }

    return state.copyWith(players: updated);
  }

  static List<Map<String, dynamic>> appendTurnToMatchPublic(
      RoomData data,
      Map<String, dynamic> turn, {
        required int winnerIndex,
        required String endKind,
      }) {
    return _appendTurnToMatch(
      data,
      turn,
      winnerIndex: winnerIndex,
      endKind: endKind,
    );
  }

  static RoomData rebuildStateFromMatchPublic(
      RoomData base,
      List<Map<String, dynamic>> match,
      ) {
    return _rebuildStateFromMatch(base, match);
  }

  static List<Map<String, dynamic>> flattenMatchToHistoryPublic(
      List<Map<String, dynamic>> match,
      ) {
    return _flattenMatchToHistory(match);
  }

  static Map<String, dynamic>? _normalizeThrowIntent(dynamic rawIntent) {
    if (rawIntent is Map) {
      final map = Map<String, dynamic>.from(rawIntent);
      final isMiss = map['isMiss'] == true;
      final number = map['number'];
      final multiplier = (map['multiplier'] as int?) ?? (isMiss ? 0 : 1);

      return {
        'type': 'dart',
        'number': isMiss ? null : number,
        'multiplier': isMiss ? 0 : multiplier,
        'isMiss': isMiss,
      };
    }

    if (rawIntent is int) {
      if (rawIntent == 0) {
        return {
          'type': 'dart',
          'number': null,
          'multiplier': 0,
          'isMiss': true,
        };
      }

      return {
        'type': 'dart',
        'number': rawIntent,
        'multiplier': 1,
        'isMiss': false,
      };
    }

    return null;
  }

  static List<Map<String, dynamic>> _normalizeStoredThrows(dynamic rawThrows) {
    final items = List.from(rawThrows ?? const []);

    return items.map<Map<String, dynamic>>((e) {
      if (e is Map) {
        return Map<String, dynamic>.from(e);
      }

      if (e is int) {
        return {
          'type': 'legacy',
          'value': e,
          'appliedValue': e,
        };
      }

      return {
        'type': 'unknown',
        'value': e,
        'appliedValue': 0,
      };
    }).toList();
  }

  static List<String> _normalizeMeta(dynamic rawMeta) {
    return List<String>.from(rawMeta ?? const []);
  }

  static int _throwBaseValue(Map<String, dynamic> intent) {
    if (intent['isMiss'] == true) return 0;
    final number = intent['number'];
    final multiplier = (intent['multiplier'] as int?) ?? 1;
    if (number == null) return 0;
    return (number as int) * multiplier;
  }

  static int _throwAppliedValue(Map<String, dynamic> item) {
    final explicit = item['appliedValue'];
    if (explicit is int) return explicit;

    if (item['value'] is int && item['type'] == 'legacy') {
      return item['value'] as int;
    }

    return _throwBaseValue(item);
  }

  static String _throwLabel(Map<String, dynamic> intent) {
    if (intent['isMiss'] == true) return 'MISS';

    final number = intent['number'];
    final multiplier = (intent['multiplier'] as int?) ?? 1;
    if (number == null) return 'MISS';

    if (number == 25) {
      if (multiplier == 2) return 'D25';
      return 'S25';
    }

    final prefix = multiplier == 3
        ? 'T'
        : multiplier == 2
        ? 'D'
        : 'S';

    return '$prefix$number';
  }

  static Map<String, dynamic>? _playerById(RoomData data, String playerId) {
    for (final p in data.players) {
      if (p['id'] == playerId) return p;
    }
    return null;
  }

  static bool _hasPlayerOpened(
      RoomData state,
      String playerId, {
        List<Map<String, dynamic>> liveThrows = const [],
      }) {
    if (state.game.doubleIn != true) return true;

    bool isOpeningThrow(Map<String, dynamic> item) {
      final label = item['label'];
      return label is String && label.startsWith('D');
    }

    // 🔑 SOLO LEG CORRENTE
    final turns = _currentLegTurns(state.match);

    for (final turn in turns) {
      if (turn['playerId'] != playerId) continue;

      final throws = _normalizeStoredThrows(turn['throws']);
      for (final item in throws) {
        if (isOpeningThrow(item)) return true;
      }
    }

    // live throws (turno in corso)
    for (final item in liveThrows) {
      if (isOpeningThrow(item)) return true;
    }

    return false;
  }
  static List<Map<String, dynamic>> _currentLegTurns(
      List<Map<String, dynamic>> match,
      ) {
    if (match.isEmpty) return const [];

    final lastSet = Map<String, dynamic>.from(match.last);
    final legs = List<Map<String, dynamic>>.from(lastSet['legs'] ?? const []);

    if (legs.isEmpty) return const [];

    final lastLeg = Map<String, dynamic>.from(legs.last);
    return List<Map<String, dynamic>>.from(lastLeg['turns'] ?? const []);
  }

  static String? _cricketTargetKey(Map<String, dynamic> intent) {
    if (intent['isMiss'] == true) return null;
    final number = intent['number'];
    if (number == null) return null;

    final value = number as int;
    if (value == 25) return '25';
    if (value >= 15 && value <= 20) return '$value';

    return null;
  }

  static int _cricketMarks(Map<String, dynamic> intent) {
    if (intent['isMiss'] == true) return 0;

    final multiplier = (intent['multiplier'] as int?) ?? 1;
    final number = intent['number'];

    if (number == 25 && multiplier == 3) {
      return 0;
    }

    if (multiplier <= 0) return 0;
    if (multiplier >= 3) return 3;
    return multiplier;
  }

  static int _cricketNumberValue(String target) {
    return int.tryParse(target) ?? 0;
  }

  static bool _allOpponentsClosedTarget(
      RoomData state,
      String playerId,
      String target,
      ) {
    final player = _playerById(state, playerId);
    if (player == null) return true;
    final playerOrder = (player['order'] ?? 0) as int;

    if (state.teamSize > 1) {
      final teamStart = (playerOrder ~/ state.teamSize) * state.teamSize;
      final teamEnd = teamStart + state.teamSize;

      for (final p in state.players) {
        final order = (p['order'] ?? 0) as int;
        final sameTeam = order >= teamStart && order < teamEnd;
        if (sameTeam) continue;

        final cricket = Map<String, dynamic>.from(p['cricket'] ?? const {});
        if ((cricket[target] as int? ?? 0) < 3) {
          return false;
        }
      }

      return true;
    }

    for (final p in state.players) {
      if (p['id'] == playerId) continue;
      final cricket = Map<String, dynamic>.from(p['cricket'] ?? const {});
      if ((cricket[target] as int? ?? 0) < 3) {
        return false;
      }
    }

    return true;
  }

  static bool _isCricketWinner(
      RoomData state,
      String playerId, {
        Map<String, dynamic>? overrideCricket,
        int? overrideScore,
      }) {
    final player = _playerById(state, playerId);
    if (player == null) return false;

    final cricket =
        overrideCricket ?? Map<String, dynamic>.from(player['cricket'] ?? const {});
    final score = overrideScore ?? (player['cricketScore'] as int?) ?? 0;

    const targets = ['20', '19', '18', '17', '16', '15', '25'];
    final allClosed = targets.every((t) => (cricket[t] as int? ?? 0) >= 3);
    if (!allClosed) return false;

    final playerOrder = (player['order'] ?? 0) as int;
    final playerTeamStart =
    state.teamSize > 1 ? (playerOrder ~/ state.teamSize) * state.teamSize : playerOrder;
    final playerTeamEnd =
    state.teamSize > 1 ? playerTeamStart + state.teamSize : playerOrder + 1;

    int bestOpponentScore = 0;

    for (final p in state.players) {
      final order = (p['order'] ?? 0) as int;
      final sameTeam = order >= playerTeamStart && order < playerTeamEnd;
      if (sameTeam) continue;

      final opponentScore = (p['cricketScore'] as int?) ?? 0;
      if (opponentScore > bestOpponentScore) {
        bestOpponentScore = opponentScore;
      }
    }

    return score >= bestOpponentScore;
  }
}