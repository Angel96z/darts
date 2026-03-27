import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/orchestrators/match_orchestrator.dart';
import '../../../application/reducers/match_reducer.dart';
import '../../../application/usecases/providers.dart';
import '../../../application/validators/command_validator.dart';
import '../../../domain/commands/match_command.dart';
import '../../../domain/engines/game_engine.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/engines/x01_engine.dart';
import '../../../domain/events/match_event.dart';
import '../../../domain/policies/team_finish_constraint.dart';
import '../../../domain/rules/x01_rules.dart';
import '../../../domain/value_objects/identifiers.dart';
import '../match_vm/match_vm.dart';

class MatchViewModel {
  const MatchViewModel({
    required this.match,
    required this.isOnline,
    required this.loading,
  });

  final Match match;
  final bool isOnline;
  final bool loading;

  MatchViewModel copyWith({
    Match? match,
    bool? isOnline,
    bool? loading,
  }) {
    return MatchViewModel(
      match: match ?? this.match,
      isOnline: isOnline ?? this.isOnline,
      loading: loading ?? this.loading,
    );
  }
}
enum MatchInputMode {
  perDart,
  perTurn,
}

enum DartMultiplierMode {
  single,
  double,
  triple,
}

extension DartMultiplierModeX on DartMultiplierMode {
  int get value {
    switch (this) {
      case DartMultiplierMode.single:
        return 1;
      case DartMultiplierMode.double:
        return 2;
      case DartMultiplierMode.triple:
        return 3;
    }
  }

  String get label {
    switch (this) {
      case DartMultiplierMode.single:
        return 'S';
      case DartMultiplierMode.double:
        return 'D';
      case DartMultiplierMode.triple:
        return 'T';
    }
  }
}
class MatchController extends StateNotifier<MatchViewModel?> {
  MatchController(this._ref) : super(null);

  final Ref _ref;
  StreamSubscription<Match>? _sub;
  MatchInputMode _inputMode = MatchInputMode.perTurn;
  DartMultiplierMode _selectedMultiplier = DartMultiplierMode.single;
  final List<DartInput> _currentTurnInputs = [];
  final Map<String, MatchInputMode> _playerInputPreferences = {};

  MatchInputMode get inputMode => _inputMode;
  DartMultiplierMode get selectedMultiplier => _selectedMultiplier;
  List<DartInput> get currentTurnInputs => List.unmodifiable(_currentTurnInputs);
  Future<bool> _checkBackendConnection() async {
    final ok = await _ref.read(backendConnectionServiceProvider).checkBackendConnection();
    final current = state;
    if (current != null) {
      state = current.copyWith(isOnline: ok);
    }
    return ok;
  }

