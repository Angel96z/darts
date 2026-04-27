// TARGET: Costruttore del match - APPLICATION LAYER
// LOGIC GOAL: Gestire turni, dardi, punteggi
// REACTION: Restituisce nuovo stato dopo ogni azione
// ERROR STRATEGY: Se errore, restituisce stato invariato
// ANTI-REGRESSION: Mantenere throwDart, undoLastDart

import 'package:flutter/foundation.dart';
import '../domain/game_types/x01_rules.dart';
import '../domain/game_types/cricket_rules.dart';
import '../domain/models/player_turn.dart';
import '../domain/models/dart_throw.dart';
import '../domain/models/game_config.dart';
import '../domain/models/round.dart';
import '../domain/models/leg.dart';
import '../domain/models/set.dart';
import 'game_logic.dart';

@immutable
class MatchBuilderState {
  final List<PlayerTurn> allTurns;
  final PlayerTurn currentTurn;
  final String currentPlayerId;
  final List<String> playerIds;
  final int teamSize;
  final Map<String, int> playerScores;
  final Map<String, bool> playersOpened;
  final int currentLegNumber;
  final int currentSetNumber;
  final int currentRoundNumber;
  final Map<String, int> legsWon;
  final Map<String, int> setsWon;

  // TEAM SUPPORT
  final Map<String, int> teamScores;
  final Map<String, String> playerToTeam;
  final Map<String, int> teamLegsWon;
  final Map<String, int> teamSetsWon;

  // STRUTTURA DATI
  final List<Round> currentLegRounds;
  final List<Leg> currentSetLegs;
  final List<Set> matchSets;
  final List<PlayerTurn> currentRoundTurns;
  final int currentRoundTurnCount;

  // 🆕 CRICKET DATA - TRANSITORI (solo per il leg corrente)
  // NON vengono più salvati permanentemente qui, ma nel Leg quando finisce
  final Map<String, Map<int, int>> cricketMarks;
  final Map<String, int> cricketPoints;

  const MatchBuilderState({
    required this.allTurns,
    required this.currentTurn,
    required this.currentPlayerId,
    required this.playerIds,
    required this.teamSize,
    required this.playerScores,
    required this.playersOpened,
    required this.currentLegNumber,
    required this.currentSetNumber,
    required this.currentRoundNumber,
    required this.legsWon,
    required this.setsWon,
    required this.currentLegRounds,
    required this.currentSetLegs,
    required this.matchSets,
    required this.currentRoundTurns,
    required this.currentRoundTurnCount,
    required this.teamScores,
    required this.playerToTeam,
    required this.teamLegsWon,
    required this.teamSetsWon,
    required this.cricketMarks,
    required this.cricketPoints,
  });

  MatchBuilderState copyWith({
    List<PlayerTurn>? allTurns,
    PlayerTurn? currentTurn,
    String? currentPlayerId,
    List<String>? playerIds,
    int? teamSize,
    Map<String, int>? playerScores,
    Map<String, bool>? playersOpened,
    int? currentLegNumber,
    int? currentSetNumber,
    int? currentRoundNumber,
    Map<String, int>? legsWon,
    Map<String, int>? setsWon,
    List<Round>? currentLegRounds,
    List<Leg>? currentSetLegs,
    List<Set>? matchSets,
    List<PlayerTurn>? currentRoundTurns,
    int? currentRoundTurnCount,
    Map<String, int>? teamScores,
    Map<String, String>? playerToTeam,
    Map<String, int>? teamLegsWon,
    Map<String, int>? teamSetsWon,
    Map<String, Map<int, int>>? cricketMarks,
    Map<String, int>? cricketPoints,
  }) {
    return MatchBuilderState(
      allTurns: allTurns ?? this.allTurns,
      currentTurn: currentTurn ?? this.currentTurn,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      playerIds: playerIds ?? this.playerIds,
      teamSize: teamSize ?? this.teamSize,
      playerScores: playerScores ?? this.playerScores,
      playersOpened: playersOpened ?? this.playersOpened,
      currentLegNumber: currentLegNumber ?? this.currentLegNumber,
      currentSetNumber: currentSetNumber ?? this.currentSetNumber,
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
      currentLegRounds: currentLegRounds ?? this.currentLegRounds,
      currentSetLegs: currentSetLegs ?? this.currentSetLegs,
      matchSets: matchSets ?? this.matchSets,
      currentRoundTurns: currentRoundTurns ?? this.currentRoundTurns,
      currentRoundTurnCount: currentRoundTurnCount ?? this.currentRoundTurnCount,
      teamScores: teamScores ?? this.teamScores,
      playerToTeam: playerToTeam ?? this.playerToTeam,
      teamLegsWon: teamLegsWon ?? this.teamLegsWon,
      teamSetsWon: teamSetsWon ?? this.teamSetsWon,
      cricketMarks: cricketMarks ?? this.cricketMarks,
      cricketPoints: cricketPoints ?? this.cricketPoints,
    );
  }
}

