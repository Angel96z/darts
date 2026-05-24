// TARGET: StateNotifier per Room - CONFORME ALL'ARCHITETTURA
// LOGIC GOAL: Gestire lobby e match builder con AppStatus
// REACTION: UI reagisce ai cambiamenti
// ERROR STRATEGY: Stato error con messaggio
// ANTI-REGRESSION: Mantenere timer di passaggio turno (3.5 secondi)

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../match_sync/data/services/local_match_sync_service.dart';
import '../../match_sync/domain/entities/local_match_record.dart';
import '../bot/bot_controller.dart';
import '../bot/bot_level.dart';
import '../domain/game_types/cricket_rules.dart';
import '../domain/models/dart_throw.dart';
import '../domain/models/game_config.dart';
import '../domain/models/leg.dart';
import '../domain/models/player_info.dart';
import '../domain/models/player_turn.dart';
import '../domain/models/game_state.dart';
import '../domain/models/match.dart';
import '../domain/models/round.dart';
import '../domain/rules/base_rules.dart';
import '../presentation/match_result/domain/match_result_state.dart';
import 'match_builder.dart';
import 'game_logic.dart';
import '../domain/models/set.dart';


enum AppStatus { initial, loading, success, error }

@immutable
class RoomState {
  final AppStatus status;
  final String? errorMessage;
  final GameConfig gameConfig;
  final MatchConfig matchConfig;
  final List<PlayerInfo> players;
  final int teamSize;
  final MatchBuilderState? builderState;
  final Match? completedMatch;
  final String? matchWinnerId;
  final bool matchFinished;
  final MatchResultState? matchResult;
  final LocalMatchSyncStatus? matchSaveStatus;
  final DateTime? matchStartTime;
  // 🆕 GameState derivato dal builderState (per UI)
  final GameState? gameState;
  // stato del timer di passaggio turno
  final bool isWaitingForTurnPass;
  final double turnPassProgress;

  const RoomState({
    this.status = AppStatus.initial,
    this.errorMessage,
    required this.gameConfig,
    required this.matchConfig,
    required this.players,
    required this.teamSize,
    this.builderState,
    this.gameState,
    this.isWaitingForTurnPass = false,
    this.turnPassProgress = 0.0,
    this.completedMatch,
    this.matchWinnerId,
    this.matchFinished = false,
    this.matchResult,
    this.matchSaveStatus,
    this.matchStartTime,
  });

  List<String> get playerIds => players.map((p) => p.id).toList();

  bool get canStartMatch {
    if (players.isEmpty) return false;
    if (teamSize > 1) {
      final realPlayers = players.where((p) => !p.id.startsWith('bot_')).length;
      final totalPlayers = players.length;
      if (totalPlayers < teamSize * 2) return false;
      if (totalPlayers % teamSize != 0) return false;
      if (realPlayers == 0) return false;
    }
    return true;
  }

  RoomState copyWith({
    AppStatus? status,
    String? errorMessage,
    GameConfig? gameConfig,
    MatchConfig? matchConfig,
    List<PlayerInfo>? players,
    int? teamSize,
    MatchBuilderState? builderState,
    GameState? gameState,
    bool? isWaitingForTurnPass,
    double? turnPassProgress,
    Match? completedMatch,
    String? matchWinnerId,
    bool? showResultOverlay,
    bool? matchFinished,
    MatchResultState? matchResult,
    LocalMatchSyncStatus? matchSaveStatus,
    DateTime? matchStartTime,
  }) {
    return RoomState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      gameConfig: gameConfig ?? this.gameConfig,
      matchConfig: matchConfig ?? this.matchConfig,
      players: players ?? this.players,
      teamSize: teamSize ?? this.teamSize,
      builderState: builderState ?? this.builderState,
      gameState: gameState ?? this.gameState,
      isWaitingForTurnPass: isWaitingForTurnPass ?? this.isWaitingForTurnPass,
      turnPassProgress: turnPassProgress ?? this.turnPassProgress,
      completedMatch: completedMatch ?? this.completedMatch,
      matchWinnerId: matchWinnerId ?? this.matchWinnerId,
      matchFinished: matchFinished ?? this.matchFinished,
      matchResult: matchResult ?? this.matchResult,
      matchSaveStatus: matchSaveStatus ?? this.matchSaveStatus,
      matchStartTime: matchStartTime ?? this.matchStartTime,
    );
  }
}

class RoomNotifier extends StateNotifier<RoomState> {
  Timer? _turnPassTimer;
  Timer? _turnPassProgressTimer;
  List<MatchBuilderState> _history = [];
  static const int _maxHistorySize = 30;
  late final BotController _botController;

  void _saveToHistory() {
    if (state.builderState != null) {
      _history.add(state.builderState!);
      if (_history.length > _maxHistorySize) {
        _history.removeAt(0);
      }
    }
  }

  void undoLastAction() {
    if (_history.isEmpty) return;

    final previousState = _history.removeLast();

    state = state.copyWith(
      builderState: previousState,
      gameState: _convertToGameState(previousState),
      status: AppStatus.success,
      isWaitingForTurnPass: false,
      turnPassProgress: 0.0,
    );

    _cancelTurnPassTimer();
  }

  static const Duration turnPassDuration = Duration(milliseconds: 3000); //tempo passaggio turno
  static const Duration progressInterval = Duration(milliseconds: 50);