  Future<void> bindMatch({
    required Match match,
    required bool isOnline,
  }) async {
    state = MatchViewModel(
      match: match,
      isOnline: isOnline,
      loading: false,
    );

    _sub?.cancel();

    if (!isOnline) {
      return;
    }

    _sub = _ref.read(matchRepositoryProvider).watchMatch(match.roomId, match.id).listen((updatedMatch) {
      final current = state;
      if (current == null) return;
      state = current.copyWith(match: updatedMatch);
    });
// 🔥 HARD SYNC fallback diretto Firestore
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(match.roomId.value)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      // opzionale: sync stato room → UI
    });
  }

  void setInputMode(MatchInputMode mode) {
    final current = state;
    if (current == null) return;

    final playerId =
        current.match.snapshot.scoreboard.currentTurnPlayerId.value;

    _playerInputPreferences[playerId] = mode;

    if (_inputMode == mode) return;

    _inputMode = mode;
    _selectedMultiplier = DartMultiplierMode.single;
    _currentTurnInputs.clear();
    _refreshVm();
  }

  void setSelectedMultiplier(DartMultiplierMode mode) {
    _selectedMultiplier = mode;
    _refreshVm();
  }

  void clearBufferedTurn() {
    _currentTurnInputs.clear();
    _selectedMultiplier = DartMultiplierMode.single;
    _refreshVm();
  }

  Future<void> registerDartValue(int rawValue) async {
    final current = state;
    if (current == null) return;
    if (_inputMode != MatchInputMode.perDart) return;
    if (current.match.snapshot.status == MatchStatus.completed) return;
    if (_currentTurnInputs.length >= 3) return;

    final multiplier = rawValue == 25
        ? (_selectedMultiplier == DartMultiplierMode.triple
        ? DartMultiplierMode.single
        : _selectedMultiplier)
        : _selectedMultiplier;

    final input = DartInput(
      rawValue: rawValue,
      multiplier: multiplier.value,
    );

    _currentTurnInputs.add(input);
    _selectedMultiplier = DartMultiplierMode.single;
    _refreshVm();

// invia turno se 3 frecce O se chiudi prima
    final total = _currentTurnInputs.fold<int>(
      0,
          (sum, input) => sum + (input.rawValue * input.multiplier),
    );

    if (current != null) {
      final playerId =
          current.match.snapshot.scoreboard.currentTurnPlayerId;

      final playerScore =
          current.match.snapshot.scoreboard.playerScores[playerId] ??
              current.match.config.startScore;

      final projected = playerScore - total;

      if (_currentTurnInputs.length == 3 || projected == 0) {
        await submitBufferedTurn();
      }
    }
  }

  Future<void> removeLastBufferedDart() async {
    if (_currentTurnInputs.isEmpty) return;
    _currentTurnInputs.removeLast();
    _selectedMultiplier = DartMultiplierMode.single;
    _refreshVm();
  }

  Future<void> submitBufferedTurn() async {
    if (_currentTurnInputs.isEmpty) return;

    final total = _currentTurnInputs.fold<int>(
      0,
          (sum, input) => sum + (input.rawValue * input.multiplier),
    );

    final inputs = List<DartInput>.from(_currentTurnInputs);
    await submitTurn(
      total,
      inputMode: InputMode.totalTurnInput,
      inputs: inputs,
    );
  }

  Future<void> submitBust() async {
    await submitTurn(
      0,
      inputMode: InputMode.totalTurnInput,
      inputs: const [],
      forceBustLabel: true,
    );
  }
  Future<void> submitCheckout() async {
    final current = state;
    if (current == null) return;

    final match = current.match;

    final playerId =
        match.snapshot.scoreboard.currentTurnPlayerId;

    final playerScore =
        match.snapshot.scoreboard.playerScores[playerId] ??
            match.config.startScore;

    // ⚠️ LOGICA REALE:
    // checkout = ultimo dart deve essere valido secondo OUT RULE

    DartInput lastDart;

    if (match.config.outMode == OutMode.doubleOut) {
      // deve essere un doppio
      if (playerScore % 2 != 0) {
        // impossibile chiudere → NON fare nulla
        return;
      }

      lastDart = DartInput(
        rawValue: playerScore ~/ 2,
        multiplier: 2,
      );
    } else {
      lastDart = DartInput(
        rawValue: playerScore,
        multiplier: 1,
      );
    }

    await submitTurn(
      playerScore,
      inputMode: InputMode.totalTurnInput,
      inputs: [lastDart],
    );
  }

  String formatInputLabel(DartInput input) {
    final prefix = input.multiplier == 3
        ? 'T'
        : input.multiplier == 2
        ? 'D'
        : 'S';
    return '$prefix${input.rawValue}';
  }

  void _refreshVm() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(match: current.match);
  }
  void _syncInputModeWithCurrentPlayer() {
    final current = state;
    if (current == null) return;

    final playerId =
        current.match.snapshot.scoreboard.currentTurnPlayerId.value;

    final preferred = _playerInputPreferences[playerId];
    if (preferred == null) return;

    if (_inputMode != preferred) {
      _inputMode = preferred;
      _selectedMultiplier = DartMultiplierMode.single;
      _currentTurnInputs.clear();
    }
  }



  Future<void> submitTurn(
      int points, {
        InputMode? inputMode,
        List<DartInput>? inputs,
        bool forceBustLabel = false,
      }) async {
    final current = state;
    if (current == null) return;
    if (current.match.snapshot.status == MatchStatus.completed) return;
    if (current.match.roster.players.isEmpty) return;

    final resolvedInputs = inputs ??
        [
          DartInput(rawValue: points, multiplier: 1),
        ];

    final resolvedInputMode = inputMode ?? InputMode.totalTurnInput;

    await _applyLocalTurn(
      points,
      inputs: resolvedInputs,
      inputMode: resolvedInputMode,
      forceBustLabel: forceBustLabel,
    );

    _currentTurnInputs.clear();
    _selectedMultiplier = DartMultiplierMode.single;
    _refreshVm();

    if (!current.isOnline) return;

    try {
      await _ref.read(matchRepositoryProvider).saveMatch(state!.match);
    } catch (_) {
      final latest = state;
      if (latest != null) {
        state = latest.copyWith(isOnline: false);
      }
    }
  }


  Future<void> undoLastTurn() async {
    final current = state;
    if (current == null) return;

    if (_inputMode == MatchInputMode.perDart && _currentTurnInputs.isNotEmpty) {
      _currentTurnInputs.removeLast();
      _selectedMultiplier = DartMultiplierMode.single;
      _refreshVm();
      return;
    }

    await _applyLocalUndo();

    if (current.isOnline) {
      try {
        await _ref.read(matchRepositoryProvider).saveMatch(state!.match);
      } catch (_) {
        final latest = state;
        if (latest != null) {
          state = latest.copyWith(isOnline: false);
        }
      }
    }
  }


  Future<void> _applyLocalTurn(
      int points, {
        required List<DartInput> inputs,
        required InputMode inputMode,
        bool forceBustLabel = false,
      }) async {
    final current = state;
    if (current == null) return;

    final match = current.match;
    if (match.snapshot.status == MatchStatus.completed) return;
    if (match.roster.players.isEmpty) return;

    final playerId = match.snapshot.scoreboard.currentTurnPlayerId;
    final playerScore =
        match.snapshot.scoreboard.playerScores[playerId] ?? match.config.startScore;
    final now = DateTime.now();
    final eventId = FirebaseFirestore.instance.collection('_').doc().id;

    final draft = TurnDraft(
      playerId: playerId,
      legNumber: match.snapshot.currentLeg,
      turnNumber: match.snapshot.currentTurn,
      inputs: inputs,
      inputMode: inputMode,
    );

    final resolution = _buildEngine(match.config).resolveTurn(
      match: match,
      draft: draft,
      currentPlayerScore: playerScore,
      currentTeamScore: 0,
      inActivated: true,
    );

    final payload = <String, dynamic>{
      'playerId': playerId.value,
      'previousScore': playerScore,
      'nextScore': resolution.nextScore,
      'reason': forceBustLabel ? 'manual_bust' : resolution.reason,
      'isBust': forceBustLabel ? true : resolution.isBust,
      'isCheckout': resolution.isCheckout,
      'draft': {
        'playerId': draft.playerId.value,
        'legNumber': draft.legNumber,
        'turnNumber': draft.turnNumber,
        'inputMode': draft.inputMode.name,
        'inputs': [
          for (final input in draft.inputs)
            {
              'rawValue': input.rawValue,
              'multiplier': input.multiplier,
            },
        ],
      },
    };

    final effectiveBust = forceBustLabel ? true : resolution.isBust;

    final event = resolution.isCheckout
        ? MatchWonEvent(
      eventId: EventId(eventId),
      roomId: match.roomId,
      matchId: match.id,
      createdAt: now,
      payload: payload,
    )
        : effectiveBust
        ? TurnBustEvent(
      eventId: EventId(eventId),
      roomId: match.roomId,
      matchId: match.id,
      createdAt: now,
      payload: payload,
    )
        : TurnCommittedEvent(
      eventId: EventId(eventId),
      roomId: match.roomId,
      matchId: match.id,
      createdAt: now,
      payload: payload,
    );

    final updated = const MatchReducer().apply(match, event);
    state = current.copyWith(match: updated);
  }

  Future<void> _applyLocalUndo() async {
    final current = state;
    if (current == null) return;

    final match = current.match;
    final turns = match.snapshot.lastTurns;
    if (turns.isEmpty) return;

    final lastTurn = turns.last;
    final inputs = lastTurn.draft.inputs;

    // 🔹 CASO 1: turno con più freccette → ricalcolo tutto da zero senza ultima freccetta
    if (inputs.length > 1) {
      final updatedInputs = List<DartInput>.from(inputs)..removeLast();

      final rebuiltTurns = List<TurnCommitted>.from(turns)..removeLast();

      final initialScores = {
        for (final p in match.roster.players)
          p.playerId: match.config.startScore,
      };

      final baseMatch = Match(
        id: match.id,
        roomId: match.roomId,
        config: match.config,
        roster: match.roster,
        snapshot: MatchStateSnapshot(
          matchState: MatchState.turnActive,
          status: MatchStatus.active,
          currentSet: 1,
          currentLeg: 1,
          currentTurn: 1,
          scoreboard: Scoreboard(
            playerScores: initialScores,
            teamScores: const {},
            currentTurnPlayerId: match.roster.players.first.playerId,
          ),
          lastTurns: const [],
        ),
        legs: match.legs,
        sets: match.sets,
        result: null,
        createdAt: match.createdAt,
      );

      Match rebuilt = baseMatch;

      // replay tutti i turni tranne ultimo
      for (final t in rebuiltTurns) {
        final event = TurnCommittedEvent(
          eventId: EventId('rebuild_${DateTime.now().microsecondsSinceEpoch}'),
          roomId: rebuilt.roomId,
          matchId: rebuilt.id,
          createdAt: DateTime.now(),
          payload: {
            'playerId': t.draft.playerId.value,
            'previousScore': 0,
            'nextScore': t.resolution.nextScore,
            'reason': t.resolution.reason,
            'isBust': t.resolution.isBust,
            'isCheckout': t.resolution.isCheckout,
            'draft': {
              'playerId': t.draft.playerId.value,
              'legNumber': t.draft.legNumber,
              'turnNumber': t.draft.turnNumber,
              'inputMode': t.draft.inputMode.name,
              'inputs': [
                for (final input in t.draft.inputs)
                  {
                    'rawValue': input.rawValue,
                    'multiplier': input.multiplier,
                  },
              ],
            },
          },
        );

        rebuilt = const MatchReducer().apply(rebuilt, event);
      }

      // riapplico ultimo turno SENZA ultima freccetta
      final playerId = lastTurn.draft.playerId;
      final playerScore =
          rebuilt.snapshot.scoreboard.playerScores[playerId] ?? match.config.startScore;

      final draft = TurnDraft(
        playerId: playerId,
        legNumber: lastTurn.draft.legNumber,
        turnNumber: lastTurn.draft.turnNumber,
        inputs: updatedInputs,
        inputMode: lastTurn.draft.inputMode,
      );

      final resolution = _buildEngine(match.config).resolveTurn(
        match: rebuilt,
        draft: draft,
        currentPlayerScore: playerScore,
        currentTeamScore: 0,
        inActivated: true,
      );

      final payload = {
        'playerId': playerId.value,
        'previousScore': playerScore,
        'nextScore': resolution.nextScore,
        'reason': resolution.reason,
        'isBust': resolution.isBust,
        'isCheckout': resolution.isCheckout,
        'draft': {
          'playerId': playerId.value,
          'legNumber': draft.legNumber,
          'turnNumber': draft.turnNumber,
          'inputMode': draft.inputMode.name,
          'inputs': [
            for (final input in draft.inputs)
              {
                'rawValue': input.rawValue,
                'multiplier': input.multiplier,
              },
          ],
        },
      };

      final event = resolution.isCheckout
          ? MatchWonEvent(
        eventId: EventId('rebuild_last'),
        roomId: rebuilt.roomId,
        matchId: rebuilt.id,
        createdAt: DateTime.now(),
        payload: payload,
      )
          : resolution.isBust
          ? TurnBustEvent(
        eventId: EventId('rebuild_last'),
        roomId: rebuilt.roomId,
        matchId: rebuilt.id,
        createdAt: DateTime.now(),
        payload: payload,
      )
          : TurnCommittedEvent(
        eventId: EventId('rebuild_last'),
        roomId: rebuilt.roomId,
        matchId: rebuilt.id,
        createdAt: DateTime.now(),
        payload: payload,
      );

      final finalMatch = const MatchReducer().apply(rebuilt, event);

      state = current.copyWith(match: finalMatch);
      return;
    }

    // 🔹 CASO 2: turno singolo → logica originale
    final playerId = lastTurn.draft.playerId;

    final currentScores = Map<PlayerId, int>.from(
      match.snapshot.scoreboard.playerScores,
    );

    final int restoredScore;
    if (lastTurn.resolution.isBust) {
      restoredScore = lastTurn.resolution.nextScore;
    } else {
      restoredScore = lastTurn.resolution.nextScore + lastTurn.draft.total;
    }

    currentScores[playerId] = restoredScore;

    final updatedTurns = List<TurnCommitted>.from(turns)..removeLast();

    final updatedSnapshot = MatchStateSnapshot(
      matchState: MatchState.turnActive,
      status: MatchStatus.active,
      currentSet: match.snapshot.currentSet,
      currentLeg: match.snapshot.currentLeg,
      currentTurn: match.snapshot.currentTurn > 1
          ? match.snapshot.currentTurn - 1
          : 1,
      scoreboard: Scoreboard(
        playerScores: currentScores,
        teamScores: match.snapshot.scoreboard.teamScores,
        currentTurnPlayerId: playerId,
      ),
      lastTurns: updatedTurns,
    );

    final updatedMatch = Match(
      id: match.id,
      roomId: match.roomId,
      config: match.config,
      roster: match.roster,
      snapshot: updatedSnapshot,
      legs: match.legs,
      sets: match.sets,
      result: null,
      createdAt: match.createdAt,
    );

    state = current.copyWith(match: updatedMatch);
  }

  GameEngine _buildEngine(MatchConfig config) {
    return X01Engine(
      inRule: InRule(config.inMode),
      outRule: OutRule(config.outMode),
      bustRule: const BustRule(),
      finishConstraint: _resolveFinishConstraint(config),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  TeamFinishConstraint _resolveFinishConstraint(MatchConfig config) {
    if (!config.finishConstraintEnabled || config.teamMode != TeamMode.teams) {
      return const NoTeamFinishConstraint();
    }
    return const LowestTeamTotalConstraint();
  }

  MatchVm toVm(String _) {
    _syncInputModeWithCurrentPlayer();
    final currentState = state;

    if (currentState == null) {
      return MatchVm(
        players: const [],
        currentPlayerId: '',
        isMyTurn: false,
        isInputEnabled: false,
        isMatchStarted: false,
        inputMode: MatchInputMode.perTurn,
        selectedMultiplier: DartMultiplierMode.single,
        currentTurnInputs: const [],
        bufferedTurnTotal: 0,
        displayTurnLabels: const [],
      );
    }

    final match = currentState.match;
    final current = match.snapshot.scoreboard.currentTurnPlayerId.value;

    final playerPreferred =
        _playerInputPreferences[current] ?? _inputMode;

    return MatchVm(
      players: match.roster.players.map((p) {
        final score =
            match.snapshot.scoreboard.playerScores[p.playerId] ??
                match.config.startScore;

        return PlayerVm(
          id: p.playerId.value,
          name: p.playerId.value,
          score: score,
          isCurrent: p.playerId.value == current,
        );
      }).toList(),
      currentPlayerId: current,
      isMyTurn: true,
      isInputEnabled: match.snapshot.status == MatchStatus.active,
      isMatchStarted: match.snapshot.status != MatchStatus.paused,
      inputMode: playerPreferred,
      selectedMultiplier: _selectedMultiplier,
      currentTurnInputs: List<DartInput>.unmodifiable(_currentTurnInputs),
      bufferedTurnTotal: _currentTurnInputs.fold<int>(
        0,
            (sum, input) => sum + (input.rawValue * input.multiplier),
      ),
      displayTurnLabels: _inputMode == MatchInputMode.perDart
          ? [
        for (final input in _currentTurnInputs) formatInputLabel(input),
      ]
          : [
        if (_currentTurnInputs.isNotEmpty)
          '${_currentTurnInputs.fold<int>(0, (sum, input) => sum + (input.rawValue * input.multiplier))}',
      ],
    );
  }

}

final matchControllerProvider =
StateNotifierProvider<MatchController, MatchViewModel?>((ref) => MatchController(ref));