class MatchBuilder {
  final int teamSize;
  final int startingScore;

  const MatchBuilder({
    this.teamSize = 0,
    this.startingScore = 501,
  });

  MatchBuilderState initialize(List<String> playerIds, GameConfig config) {
    if (playerIds.isEmpty) {
      throw StateError('Nessun giocatore!');
    }

    final firstPlayerId = playerIds[0];
    final isCricket = config.type == GameType.cricket;

    final Map<String, int> initialScores = {
      for (final id in playerIds) id: isCricket ? 0 : startingScore,
    };

    final Map<String, bool> initialOpened = {
      for (final id in playerIds) id: !(config.doubleIn ?? false),
    };

    final Map<String, int> initialLegsWon = {
      for (final id in playerIds) id: 0,
    };

    final Map<String, int> initialSetsWon = {
      for (final id in playerIds) id: 0,
    };

    // 🆕 CRICKET INITIALIZATION
    final Map<String, Map<int, int>> initialCricketMarks = CricketRules.initializeMarks(playerIds);
    final Map<String, int> initialCricketPoints = CricketRules.initializePoints(playerIds);

    // TEAM INITIALIZATION
    Map<String, int> teamScores = {};
    Map<String, String> playerToTeam = {};
    Map<String, int> teamLegsWon = {};
    Map<String, int> teamSetsWon = {};

    if (teamSize > 1) {
      int teamIndex = 1;
      for (int i = 0; i < playerIds.length; i += teamSize) {
        final teamId = "T$teamIndex";
        teamScores[teamId] = isCricket ? 0 : startingScore;
        teamLegsWon[teamId] = 0;
        teamSetsWon[teamId] = 0;

        for (int j = i; j < i + teamSize && j < playerIds.length; j++) {
          playerToTeam[playerIds[j]] = teamId;
        }
        teamIndex++;
      }
    }

// Nel metodo initialize(), crea firstTurn con totalMarks: 0

    final firstTurn = PlayerTurn(
      playerId: firstPlayerId,
      turnNumber: 1,
      roundNumber: 1,
      legNumber: 1,
      throws: [],
      total: 0,
      totalMarks: 0,  // 🆕
      initialScore: isCricket ? 0 : startingScore,
      score: isCricket ? 0 : startingScore,
      isBust: false,
      isCheckout: false,
      timestamp: DateTime.now(),
    );

    return MatchBuilderState(
      allTurns: [],
      currentTurn: firstTurn,
      currentPlayerId: firstPlayerId,
      playerIds: playerIds,
      teamSize: teamSize,
      playerScores: initialScores,
      playersOpened: initialOpened,
      currentLegNumber: 1,
      currentSetNumber: 1,
      currentRoundNumber: 1,
      legsWon: initialLegsWon,
      setsWon: initialSetsWon,
      currentLegRounds: [],
      currentSetLegs: [],
      matchSets: [],
      currentRoundTurns: [],
      currentRoundTurnCount: playerIds.length,
      teamScores: teamScores,
      playerToTeam: playerToTeam,
      teamLegsWon: teamLegsWon,
      teamSetsWon: teamSetsWon,
      cricketMarks: initialCricketMarks,
      cricketPoints: initialCricketPoints,
    );
  }

