/// File: match.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'package:equatable/equatable.dart';

import '../policies/input_fidelity_policy.dart';
import '../value_objects/identifiers.dart';
import 'identity.dart';

enum MatchState {
  created,
  legStarting,
  turnActive,
  turnPendingCommit,
  legFinished,
  setFinished,
  matchFinished,
  aborted,
}

enum GameType { x01 }
enum X01Variant { x101, x180, x301, x501, x701, x1001 }
enum InMode { straightIn, doubleIn }
enum OutMode { singleOut, doubleOut, masterOut }
enum MatchMode { legsOnly, setsAndLegs }
enum MatchTargetType { firstTo, bestOf }
enum TeamMode { solo, freeForAll, teams }
enum MatchStatus { active, paused, completed }
enum InputMode { perDartPad, totalTurnInput }

class MatchConfig extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MatchConfig({
    required this.gameType,
    required this.variant,
    required this.inMode,
    required this.outMode,
    required this.matchMode,
    required this.legsTargetType,
    required this.legsTargetValue,
    required this.setsTargetType,
    required this.setsTargetValue,
    required this.teamMode,
    required this.teamSharedScore,
    required this.finishConstraintEnabled,
    required this.undoRequiresHost,
    required this.inputSnapshot,
  });

  final GameType gameType;
  final X01Variant variant;
  final InMode inMode;
  final OutMode outMode;
  final MatchMode matchMode;
  final MatchTargetType legsTargetType;
  final int legsTargetValue;
  final MatchTargetType? setsTargetType;
  final int? setsTargetValue;
  final TeamMode teamMode;
  final bool teamSharedScore;
  final bool finishConstraintEnabled;
  final bool undoRequiresHost;
  final Map<PlayerId, InputModeSnapshot> inputSnapshot;

  int get startScore => switch (variant) {
        X01Variant.x101 => 101,
        X01Variant.x180 => 180,
        X01Variant.x301 => 301,
        X01Variant.x501 => 501,
        X01Variant.x701 => 701,
        X01Variant.x1001 => 1001,
      };

  @override
  List<Object?> get props => [
        gameType,
        variant,
        inMode,
        outMode,
        matchMode,
        legsTargetType,
        legsTargetValue,
        setsTargetType,
        setsTargetValue,
        teamMode,
        teamSharedScore,
        finishConstraintEnabled,
        undoRequiresHost,
        inputSnapshot,
      ];
}

class MatchRoster extends Equatable {
  const MatchRoster({required this.players, required this.teams});

  final List<PlayerSlot> players;
  final List<Team> teams;

  @override
  List<Object?> get props => [players, teams];
}

class LegState extends Equatable {
  const LegState({required this.legNumber, required this.winnerPlayerId, required this.winnerTeamId});

  final int legNumber;
  final PlayerId? winnerPlayerId;
  final TeamId? winnerTeamId;

  @override
  List<Object?> get props => [legNumber, winnerPlayerId, winnerTeamId];
}

class SetState extends Equatable {
  const SetState({required this.setNumber, required this.winnerPlayerId, required this.winnerTeamId});

  final int setNumber;
  final PlayerId? winnerPlayerId;
  final TeamId? winnerTeamId;

  @override
  List<Object?> get props => [setNumber, winnerPlayerId, winnerTeamId];
}

class DartInput extends Equatable {
  const DartInput({required this.rawValue, required this.multiplier});

  final int rawValue;
  final int multiplier;

  int get score => rawValue * multiplier;
  bool get isDouble => multiplier == 2;
  bool get isTreble => multiplier == 3;

  @override
  List<Object?> get props => [rawValue, multiplier];
}

class TurnDraft extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TurnDraft({
    required this.playerId,
    required this.legNumber,
    required this.turnNumber,
    required this.inputs,
    required this.inputMode,
  });

  final PlayerId playerId;
  final int legNumber;
  final int turnNumber;
  final List<DartInput> inputs;
  final InputMode inputMode;

  int get total => inputs.fold(0, (prev, dart) => prev + dart.score);

  @override
  List<Object?> get props => [playerId, legNumber, turnNumber, inputs, inputMode];
}

class TurnResolution extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TurnResolution({
    required this.isBust,
    required this.isCheckout,
    required this.nextScore,
    required this.reason,
  });

  final bool isBust;
  final bool isCheckout;
  final int nextScore;
  final String reason;

  @override
  List<Object?> get props => [isBust, isCheckout, nextScore, reason];
}

class TurnCommitted extends Equatable {
  const TurnCommitted({required this.turnId, required this.draft, required this.resolution, required this.committedAt});

  final String turnId;
  final TurnDraft draft;
  final TurnResolution resolution;
  final DateTime committedAt;

  @override
  List<Object?> get props => [turnId, draft, resolution, committedAt];
}

class Scoreboard extends Equatable {
  const Scoreboard({required this.playerScores, required this.teamScores, required this.currentTurnPlayerId});

  final Map<PlayerId, int> playerScores;
  final Map<TeamId, int> teamScores;
  final PlayerId currentTurnPlayerId;

  @override
  List<Object?> get props => [playerScores, teamScores, currentTurnPlayerId];
}

class MatchStateSnapshot extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MatchStateSnapshot({
    required this.matchState,
    required this.status,
    required this.currentSet,
    required this.currentLeg,
    required this.currentTurn,
    required this.scoreboard,
    required this.lastTurns,
  });

  final MatchState matchState;
  final MatchStatus status;
  final int currentSet;
  final int currentLeg;
  final int currentTurn;
  final Scoreboard scoreboard;
  final List<TurnCommitted> lastTurns;

  @override
  List<Object?> get props => [matchState, status, currentSet, currentLeg, currentTurn, scoreboard, lastTurns];
}

class PlayerMatchStats extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const PlayerMatchStats({
    required this.playerId,
    required this.average,
    required this.highestCheckout,
    required this.maxTurn,
    required this.inputFidelity,
  });

  final PlayerId playerId;
  final double average;
  final int highestCheckout;
  final int maxTurn;
  final StatsFidelity inputFidelity;

  @override
  List<Object?> get props => [playerId, average, highestCheckout, maxTurn, inputFidelity];
}

class TeamMatchStats extends Equatable {
  const TeamMatchStats({required this.teamId, required this.average});

  final TeamId teamId;
  final double average;

  @override
  List<Object?> get props => [teamId, average];
}

class MatchResult extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MatchResult({
    required this.winnerPlayerId,
    required this.winnerTeamId,
    required this.ranking,
    required this.playerStats,
    required this.teamStats,
    required this.mvpPlayerId,
    required this.highestScore,
  });

  final PlayerId? winnerPlayerId;
  final TeamId? winnerTeamId;
  final List<PlayerId> ranking;
  final List<PlayerMatchStats> playerStats;
  final List<TeamMatchStats> teamStats;
  final PlayerId? mvpPlayerId;
  final int highestScore;

  @override
  List<Object?> get props => [winnerPlayerId, winnerTeamId, ranking, playerStats, teamStats, mvpPlayerId, highestScore];
}

class Match extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const Match({
    required this.id,
    required this.roomId,
    required this.config,
    required this.roster,
    required this.snapshot,
    required this.legs,
    required this.sets,
    required this.result,
    required this.createdAt,
  });

  final MatchId id;
  final RoomId roomId;
  final MatchConfig config;
  final MatchRoster roster;
  final MatchStateSnapshot snapshot;
  final List<LegState> legs;
  final List<SetState> sets;
  final MatchResult? result;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, roomId, config, roster, snapshot, legs, sets, result, createdAt];
}