  RoomNotifier()
      : super(RoomState(
    gameConfig: GameConfig.x01(),
    matchConfig: const MatchConfig(mode: MatchMode.firstTo, setCount: 1, legCount: 2),
    players: [],
    teamSize: 0,
  )) {
    _botController = BotController(this);
    _createEmptyState();
  }

  // ============================================================
  // UTILITY: Converte MatchBuilderState in GameState
  // ============================================================

  GameState? _convertToGameState(MatchBuilderState? builderState) {
    if (builderState == null) return null;
    print("🔍 [ROUND] _convertToGameState - builderState.currentRoundNumber = ${builderState.currentRoundNumber}");

    final match = Match(
      id: 'match_${DateTime.now().millisecondsSinceEpoch}',
      sets: builderState.matchSets,
      winnerId: null,
      startTime: DateTime.now(),
      endTime: null,
    );

    final Map<String, List<PlayerTurn>> playerTurnsHistory = {};
    for (final turn in builderState.allTurns) {
      playerTurnsHistory.putIfAbsent(turn.playerId, () => []).add(turn);
    }

    return GameState(
      match: match,
      gameConfig: state.gameConfig,
      matchConfig: state.matchConfig,
      allTurns: builderState.allTurns,
      currentTurn: builderState.currentTurn,
      currentPlayerId: builderState.currentPlayerId,
      playerScores: builderState.playerScores,
      playerTurnsHistory: playerTurnsHistory,
      playersOpened: builderState.playersOpened,
      players: state.players,
      currentRoundNumber: builderState.currentRoundNumber,
      legsWon: builderState.legsWon,
      setsWon: builderState.setsWon,
      // 🆕 AGGIUNGI QUESTI 5 PARAMETRI:
      teamScores: builderState.teamScores,
      playerToTeam: builderState.playerToTeam,
      teamLegsWon: builderState.teamLegsWon,
      teamSetsWon: builderState.teamSetsWon,
      teamSize: builderState.teamSize,
      cricketMarks: builderState.cricketMarks,  // ← AGGIUNGI
      cricketPoints: builderState.cricketPoints,  // ← AGGIUNGI

    );
  }

  // ============================================================
  // TIMER DI PASSAGGIO TURNO
  // ============================================================