  // ============================================================
  // SMISTATORE - chiama le regole in base al tipo di gioco
  // ============================================================

  MatchBuilderState throwDart(MatchBuilderState state, int target, int multiplier, GameConfig config) {
    if (state.currentTurn.isComplete) return state;

    final newDart = DartThrow(
      dartNumber: state.currentTurn.throws.length + 1,
      target: target,
      multiplier: multiplier,
      score: target * multiplier,
      timestamp: DateTime.now(),
    );

    if (config.type == GameType.x01) {
      return _throwDartX01(state, newDart, config);
    } else if (config.type == GameType.cricket) {
      return _throwDartCricket(state, newDart, config);
    }

    return state;
  }

  // ============================================================
  // X01 - REGOLE SPECIFICHE
  // ============================================================

  MatchBuilderState _throwDartX01(MatchBuilderState state, DartThrow dart, GameConfig config) {
    final isTeamMode = state.teamSize > 1;
    final currentPlayerId = state.currentPlayerId;
    String? currentTeamId;
    int lowestTeamScore = 0;

    if (isTeamMode) {
      currentTeamId = state.playerToTeam[currentPlayerId];
      if (state.teamScores.isNotEmpty) {
        final opposingTeamScores = state.teamScores.entries
            .where((entry) => entry.key != currentTeamId)
            .map((entry) => entry.value);
        if (opposingTeamScores.isNotEmpty) {
          lowestTeamScore = opposingTeamScores.reduce((a, b) => a < b ? a : b);
        }
      }
    }

    // Calcola se checkout è bloccato
    final bool isCheckoutBlocked;
    if (isTeamMode && currentTeamId != null) {
      final Map<String, int> allTeamScores = Map.from(state.teamScores);
      isCheckoutBlocked = X01Rules.isCheckoutBlocked(
        allTeamScores: allTeamScores,
        currentTeamId: currentTeamId,
        currentPlayerScore: state.currentTurn.score,
      );
    } else {
      isCheckoutBlocked = false;
    }

    final (newScore, actualScore, isBust, isCheckout, didOpen) = X01Rules.calculateDart(
      currentScore: state.currentTurn.score,
      hasOpened: state.playersOpened[currentPlayerId] ?? false,
      dart: dart,
      config: config,
      isCheckoutBlocked: isCheckoutBlocked,
    );

    final finalScore;
    if (isCheckout) {
      finalScore = 0;
    } else if (isBust) {
      finalScore = state.currentTurn.initialScore;
    } else {
      finalScore = newScore;
    }

    final displayDart = dart.copyWith(score: actualScore);
    final newThrows = [...state.currentTurn.throws, displayDart];
    final newTotal = state.currentTurn.total + actualScore;

    Map<String, bool> updatedOpened = Map.from(state.playersOpened);
    if (didOpen) {
      updatedOpened[currentPlayerId] = true;
    }

    // Aggiorna punteggio team solo se NON è bust
    Map<String, int> updatedTeamScores = Map.from(state.teamScores);
    if (isTeamMode && !isBust && actualScore > 0 && currentTeamId != null) {
      final newTeamScore = (updatedTeamScores[currentTeamId] ?? 0) - actualScore;
      updatedTeamScores[currentTeamId] = newTeamScore;
    }

// In _throwDartX01, aggiungi totalMarks: 0 (X01 non usa i marks)

    final updatedTurn = PlayerTurn(
      playerId: currentPlayerId,
      turnNumber: state.currentTurn.turnNumber,
      roundNumber: state.currentTurn.roundNumber,
      legNumber: state.currentTurn.legNumber,
      throws: newThrows,
      total: newTotal,
      totalMarks: 0,  // 🆕 X01 non usa marks
      initialScore: state.currentTurn.initialScore,
      score: finalScore,
      isBust: isBust,
      isCheckout: isCheckout,
      timestamp: DateTime.now(),
    );

    if (isCheckout || isBust) {
      final updatedScores = Map<String, int>.from(state.playerScores);
      updatedScores[currentPlayerId] = finalScore;

      return state.copyWith(
        currentTurn: updatedTurn,
        playerScores: updatedScores,
        playersOpened: updatedOpened,
        teamScores: updatedTeamScores,
      );
    }

    return state.copyWith(
      currentTurn: updatedTurn,
      playersOpened: updatedOpened,
      teamScores: updatedTeamScores,
    );
  }

  // ============================================================
  // CRICKET - REGOLE SPECIFICHE
  // ============================================================

  MatchBuilderState _throwDartCricket(MatchBuilderState state, DartThrow dart, GameConfig config) {
    final currentPlayerId = state.currentPlayerId;
    final isCutThroat = config.cutThroat ?? false;

    // Costruisci i marks attuali (inclusi dardi del turno corrente)
    final currentMarks = _buildCricketMarksFromState(state);
    final currentPoints = Map<String, int>.from(state.cricketPoints);

    // Assicurati che ogni giocatore abbia un valore
    for (final playerId in state.playerIds) {
      currentPoints.putIfAbsent(playerId, () => 0);
    }

    final target = dart.target;
    final multiplier = dart.multiplier;
    final isValidTarget = CricketRules.isValidCricketNumber(target);

    // ============================================================
    // CALCOLO MARKS E PUNTI ECCEDENTI
    // ============================================================
    int excessMarks = 0;
    int newTotalMarks = 0;
    bool numberJustOpened = false;
    int totalMarksForTurn = state.currentTurn.totalMarks;
    if (isValidTarget && target != 0 && multiplier != 0) {
      totalMarksForTurn += multiplier;

      final currentMarksOnTarget = currentMarks[currentPlayerId]?[target] ?? 0;

      if (currentMarksOnTarget < 3) {
        // Calcola il nuovo totale marks (max 3)
        final wouldBe = currentMarksOnTarget + multiplier;
        newTotalMarks = wouldBe.clamp(0, 3);

        // Calcola marks eccedenti: se supera 3, l'eccesso diventa punti
        if (wouldBe > 3) {
          excessMarks = wouldBe - 3;
        }

        numberJustOpened = newTotalMarks >= 3 && currentMarksOnTarget < 3;
      } else {
        // Settore già chiuso dal giocatore: TUTTI i marks sono eccedenti
        excessMarks = multiplier;
        newTotalMarks = 3; // Resta 3
        numberJustOpened = false;
      }
    }

    // Verifica se l'avversario ha già chiuso questo numero
    final opponentHasClosed = _isNumberClosedByOpponent(
        currentMarks,
        target,
        currentPlayerId
    );

    // Verifica se il giocatore ha aperto il numero (dopo questo dardo)
    final playerHasNumber = numberJustOpened ||
        ((currentMarks[currentPlayerId]?[target] ?? 0) >= 3);

    // ============================================================
    // CALCOLO PUNTI (SOLO MARKS ECCEDENTI)
    // ============================================================
    int pointsScored = 0;
    int actualScore = 0;

    // Solo se:
    // 1. Il giocatore ha aperto il numero (3+ marks totali)
    // 2. L'avversario NON ha chiuso il numero
    // 3. Ci sono marks eccedenti
    if (isValidTarget && target != 0 && multiplier != 0 && playerHasNumber && !opponentHasClosed && excessMarks > 0) {
      final pointsValue = CricketRules.getNumberValue(target);
      pointsScored = pointsValue * excessMarks;

      if (isCutThroat) {
        // Cut Throat: i punti vanno agli avversari
        actualScore = 0;
      } else {
        // Standard Cricket: i punti vanno al giocatore corrente
        actualScore = pointsScored;
      }
    }

    // ============================================================
    // AGGIORNA PUNTEGGI
    // ============================================================
    final updatedCricketPoints = Map<String, int>.from(currentPoints);

    if (!isCutThroat) {
      // Standard: aggiungi punti al giocatore corrente
      updatedCricketPoints[currentPlayerId] = (updatedCricketPoints[currentPlayerId] ?? 0) + actualScore;
    } else {
      // Cut Throat: distribuisci punti a TUTTI gli avversari che NON hanno chiuso il numero
      if (playerHasNumber && !opponentHasClosed && pointsScored > 0) {
        for (final playerId in state.playerIds) {
          if (playerId == currentPlayerId) continue;

          final opponentMarks = currentMarks[playerId]?[target] ?? 0;
          // Solo gli avversari che NON hanno chiuso il numero ricevono punti
          if (opponentMarks < 3) {
            updatedCricketPoints[playerId] = (updatedCricketPoints[playerId] ?? 0) + pointsScored;
          }
        }
      }
      // Il giocatore corrente non prende punti in Cut Throat
      updatedCricketPoints[currentPlayerId] = updatedCricketPoints[currentPlayerId] ?? 0;
    }

    // ============================================================
    // AGGIORNA MARKS
    // ============================================================
    final updatedMarks = _updateCricketMarksWithExcess(
      state,
      currentPlayerId,
      target,
      multiplier,
      newTotalMarks,
    );

    // ============================================================
    // VERIFICA VITTORIA
    // ============================================================
    final isCheckout = _checkCricketVictory(
      updatedMarks,
      updatedCricketPoints,
      currentPlayerId,
      isCutThroat,
    );

    // ============================================================
    // AGGIORNA TURNO
    // ============================================================
    final newThrows = [...state.currentTurn.throws, dart];
    final newTotal = state.currentTurn.total + actualScore;
    final newPlayerScore = updatedCricketPoints[currentPlayerId] ?? 0;

    final updatedTurn = PlayerTurn(
      playerId: currentPlayerId,
      turnNumber: state.currentTurn.turnNumber,
      roundNumber: state.currentTurn.roundNumber,
      legNumber: state.currentTurn.legNumber,
      throws: newThrows,
      total: 0,  // 🆕 Cricket non usa total per i punti (usa cricketPoints)
      totalMarks: totalMarksForTurn,  // 🆕 somma dei moltiplicatori
      initialScore: state.currentTurn.initialScore,
      score: newPlayerScore,
      isBust: false,
      isCheckout: isCheckout,
      timestamp: DateTime.now(),
    );

    // ============================================================
    // GESTIONE VITTORIA
    // ============================================================
    if (isCheckout) {
      return state.copyWith(
        currentTurn: updatedTurn,
        cricketMarks: updatedMarks,
        cricketPoints: updatedCricketPoints,
        playerScores: updatedCricketPoints,
      );
    }

    return state.copyWith(
      currentTurn: updatedTurn,
      cricketMarks: updatedMarks,
      cricketPoints: updatedCricketPoints,
      playerScores: updatedCricketPoints,
    );
  }

// Helper aggiornato per gestire correttamente i marks (max 3)
  Map<String, Map<int, int>> _updateCricketMarksWithExcess(
      MatchBuilderState state,
      String playerId,
      int target,
      int multiplier,
      int newTotalMarks,
      ) {
    // Costruisci la mappa base dai turni completati
    final updatedMarks = _buildCricketMarksFromState(state);

    // Applica i nuovi marks solo se il target è valido
    if (CricketRules.isValidCricketNumber(target) && target != 0 && multiplier != 0) {
      final currentForPlayer = updatedMarks[playerId] ?? {};
      final currentOnTarget = currentForPlayer[target] ?? 0;

      // Se non era già a 3, aggiorna al nuovo totale (max 3)
      if (currentOnTarget < 3) {
        updatedMarks[playerId]?[target] = newTotalMarks.clamp(0, 3);
      }
      // Se era già a 3, rimane 3 (non si può superare)
    }

    return updatedMarks;
  }


// Helper per verificare se un numero è chiuso da tutti gli avversari
  bool _isNumberClosedByOpponent(
      Map<String, Map<int, int>> allMarks,
      int target,
      String currentPlayerId,
      ) {
    for (final entry in allMarks.entries) {
      if (entry.key == currentPlayerId) continue;
      final playerMarks = entry.value[target] ?? 0;
      if (playerMarks < 3) return false; // Almeno un avversario non ha chiuso
    }
    return true;
  }

// Helper per verificare la vittoria in Cricket
  bool _checkCricketVictory(
      Map<String, Map<int, int>> allMarks,
      Map<String, int> allPoints,
      String playerId,
      bool isCutThroat,
      ) {
    final myMarks = allMarks[playerId] ?? {};

    // 1. Verifica se TUTTI i numeri sono chiusi (3+ marks)
    for (final number in CricketRules.cricketNumbers) {
      if ((myMarks[number] ?? 0) < 3) return false;
    }

    // 2. Tutti i numeri chiusi - verifica punteggio
    final myPoints = allPoints[playerId] ?? 0;

    for (final entry in allPoints.entries) {
      if (entry.key == playerId) continue;

      if (isCutThroat) {
        // Cut Throat: vince chi ha MENO punti
        if (entry.value <= myPoints) return false;
      } else {
        // Standard: vince chi ha PIÙ punti
        if (entry.value >= myPoints) return false;
      }
    }

    return true;
  }

// Helper aggiornato per aggiornare i marks con i nuovi conteggi
  Map<String, Map<int, int>> _updateCricketMarksWithCounts(
      MatchBuilderState state,
      String playerId,
      int target,
      int multiplier,
      int marksAdded,
      int newMarksCount,
      ) {
    // Costruisci la mappa base dai turni completati
    final updatedMarks = _buildCricketMarksFromState(state);

    // Applica i nuovi marks solo se il target è valido
    if (CricketRules.isValidCricketNumber(target) && target != 0 && multiplier != 0 && marksAdded > 0) {
      final currentForPlayer = updatedMarks[playerId] ?? {};
      final currentOnTarget = currentForPlayer[target] ?? 0;

      // Non superare mai 3
      if (currentOnTarget < 3) {
        updatedMarks[playerId]?[target] = newMarksCount;
      }
    }

    return updatedMarks;
  }