  void _startTurnPassTimer() {
    _cancelTurnPassTimer();

    state = state.copyWith(
      isWaitingForTurnPass: true,
      turnPassProgress: 0.0,
    );

    final startTime = DateTime.now();
    _turnPassProgressTimer = Timer.periodic(progressInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startTime);
      final progress = (elapsed.inMilliseconds / turnPassDuration.inMilliseconds).clamp(0.0, 1.0);

      state = state.copyWith(turnPassProgress: progress);

      if (progress >= 1.0) {
        timer.cancel();
        _turnPassProgressTimer = null;
      }
    });

    _turnPassTimer = Timer(turnPassDuration, () {
      _executeTurnPass();
    });
  }

  void _cancelTurnPassTimer() {
    _turnPassTimer?.cancel();
    _turnPassTimer = null;
    _turnPassProgressTimer?.cancel();
    _turnPassProgressTimer = null;

    state = state.copyWith(
      isWaitingForTurnPass: false,
      turnPassProgress: 0.0,
    );
  }

  // ============================================================
  // MATCH OPERATIONS
  // ============================================================

  void throwDart(int target, int multiplier) {
    final builderState = state.builderState;
    if (builderState == null) return;

    if (state.isWaitingForTurnPass) {
      _cancelTurnPassTimer();
    }

    // 🔥 SALVA LO STATO PRIMA DI MODIFICARE
    _saveToHistory();

    state = state.copyWith(status: AppStatus.loading);

    try {
      final builder = MatchBuilder(
        teamSize: state.teamSize,
        startingScore: state.gameConfig.startingScore ?? 501,
      );
      final newBuilderState = builder.throwDart(builderState, target, multiplier, state.gameConfig);
      print("🔍 [ROUND] DOPO throwDart - newBuilderState.currentRoundNumber = ${newBuilderState.currentRoundNumber}");

      state = state.copyWith(
        builderState: newBuilderState,
        gameState: _convertToGameState(newBuilderState),
        status: AppStatus.success,
        errorMessage: null,
      );
      print("🔍 [ROUND] STATO FINALE - state.gameState.currentRoundNumber = ${state.gameState?.currentRoundNumber}");

      // 🔥 Attiva bot subito dopo un dardo (se necessario)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentGameState = state.gameState;
        if (currentGameState != null && currentGameState.currentPlayerId.startsWith('bot_')) {
          print('🤖 [ROOM] Dopo throwDart - attivo bot per: ${currentGameState.currentPlayerId}');
          _botController.startBotIfNeeded(currentGameState);
        }
      });

      _checkAndStartTurnPassTimer();
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Errore lancio dardo: $e',
      );
    }
  }

  void undoLastThrow() {
    final builderState = state.builderState;
    if (builderState == null) return;

    if (state.isWaitingForTurnPass) {
      _cancelTurnPassTimer();
    }

    // 🔥 SE IL TURNO CORRENTE HA DARDI, USA L'HISTORY
    // SE NON HA DARDI, FA COMUNQUE UNDO DELL'ULTIMA AZIONE
    undoLastAction();
  }



  void _checkAndStartTurnPassTimer() {
    final builderState = state.builderState;
    if (builderState == null) return;

    final currentTurn = builderState.currentTurn;

    if (currentTurn.isComplete && !state.isWaitingForTurnPass) {
      _startTurnPassTimer();
    }
  }

  void _executeTurnPass() {
    print("⏰ TIMER SCADUTO - Eseguo passaggio turno");
    final builderState = state.builderState;
    if (builderState == null) return;

    final currentTurn = builderState.currentTurn;

    if (!currentTurn.isComplete) {
      _cancelTurnPassTimer();
      return;
    }

    _commitCurrentTurnAndAdvance();
  }

  void _commitCurrentTurnAndAdvance() {
    final builderState = state.builderState;
    if (builderState == null) return;

    final currentTurn = builderState.currentTurn;
    if (!currentTurn.isComplete) return;

    // 🔍 PRINT 1 - STATO INIZIALE
    print("🔍 [ROUND] === INIZIO commit ===");
    print("   currentRoundNumber (iniziale): ${builderState.currentRoundNumber}");
    print("   currentRoundTurns.length: ${builderState.currentRoundTurns.length}");
    print("   currentRoundTurnCount: ${builderState.currentRoundTurnCount}");
    print("   currentLegNumber: ${builderState.currentLegNumber}");
    print("   currentTurn.isCheckout: ${currentTurn.isCheckout}");
    print("   currentTurn.playerId: ${currentTurn.playerId}");

    // 1. AGGIUNGI il turno corrente ai completati
    final updatedAllTurns = [...builderState.allTurns, currentTurn];
    print("📊 ALL TURNS SAVED - total turns: ${updatedAllTurns.length}");
    for (var t in updatedAllTurns) {
      print("   Turn ${t.turnNumber} - player: ${t.playerId}, score: ${t.total} pts, checkout: ${t.isCheckout}");
    }

    // 2. AGGIUNGI il turno al round corrente
    final updatedRoundTurns = [...builderState.currentRoundTurns, currentTurn];

    // 3. Calcola se il round è completo
    final bool roundComplete = updatedRoundTurns.length >= builderState.currentRoundTurnCount;

    // 4. Variabili per struttura dati
    List<Round> updatedLegRounds = List.from(builderState.currentLegRounds);
    List<Leg> updatedSetLegs = List.from(builderState.currentSetLegs);
    List<Set> updatedMatchSets = List.from(builderState.matchSets);
    List<PlayerTurn> nextRoundTurns = [];
    int newCurrentLegNumber = builderState.currentLegNumber;
    int newCurrentSetNumber = builderState.currentSetNumber;
    int newCurrentRoundNumber = builderState.currentRoundNumber;

    // 5. Se round completo, crea Round e aggiungilo al leg
    if (roundComplete) {
      print("🔍 [ROUND] ✅ ROUND COMPLETO!");
      print("   currentLegRounds.length (prima): ${builderState.currentLegRounds.length}");

      final round = Round(
        roundNumber: builderState.currentLegRounds.length + 1,
        turns: updatedRoundTurns,
        timestamp: DateTime.now(),
      );

      print("   round creato con numero: ${round.roundNumber}");

      updatedLegRounds = [...builderState.currentLegRounds, round];
      nextRoundTurns = [];
      newCurrentRoundNumber = builderState.currentRoundNumber + 1;
      print("   newCurrentRoundNumber = ${builderState.currentRoundNumber} + 1 = $newCurrentRoundNumber");

    } else {
      nextRoundTurns = updatedRoundTurns;
      newCurrentRoundNumber = builderState.currentRoundNumber;
      print("🔍 [ROUND] ❌ ROUND NON COMPLETO - newCurrentRoundNumber invariato = $newCurrentRoundNumber");
    }

    // 6. Aggiorna i punteggi
    Map<String, int> updatedScores = Map<String, int>.from(builderState.playerScores);
    updatedScores[currentTurn.playerId] = currentTurn.score;

    // 7. Variabili per leg/set/match (INCLUSI TEAM)
    Map<String, int> updatedLegsWon = Map.from(builderState.legsWon);
    Map<String, int> updatedSetsWon = Map.from(builderState.setsWon);
    Map<String, int> updatedTeamLegsWon = Map.from(builderState.teamLegsWon);
    Map<String, int> updatedTeamSetsWon = Map.from(builderState.teamSetsWon);
    bool legFinished = false;
    bool setFinished = false;
    bool matchFinished = false;
    String? legWinnerId;
    String? setWinnerId;
    String? matchWinnerId;

    // ✅ FIX CRITICO 1: COPIA PROFONDA dei dati Cricket (non riferimento)
    //    Crea NUOVE mappe indipendenti dai vecchi dati
    Map<String, Map<int, int>> newCricketMarks = Map.fromEntries(
        builderState.cricketMarks.entries.map((e) => MapEntry(e.key, Map<int, int>.from(e.value)))
    );
    Map<String, int> newCricketPoints = Map<String, int>.from(builderState.cricketPoints);

    // 8. VERIFICA SE IL LEG È FINITO (checkout)
    if (currentTurn.isCheckout) {
      print("🔍 [ROUND] 🏆 LEG FINITO! (checkout)");
      print("   newCurrentRoundNumber PRIMA del reset: $newCurrentRoundNumber");

      legFinished = true;
      legWinnerId = currentTurn.playerId;

      // 🆕 TEAM MODE: determina il vincitore (team o giocatore)
      final isTeamMode = builderState.teamSize > 1;
      String winnerIdForStats;

      if (isTeamMode) {
        winnerIdForStats = builderState.playerToTeam[legWinnerId!] ?? legWinnerId!;
        legWinnerId = winnerIdForStats;
      } else {
        winnerIdForStats = legWinnerId!;
      }

      // INCREMENTA LEG VINTI (team o player)
      if (isTeamMode) {
        updatedTeamLegsWon[winnerIdForStats] = (updatedTeamLegsWon[winnerIdForStats] ?? 0) + 1;
        print("   🏆 TEAM $winnerIdForStats ha vinto il leg - Ora: ${updatedTeamLegsWon[winnerIdForStats]} leg vinti");
      } else {
        updatedLegsWon[winnerIdForStats] = (updatedLegsWon[winnerIdForStats] ?? 0) + 1;
        print("   🏆 PLAYER $winnerIdForStats ha vinto il leg - Ora: ${updatedLegsWon[winnerIdForStats]} leg vinti");
      }

      // 🔧 CORREZIONE: Assicurati che tutti i turni del round corrente siano salvati
      List<Round> finalLegRounds = List.from(updatedLegRounds);

      // Se il round non era completo ma ci sono turni, crea un round parziale
      if (!roundComplete && updatedRoundTurns.isNotEmpty) {
        final partialRound = Round(
          roundNumber: builderState.currentLegRounds.length + 1,
          turns: updatedRoundTurns,
          timestamp: DateTime.now(),
        );
        finalLegRounds = [...finalLegRounds, partialRound];
        print("   🔧 Creato round parziale con ${updatedRoundTurns.length} turni per leg ${builderState.currentLegNumber}");
      }

      // CREA IL LEG COMPLETATO
// In _commitCurrentTurnAndAdvance, quando crei completedLeg:

// CREA IL LEG COMPLETATO (con i dati Cricket salvati)
      final completedLeg = Leg(
        legNumber: builderState.currentLegNumber,
        rounds: finalLegRounds,
        winnerId: legWinnerId,
        winnerName: _getPlayerName(legWinnerId),
        winningScore: currentTurn.score,
        startTime: builderState.currentLegRounds.isNotEmpty
            ? builderState.currentLegRounds.first.timestamp
            : DateTime.now(),
        endTime: DateTime.now(),
        // ✅ SALVA I DATI CRICKET DI QUESTO LEG (COPIA PROFONDA)
        cricketMarks: Map.fromEntries(
            builderState.cricketMarks.entries.map(
                    (e) => MapEntry(e.key, Map<int, int>.from(e.value))
            )
        ),
        cricketPoints: Map<String, int>.from(builderState.cricketPoints),
      );

      print("📊 LEG SAVED - rounds: ${finalLegRounds.length}, turns in each round:");
      for (var r in finalLegRounds) {
        print("   Round ${r.roundNumber}: ${r.turns.length} turns");
        for (var t in r.turns) {
          print("      Turn ${t.turnNumber}: ${t.throws.length} darts - ${t.total} pts");
        }
      }
      print("   ✅ LEG COMPLETATO: ${finalLegRounds.length} round, vincitore: $legWinnerId");

      // AGGIUNGI IL LEG AL SET CORRENTE
      updatedSetLegs = [...builderState.currentSetLegs, completedLeg];

      // VERIFICA SE HA VINTO IL SET
      int legsWonCount;
      if (isTeamMode) {
        legsWonCount = updatedTeamLegsWon[winnerIdForStats] ?? 0;
      } else {
        legsWonCount = updatedLegsWon[winnerIdForStats] ?? 0;
      }
      print("   Leg vinti da $winnerIdForStats: $legsWonCount / ${state.matchConfig.legsToWin}");

      if (legsWonCount >= state.matchConfig.legsToWin) {
        setFinished = true;
        setWinnerId = winnerIdForStats;
        print("   🎯 SET VINTO DA: $setWinnerId!");

        // INCREMENTA SET VINTI (team o player)
        if (isTeamMode) {
          updatedTeamSetsWon[setWinnerId!] = (updatedTeamSetsWon[setWinnerId] ?? 0) + 1;
          print("   🏆 TEAM $setWinnerId ha vinto il set - Ora: ${updatedTeamSetsWon[setWinnerId]} set vinti");
        } else {
          updatedSetsWon[setWinnerId!] = (updatedSetsWon[setWinnerId] ?? 0) + 1;
          print("   🏆 PLAYER $setWinnerId ha vinto il set - Ora: ${updatedSetsWon[setWinnerId]} set vinti");
        }

        final completedSet = Set(
          setNumber: builderState.currentSetNumber,
          legs: updatedSetLegs,
          winnerId: setWinnerId,
          startTime: DateTime.now(),
          endTime: DateTime.now(),
        );

        // AGGIUNGI IL SET AL MATCH
        updatedMatchSets = List<Set>.from(builderState.matchSets)..add(completedSet);

        print("📊 SET SAVED - legs: ${updatedSetLegs.length}");
        for (var l in updatedSetLegs) {
          print("   Leg ${l.legNumber}: ${l.rounds.length} rounds, winner: ${l.winnerId}");
        }

        // VERIFICA SE HA VINTO IL MATCH
        int setsWonCount;
        if (isTeamMode) {
          setsWonCount = updatedTeamSetsWon[setWinnerId!] ?? 0;
        } else {
          setsWonCount = updatedSetsWon[setWinnerId!] ?? 0;
        }
        print("   Set vinti da $setWinnerId: $setsWonCount / ${state.matchConfig.setsToWin}");

        if (setsWonCount >= state.matchConfig.setsToWin) {
          print("🏆🏆🏆 MATCH VINTO - creazione Match finale");

          matchFinished = true;
          matchWinnerId = setWinnerId;
          print("   🏆🏆🏆 MATCH VINTO DA: $matchWinnerId! 🏆🏆🏆");

          // 🆕 CREA IL SET COMPLETATO (quello corrente che ha fatto vincere il match)
          final completedSetFinal = Set(
            setNumber: builderState.currentSetNumber,
            legs: updatedSetLegs,
            winnerId: setWinnerId,
            startTime: builderState.currentSetLegs.isNotEmpty
                ? builderState.currentSetLegs.first.startTime
                : DateTime.now(),
            endTime: DateTime.now(),
          );

          // AGGIUNGI IL SET CORRENTE AL MATCH (insieme agli altri set già completati)
          final finalMatchSets = List<Set>.from(builderState.matchSets)..add(completedSetFinal);

          final match = Match(
            id: 'match_${DateTime.now().millisecondsSinceEpoch}',
            sets: finalMatchSets,
            winnerId: matchWinnerId,
            startTime: state.matchStartTime ?? DateTime.now(),  // ← usa quello salvato
            endTime: DateTime.now(),
          );

          // 🆕 SALVA IN LOCALE (NON BLOCCANTE)
          unawaited(_saveMatchForEachPlayer(match, matchWinnerId!));

          // Salva il match completato nello stato e mostra overlay
          state = state.copyWith(
            completedMatch: match,
            matchWinnerId: matchWinnerId,
            matchFinished: true,
          );

          print("📊 FINAL MATCH - sets: ${finalMatchSets.length}");
          for (var s in finalMatchSets) {
            print("   Set ${s.setNumber}: ${s.legs.length} legs, winner: ${s.winnerId}");
            for (var l in s.legs) {
              print("      Leg ${l.legNumber}: ${l.rounds.length} rounds");
            }
          }
          return; // Esci perché il match è finito
        }

        // RESETTA LEG VINTI PER IL NUOVO SET
        if (isTeamMode) {
          for (final teamId in updatedTeamLegsWon.keys) {
            updatedTeamLegsWon[teamId] = 0;
          }
          print("   🔄 Team legs reset per il nuovo set");
        } else {
          for (final id in builderState.playerIds) {
            updatedLegsWon[id] = 0;
          }
          print("   🔄 Player legs reset per il nuovo set");
        }

        // RESETTA LEG DEL SET PER NUOVO SET
        updatedSetLegs = [];
        newCurrentSetNumber++;

        // RESETTA currentLegNumber a 1 per il nuovo set
        newCurrentLegNumber = 1;

        // RESETTA ROUND DEL LEG PER NUOVO LEG
        updatedLegRounds = [];

      } else {
        // LEG FINITO MA SET NON FINITO: incrementa leg normalmente
        newCurrentLegNumber++;
        print("   ➡️ Nuovo leg #$newCurrentLegNumber (set non finito)");
      }

      // RESETTA nextRoundTurns per il nuovo leg
      nextRoundTurns = [];

      // RESETTA currentRoundNumber a 1 per il nuovo leg
      newCurrentRoundNumber = 1;
      print("🔍 [ROUND] newCurrentRoundNumber DOPO reset = $newCurrentRoundNumber");

      // RESETTA ROUND DEL LEG PER NUOVO LEG
      updatedLegRounds = [];
      print("🔍 [ROUND] updatedLegRounds resettato a []");

      // ============================================================
      // RESETTA PUNTEGGI PER NUOVO LEG (X01 e Cricket)
      // ============================================================
      final isCricket = state.gameConfig.type == GameType.cricket;
      final resetScores = Map<String, int>.from(updatedScores);

      for (final id in builderState.playerIds) {
        if (isCricket) {
          resetScores[id] = 0;  // Cricket parte da 0 punti
        } else {
          resetScores[id] = state.gameConfig.startingScore ?? 501;  // X01 parte da startingScore
        }
      }
      updatedScores = resetScores;

      print("   🔄 Punteggi resettati per il nuovo leg (Cricket: $isCricket)");
      print("   📊 Nuovi punteggi: $updatedScores");

      // ============================================================
      // ✅ FIX CRITICO 2: RESETTA CRICKET MARKS E PUNTI PER NUOVO LEG
      //    Crea NUOVE mappe completamente indipendenti (non riferimenti)
      // ============================================================
      if (isCricket) {
        newCricketMarks = CricketRules.initializeMarks(builderState.playerIds);
        newCricketPoints = CricketRules.initializePoints(builderState.playerIds);
        print("   🎯 CRICKET RESET - Nuovi marks e punti inizializzati per il leg $newCurrentLegNumber");
      }

    } // ← Chiude il blocco if (currentTurn.isCheckout)

    // 9. Trova il prossimo giocatore
    final String nextPlayerId;

    if (legFinished) {
      // Inizio di un nuovo leg: usa getStartingPlayerForLeg
      nextPlayerId = BaseRules.getStartingPlayerForLeg(
        newCurrentLegNumber,
        builderState.playerIds,
        builderState.teamSize,
      );
      print("   🎲 Nuovo leg - giocatore iniziale: $nextPlayerId");
    } else {
      // Turno normale all'interno dello stesso leg: usa getNextPlayer
      nextPlayerId = getNextPlayer(
        currentTurn.playerId,
        builderState.playerIds,
        builderState.teamSize,
      )!;
      print("   🔄 Prossimo giocatore normale: $nextPlayerId");
    }

    final nextPlayerScore = updatedScores[nextPlayerId] ??
        (state.gameConfig.startingScore ?? 501);
    final nextTurnNumber = updatedAllTurns.length + 1;

    // 10. Prepara stato apertura per nuovo leg
    Map<String, bool> finalOpened = builderState.playersOpened;
    if (legFinished && state.gameConfig.doubleIn == true) {
      finalOpened = Map.from(builderState.playersOpened);
      for (final id in builderState.playerIds) {
        finalOpened[id] = false;
      }
      print("   🔒 DoubleIn attivo - giocatori bloccati per il nuovo leg");
    }

    // 11. Crea nuovo turno
    final newTurn = PlayerTurn(
      playerId: nextPlayerId,
      turnNumber: nextTurnNumber,
      roundNumber: newCurrentRoundNumber,
      legNumber: newCurrentLegNumber,
      throws: [],
      total: 0,
      totalMarks: 0,
      initialScore: nextPlayerScore,
      score: nextPlayerScore,
      isBust: false,
      isCheckout: false,
      timestamp: DateTime.now(),
    );

    // 🔍 PRINT 7 - VALORE FINALE PRIMA DI CREARE newBuilderState
    print("🔍 [ROUND] === VALORI FINALI ===");
    print("   newCurrentRoundNumber = $newCurrentRoundNumber");
    print("   newCurrentLegNumber = $newCurrentLegNumber");
    print("   updatedLegRounds.length = ${updatedLegRounds.length}");
    print("   nextRoundTurns.length = ${nextRoundTurns.length}");
    print("   legFinished = $legFinished");
    print("   teamLegsWon finali: $updatedTeamLegsWon");
    print("   teamSetsWon finali: $updatedTeamSetsWon");

    // 12. Costruisci nuovo stato
    final newBuilderState = MatchBuilderState(
      allTurns: updatedAllTurns,
      currentTurn: newTurn,
      currentPlayerId: nextPlayerId,
      playerIds: builderState.playerIds,
      teamSize: builderState.teamSize,
      playerScores: updatedScores,
      playersOpened: finalOpened,
      currentLegNumber: newCurrentLegNumber,
      currentSetNumber: newCurrentSetNumber,
      currentRoundNumber: newCurrentRoundNumber,
      legsWon: updatedLegsWon,
      setsWon: updatedSetsWon,
      currentLegRounds: updatedLegRounds,
      currentSetLegs: updatedSetLegs,
      matchSets: updatedMatchSets,
      currentRoundTurns: nextRoundTurns,
      currentRoundTurnCount: builderState.currentRoundTurnCount,
      teamLegsWon: updatedTeamLegsWon,
      teamSetsWon: updatedTeamSetsWon,
      teamScores: builderState.teamScores,
      playerToTeam: builderState.playerToTeam,
      cricketMarks: newCricketMarks,      // ✅ USA I NUOVI (resettati se leg finito)
      cricketPoints: newCricketPoints,    // ✅ USA I NUOVI (resettati se leg finito)
    );

    // 13. Log
    print("✅ NUOVO TURNO - playerId: $nextPlayerId, turnNumber: $nextTurnNumber");
    if (legFinished) print("🏆 LEG VINTO DA: $legWinnerId - NUOVO LEG: $newCurrentLegNumber, NUOVO ROUND: 1");
    if (setFinished) print("🏆 SET VINTO DA: $setWinnerId - NUOVO SET: $newCurrentSetNumber, NUOVO LEG: 1");
    if (matchFinished) print("🏆🏆🏆 MATCH VINTO DA: $matchWinnerId 🏆🏆🏆");

    // 14. Aggiorna stato
    state = state.copyWith(
      builderState: newBuilderState,
      gameState: _convertToGameState(newBuilderState),
      isWaitingForTurnPass: false,
      turnPassProgress: 0.0,
    );

    // 15. Attiva bot se necessario (dopo che l'UI si è aggiornata)
    print('🤖 [ROOM] Post-commit: verifico se attivare bot');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentGameState = state.gameState;
      print('🤖 [ROOM] currentGameState: ${currentGameState != null}');
      if (currentGameState != null) {
        print('🤖 [ROOM] Chiamo startBotIfNeeded per player: ${currentGameState.currentPlayerId}');
        _botController.startBotIfNeeded(currentGameState);
      }
    });
  } // ← Chiude il metodo _commitCurrentTurnAndAdvance


  // ============================================================
  // LOBBY OPERATIONS
  // ============================================================

  void _createEmptyState() {
    if (state.playerIds.isEmpty) {
      state = state.copyWith(
        builderState: null,
        gameState: null,
        status: AppStatus.success,
        errorMessage: null,
      );
      return;
    }

    try {
      final builder = MatchBuilder(
        teamSize: state.teamSize,
        startingScore: state.gameConfig.startingScore ?? 501,
      );
      final builderState = builder.initialize(state.playerIds, state.gameConfig);
      state = state.copyWith(
        builderState: builderState,
        gameState: _convertToGameState(builderState),
        status: AppStatus.success,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Errore inizializzazione: $e',
      );
    }
  }

  void _recreateMatch() {
    _cancelTurnPassTimer();
    _history.clear();  // ← AGGIUNGI QUESTA RIGA
    if (state.playerIds.isEmpty) {
      state = state.copyWith(builderState: null, gameState: null, status: AppStatus.success);
      return;
    }

    try {
      final builder = MatchBuilder(
        teamSize: state.teamSize,
        startingScore: state.gameConfig.startingScore ?? 501,
      );
      final builderState = builder.initialize(state.playerIds, state.gameConfig);
      state = state.copyWith(
        builderState: builderState,
        gameState: _convertToGameState(builderState),
        status: AppStatus.success,
      );

      // 🔥 Se il primo giocatore è un bot, attivalo subito
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentGameState = state.gameState;
        if (currentGameState != null && currentGameState.currentPlayerId.startsWith('bot_')) {
          print('🤖 [ROOM] _recreateMatch - primo giocatore è un bot: ${currentGameState.currentPlayerId}');
          _botController.startBotIfNeeded(currentGameState);
        }
      });
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Errore ricreazione match: $e',
      );
    }
  }

  void addPlayer(String playerId, String playerName, bool isGuest) {
    final newOrder = state.players.length;
    final newPlayer = PlayerInfo(
      id: playerId,
      name: playerName,
      isGuest: isGuest,
      order: newOrder,
    );
    final newPlayers = [...state.players, newPlayer];
    state = state.copyWith(players: newPlayers);
    _recreateMatch();
  }

  void addBot(BotLevel level) {
    final botId = 'bot_${level.name}_${DateTime.now().millisecondsSinceEpoch}';
    final botName = '🤖 ${level.displayName}';
    addPlayer(botId, botName, true);
  }

  void removePlayer(String playerId) {
    final newPlayers = state.players.where((p) => p.id != playerId).toList();
    for (int i = 0; i < newPlayers.length; i++) {
      newPlayers[i] = newPlayers[i].copyWith(order: i);
    }
    state = state.copyWith(players: newPlayers);
    _recreateMatch();
  }

  void reorderPlayers(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final reordered = List<PlayerInfo>.from(state.players);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    for (int i = 0; i < reordered.length; i++) {
      reordered[i] = reordered[i].copyWith(order: i);
    }
    state = state.copyWith(players: reordered);
    _recreateMatch();
  }

  void updateGameConfig(GameConfig config) {
    state = state.copyWith(gameConfig: config);
    _recreateMatch();
  }

  void updateMatchConfig(MatchConfig config) {
    state = state.copyWith(matchConfig: config);
    _recreateMatch();
  }

  void updateTeamSize(int size) {
    state = state.copyWith(teamSize: size);
    _recreateMatch();
  }

  void startMatch() {
    _cancelTurnPassTimer();
    _history.clear();

    // Resetta TUTTO lo stato del match prima di ricrearlo
    state = state.copyWith(
      builderState: null,
      gameState: null,
      completedMatch: null,
      matchWinnerId: null,
      matchFinished: false,
      matchStartTime: DateTime.now(),
    );

    _recreateMatch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentGameState = state.gameState;
      if (currentGameState != null && currentGameState.currentPlayerId.startsWith('bot_')) {
        print('🤖 [ROOM] Inizio match - primo giocatore è un bot: ${currentGameState.currentPlayerId}');
        _botController.startBotIfNeeded(currentGameState);
      }
    });
  }

  void resetAll() {
    _cancelTurnPassTimer();
    _history.clear();  // ← AGGIUNGI QUESTA RIGA

    state = RoomState(
      gameConfig: GameConfig.x01(),
      matchConfig: const MatchConfig(mode: MatchMode.firstTo, setCount: 1, legCount: 2),
      players: [],
      teamSize: 0,
      status: AppStatus.initial,
      builderState: null,
      gameState: null,
    );
    _createEmptyState();
  }

  @override
  void dispose() {
    _cancelTurnPassTimer();
    super.dispose();
  }