  /// Helper per costruire la mappa dei marks dallo stato
  /// Helper per costruire la mappa dei marks dallo stato
  /// Helper per costruire la mappa dei marks dallo stato
  /// I marks non possono mai superare 3 (il 4°+ è punti, non mark)
// In match_builder.dart, sostituisci _buildCricketMarksFromState con:

  /// Helper per costruire la mappa dei marks dallo stato
  /// I marks non possono mai superare 3 (il 4°+ è punti, non mark)
  /// 🔥 ORA FILTRA SOLO PER IL LEG CORRENTE
  Map<String, Map<int, int>> _buildCricketMarksFromState(MatchBuilderState state) {
    final result = <String, Map<int, int>>{};

    // Inizializza per tutti i giocatori
    for (final playerId in state.playerIds) {
      result[playerId] = {
        20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0,
      };
    }

    // ✅ FIX: Aggrega i marks SOLO dai turni del LEG CORRENTE
    final currentLegNumber = state.currentLegNumber;

    for (final turn in state.allTurns) {
      // 🔥 SALTA i turni dei leg precedenti!
      if (turn.legNumber != currentLegNumber) continue;

      final playerMarks = result[turn.playerId]!;
      for (final dart in turn.throws) {
        final target = dart.target;
        if (CricketRules.isValidCricketNumber(target)) {
          final multiplier = dart.multiplier;
          final current = playerMarks[target] ?? 0;
          if (current < 3) {
            final wouldBe = current + multiplier;
            playerMarks[target] = wouldBe.clamp(0, 3);
          }
        }
      }
    }

    // Aggiungi anche i dardi del turno corrente (SEMPRE nello stesso leg)
    for (final dart in state.currentTurn.throws) {
      final target = dart.target;
      if (CricketRules.isValidCricketNumber(target)) {
        final multiplier = dart.multiplier;
        final current = result[state.currentPlayerId]?[target] ?? 0;
        if (current < 3) {
          final wouldBe = current + multiplier;
          result[state.currentPlayerId]?[target] = wouldBe.clamp(0, 3);
        }
      }
    }

    return result;
  }


  // ============================================================
  // COMPLETA TURNO
  // ============================================================

  MatchBuilderState completeTurn(MatchBuilderState state, PlayerTurn completedTurn) {
    final updatedScores = Map<String, int>.from(state.playerScores);
    updatedScores[state.currentPlayerId] = completedTurn.score;

    final nextPlayerId = getNextPlayer(
      state.currentPlayerId,
      state.playerIds,
      state.teamSize,
    );

    if (nextPlayerId == null) return state;

    final nextPlayerScore = updatedScores[nextPlayerId] ?? startingScore;
    final nextTurnNumber = getNextTurnNumber(state.allTurns);

    final newTurn = PlayerTurn(
      playerId: nextPlayerId,
      turnNumber: nextTurnNumber,
      roundNumber: state.currentRoundNumber,
      legNumber: state.currentLegNumber,
      throws: [],
      total: 0,
      totalMarks: 0,  // 🆕
      initialScore: nextPlayerScore,
      score: nextPlayerScore,
      isBust: false,
      isCheckout: false,
      timestamp: DateTime.now(),
    );

    return MatchBuilderState(
      allTurns: [...state.allTurns, completedTurn],
      currentTurn: newTurn,
      currentPlayerId: nextPlayerId,
      playerIds: state.playerIds,
      teamSize: state.teamSize,
      playerScores: updatedScores,
      playersOpened: state.playersOpened,
      currentLegNumber: state.currentLegNumber,
      currentSetNumber: state.currentSetNumber,
      currentRoundNumber: state.currentRoundNumber,
      legsWon: state.legsWon,
      setsWon: state.setsWon,
      currentLegRounds: state.currentLegRounds,
      currentSetLegs: state.currentSetLegs,
      matchSets: state.matchSets,
      currentRoundTurns: state.currentRoundTurns,
      currentRoundTurnCount: state.currentRoundTurnCount,
      teamScores: state.teamScores,
      playerToTeam: state.playerToTeam,
      teamLegsWon: state.teamLegsWon,
      teamSetsWon: state.teamSetsWon,
      cricketMarks: state.cricketMarks,
      cricketPoints: state.cricketPoints,
    );
  }