// ============================================================
// SALVATAGGIO MATCH PER GIOCATORE (SOLO I PROPRI TURNI)
// ============================================================

  Future<void> _saveMatchForEachPlayer(Match match, String winnerId) async {
    final builderState = state.builderState;
    if (builderState == null) return;

    // Raggruppa i giocatori Firebase (escludi guest)
    final firebasePlayers = state.players.where((p) => !p.isGuest).toList();

    if (firebasePlayers.isEmpty) {
      print("⚠️ Nessun giocatore Firebase da salvare");
      return;
    }

    // Per ogni giocatore Firebase, crea un record separato
    for (final player in firebasePlayers) {
      await _savePlayerMatchRecord(match, winnerId, player);
    }
  }

  Future<void> _savePlayerMatchRecord(Match match, String winnerId, PlayerInfo player) async {
    final builderState = state.builderState;
    if (builderState == null) return;

    // Costruisci la struttura gerarchica filtrata per QUESTO giocatore
    final filteredSets = <Map<String, dynamic>>[];

    for (final set in match.sets) {
      final filteredLegs = <Map<String, dynamic>>[];

// In _savePlayerMatchRecord, invece di saltare i leg senza turni,
// salva un leg vuoto con rounds vuoti
      for (final leg in set.legs) {
        final filteredRounds = <Map<String, dynamic>>[];
        for (final round in leg.rounds) {
          final playerTurns = round.turns
              .where((turn) => turn.playerId == player.id)
              .map((turn) => turn.toMap())
              .toList();
          // SEMPRE aggiungi il round, anche se vuoto
          filteredRounds.add({
            'roundNumber': round.roundNumber,
            'timestamp': round.timestamp.toIso8601String(),
            'turns': playerTurns,  // Può essere vuoto
          });
        }
        // SEMPRE aggiungi il leg
        filteredLegs.add({
          'legNumber': leg.legNumber,
          'winnerId': leg.winnerId,
          'winningScore': leg.winningScore,
          'startTime': leg.startTime.toIso8601String(),
          'endTime': leg.endTime?.toIso8601String(),
          'rounds': filteredRounds,
        });
      }

      if (filteredLegs.isNotEmpty) {
        filteredSets.add({
          'setNumber': set.setNumber,
          'winnerId': set.winnerId,
          'startTime': set.startTime.toIso8601String(),
          'endTime': set.endTime?.toIso8601String(),
          'legs': filteredLegs,
        });
      }
    }

    // Calcola statistiche del giocatore
    final playerTurns = builderState.allTurns
        .where((turn) => turn.playerId == player.id)
        .toList();

    final totalScore = playerTurns.fold(0, (sum, t) => sum + t.total);
    final totalDarts = playerTurns.fold(0, (sum, t) => sum + t.throws.length);
    final avg = totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;
    final checkouts = playerTurns.where((t) => t.isCheckout).length;
    final checkoutPct = playerTurns.isNotEmpty ? (checkouts / playerTurns.length) * 100 : 0.0;
    final bestTurn = playerTurns.isEmpty ? 0 : playerTurns.map((t) => t.total).reduce((a, b) => a > b ? a : b);
    final legsWonCount = builderState.legsWon[player.id] ?? 0;
    final setsWonCount = builderState.setsWon[player.id] ?? 0;

    // Prepara le configurazioni
    final gameConfigMap = {
      'type': state.gameConfig.type.name,
      'startingScore': state.gameConfig.startingScore,
      'tripleOut': state.gameConfig.tripleOut,
      'doubleOut': state.gameConfig.doubleOut,
      'doubleIn': state.gameConfig.doubleIn,
    };

    final matchConfigMap = {
      'mode': state.matchConfig.mode.name,
      'setCount': state.matchConfig.setCount,
      'legCount': state.matchConfig.legCount,
    };

    // Ogni giocatore Firebase ha un record locale separato.
    // Non usare solo match.id: in multi-player causerebbe collisioni locali.
    final localRecordId = '${match.id}_${player.id}';

    final tempRecord = LocalMatchRecord(
      localId: localRecordId,
      remoteId: null,      mode: state.gameConfig.type == GameType.x01 ? 'x01' : 'cricket',
      winnerId: winnerId,
      winnerName: _getPlayerName(winnerId),
      playerIds: state.playerIds,
      playerNames: state.players.map((p) => p.name).toList(),
      finalScores: builderState.playerScores,
      legsWon: builderState.legsWon,
      setsWon: builderState.setsWon,
      startTime: match.startTime,
      endTime: match.endTime ?? DateTime.now(),
      createdAt: match.startTime,
      updatedAt: match.endTime ?? DateTime.now(),
      totalTurns: playerTurns.length,
      totalDarts: totalDarts,
      gameConfig: gameConfigMap,
      matchConfig: matchConfigMap,
      teamSize: state.teamSize,
      playerToTeam: builderState.playerToTeam.isNotEmpty ? builderState.playerToTeam : null,
      playerTurns: {player.id: playerTurns},
      matchSets: filteredSets,
      syncStatus: LocalMatchSyncStatus.pending,
    );

    // 🔥 SALVA E OTTIENI IL remoteId (lo stesso per tutti i giocatori)
    debugPrint('📤 CALLING saveMatch with localId: ${tempRecord.localId}');
    try {
      final result = await LocalMatchSyncService.instance.saveMatch(tempRecord);
      debugPrint('📤 saveMatch result: $result');
    } catch (e, stack) {
      debugPrint('❌ saveMatch FAILED: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }

    // Recupera il record salvato per verificare eventuale remoteId.
    final savedRecord = await LocalMatchSyncService.instance.getById(localRecordId);

    if (savedRecord != null && savedRecord.remoteId != null) {
      // Il remoteId è lo stesso per tutti i giocatori!
      debugPrint('📊 Match saved for player ${player.name} with remoteId: ${savedRecord.remoteId}');
    } else {
      debugPrint('⚠️ Match saved for player ${player.name} but remoteId not yet available');
    }
  }

  String _getPlayerName(String playerId) {
    final player = state.players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => PlayerInfo(id: playerId, name: playerId, isGuest: false, order: 0),
    );
    return player.name;
  }

}
// TARGET: costruire cricketMarks dai turni
// LOGIC GOAL: calcolo puro, nessuno stato duplicato
// ANTI-REGRESSION: compatibile X01

Map<String, Map<int, int>> _buildCricketMarks(MatchBuilderState builderState) {
  final result = <String, Map<int, int>>{};

  // init
  for (final playerId in builderState.playerIds) {
    result[playerId] = {
      20: 0,
      19: 0,
      18: 0,
      17: 0,
      16: 0,
      15: 0,
      25: 0,
    };
  }

  for (final turn in builderState.allTurns) {
    final playerId = turn.playerId;

    for (final dart in turn.throws) {
      final target = dart.target;
      final multiplier = dart.multiplier;

      if (!result[playerId]!.containsKey(target)) continue;

      final current = result[playerId]![target]!;
      final updated = (current + multiplier).clamp(0, 3);

      result[playerId]![target] = updated;
    }
  }

  return result;
}
final roomNotifierProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier();
});