  // ============================================================
  // UNDO
  // ============================================================

  MatchBuilderState undoLastDart(MatchBuilderState state, GameConfig config) {
    if (state.currentTurn.throws.isEmpty) return state;

    final newThrows = List<DartThrow>.from(state.currentTurn.throws)..removeLast();
    final newTotal = newThrows.fold(0, (sum, d) => sum + d.score);
    final newScore = state.currentTurn.initialScore - newTotal;

    final hasOpened = _recalculateOpenedState(newThrows, config);

    final updatedOpened = Map<String, bool>.from(state.playersOpened);
    updatedOpened[state.currentPlayerId] = hasOpened;

    final updatedTurn = PlayerTurn(
      playerId: state.currentTurn.playerId,
      turnNumber: state.currentTurn.turnNumber,
      roundNumber: state.currentTurn.roundNumber,
      legNumber: state.currentTurn.legNumber,
      throws: newThrows,
      total: newTotal,
      totalMarks: state.currentTurn.totalMarks,  // 🆕 mantieni invariato
      initialScore: state.currentTurn.initialScore,
      score: newScore,
      isBust: false,
      isCheckout: false,
      timestamp: DateTime.now(),
    );

    return state.copyWith(
      currentTurn: updatedTurn,
      playersOpened: updatedOpened,
    );
  }

  bool _recalculateOpenedState(List<DartThrow> throws, GameConfig config) {
    final doubleIn = config.doubleIn ?? false;
    if (!doubleIn) return true;

    for (final dart in throws) {
      if (dart.multiplier == 2) return true;
    }
    return false;
  }
}