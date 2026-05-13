// TARGET: Stato completo e immutabile del gioco
// LOGIC GOAL: Contenere match, configurazioni, stato corrente
// REACTION: UI reagisce a cambiamenti di stato
// ERROR STRATEGY: Stato error con messaggio
// ANTI-REGRESSION: Mantenere tutti i campi necessari per UI completa

import 'package:flutter/foundation.dart';
import '../game_types/x01_rules.dart';
import '../rules/base_rules.dart';
import 'match.dart';
import 'game_config.dart';
import 'player_info.dart';
import 'player_turn.dart';

@immutable
class GameState {
  final Match match;
  final GameConfig gameConfig;
  final MatchConfig matchConfig;
  final List<PlayerTurn> allTurns;
  final PlayerTurn currentTurn;
  final String currentPlayerId;
  final Map<String, int> playerScores;
  final Map<String, List<PlayerTurn>> playerTurnsHistory;
  final Map<String, bool> playersOpened;

  // 🆕 CRICKET DATA - TRANSITORI (solo per UI, dal leg corrente)
  final Map<String, Map<int, int>> cricketMarks;
  final Map<String, int> cricketPoints;

  final int currentRoundNumber;
  final List<PlayerInfo> players;
  final Map<String, int> legsWon;
  final Map<String, int> setsWon;
  final Map<String, int> teamScores;
  final Map<String, String> playerToTeam;
  final Map<String, int> teamLegsWon;
  final Map<String, int> teamSetsWon;
  final int teamSize;

  const GameState({
    required this.match,
    required this.gameConfig,
    required this.matchConfig,
    required this.allTurns,
    required this.currentTurn,
    required this.currentPlayerId,
    required this.playerScores,
    required this.playerTurnsHistory,
    this.currentRoundNumber = 1,
    required this.players,
    required this.legsWon,
    required this.setsWon,
    required this.playersOpened,
    required this.cricketMarks,
    required this.cricketPoints,
    required this.teamScores,
    required this.playerToTeam,
    required this.teamLegsWon,
    required this.teamSetsWon,
    required this.teamSize,
  });

  // === GETTER PER UI ===
  // =========================
  // 🔥 UI GETTERS COMPLETI
  // =========================

  // ───── PLAYER ─────

  PlayerInfo getPlayer(String playerId) {
    return players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => PlayerInfo(id: playerId, name: playerId, isGuest: false, order: 0),
    );
  }

  String getPlayerName(String playerId) => getPlayer(playerId).name;

  int getPlayerOrder(String playerId) => getPlayer(playerId).order;

  List<PlayerInfo> get playersSorted {
    final list = List<PlayerInfo>.from(players);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }
  /// 🔥 ORDINE VISIVO STABILE (UI)
  List<PlayerInfo> get playersUiOrder {
    final list = List<PlayerInfo>.from(players);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<String> get orderedPlayerIds {
    return BaseRules.calculateTurnOrder(
      players.map((p) => p.id).toList(),
      teamSize,
    );
  }
  int getPlayerPosition(String playerId) {
    final index = orderedPlayerIds.indexOf(playerId);
    return index == -1 ? 0 : index + 1;
  }
  List<String> get orderedTeamIds {
    final order = <String>[];

    for (final playerId in orderedPlayerIds) {
      final team = getPlayerTeam(playerId);
      if (team != null && !order.contains(team)) {
        order.add(team);
      }
    }

    return order;
  }

  PlayerInfo get currentPlayer => getPlayer(currentPlayerId);

  // ───── TURN UI ─────

  String getTurnLabel(PlayerTurn turn) {
    if (turn.isCheckout) return "CHECKOUT";
    if (turn.isBust) return "BUST";
    return "${turn.total}";
  }

  String getTurnStatus(PlayerTurn turn) {
    if (turn.isCheckout) return "OUT";
    if (turn.isBust) return "BUST";
    if (!turn.isComplete) return "PLAYING";
    return "DONE";
  }

  int getTurnScoreDiff(PlayerTurn turn) {
    return turn.initialScore - turn.score;
  }

  // ───── PLAYER STATE UI ─────

  bool isPlayerFrozen(String playerId) {
    final doubleIn = gameConfig.doubleIn ?? false;
    final isOpen = playersOpened[playerId] ?? false;
    final isCurrent = playerId == currentPlayerId;

    if (!doubleIn) return false;
    if (!isCurrent) return false;

    final turn = currentTurn;
    return !isOpen && !turn.isCheckout && !turn.isBust;
  }

  String getPlayerStateLabel(String playerId) {
    final turn = currentTurn;

    if (turn.playerId != playerId) return "";

    if (turn.isCheckout) return "OUT";
    if (turn.isBust) return "BUST";
    if (isCheckoutBlocked) return "NO OUT";
    if (isPlayerFrozen(playerId)) return "DOUBLE IN";

    return "${remainingThrows} LEFT";
  }

  // ───── TEAM ─────

  List<String> get teams {
    return playerToTeam.values.toSet().toList();
  }

  List<String> getPlayersByTeam(String teamId) {
    return playerToTeam.entries
        .where((e) => e.value == teamId)
        .map((e) => e.key)
        .toList();
  }

  Map<String, List<String>> get teamPlayersMap {
    final map = <String, List<String>>{};
    for (final entry in playerToTeam.entries) {
      map.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    return map;
  }

  // ───── MATCH UI ─────

  String get currentSetLabel => "SET ${getCurrentSetNumber()}";

  String get currentLegLabel => "LEG ${getCurrentLegNumber()}";

  String get currentRoundLabel => "R$currentRoundNumber";

  // ───── SCORE UI ─────

  String getPlayerScoreLabel(String playerId) {
    final score = getPlayerLiveScore(playerId);
    if (score == 0) return "WIN";
    return "$score";
  }

  // ───── CRICKET UI ─────

  List<int> get cricketNumbers => [20, 19, 18, 17, 16, 15, 25];

  bool isCricketNumberClosedForAll(int number) {
    return players.every((p) => isNumberClosed(p.id, number));
  }

  // ───── SAFE GAME TYPE ─────

  bool get isCricketSafe => gameConfig.type == GameType.cricket;

  bool get isX01Safe => gameConfig.type == GameType.x01;

  String get currentTurnLabel =>
      "🎯 Turno #${currentTurn.turnNumber} - ${currentTurn.playerId}";

  int get remainingThrows => currentTurn.remainingThrows;

  double get turnProgress => currentTurn.throws.length / 3;

  List<PlayerTurn> getTurnsForPlayer(String playerId) {
    return playerTurnsHistory[playerId] ?? [];
  }
  // TARGET: Determinare tipo gioco senza rompere GameConfig
// LOGIC GOAL: Non dipendere da nomi proprietà non garantiti
// ANTI-REGRESSION: Nessuna modifica a firme esistenti

  bool get isCricket => gameConfig.type == GameType.cricket;

  bool get isX01 => !isCricket;

// UI helpers
  bool get showCricketBoard => isCricket;
  bool get showX01Score => isX01;
// Getter per UI
  // TARGET: Getter UI per Cricket
// LOGIC GOAL: Esporre stato marks per numero
// ANTI-REGRESSION: fallback sicuro

  int getCricketMarks(String playerId, int number) {
    return cricketMarks[playerId]?[number] ?? 0;
  }

  bool isNumberClosed(String playerId, int number) {
    return getCricketMarks(playerId, number) >= 3;
  }

  bool get isTeamMode => teamSize > 1;
  String? getPlayerTeam(String playerId) => playerToTeam[playerId];

  // In game_state.dart, sostituisci getTeamScore con:

  int getTeamScore(String teamId) {
    if (isCricket && teamSize > 1) {
      // 🔥 Cricket team: somma i punti INDIVIDUALI dei giocatori del team
      final teamPlayerIds = playerToTeam.entries
          .where((entry) => entry.value == teamId)
          .map((entry) => entry.key)
          .toList();

      int total = 0;
      for (final playerId in teamPlayerIds) {
        total += getCricketPoints(playerId);
      }
      return total;
    }

    // X01 team mode: somma i punteggi live
    final teamPlayerIds = playerToTeam.entries
        .where((entry) => entry.value == teamId)
        .map((entry) => entry.key)
        .toList();
    return teamPlayerIds.fold(0, (sum, playerId) => sum + getPlayerLiveScore(playerId));
  }

  /// Ottieni il punteggio Cricket per un team - 🔥 STESSA LOGICA di getTeamScore
  int getTeamCricketPoints(String teamId) {
    // Cricket team: somma i punti INDIVIDUALI
    final teamPlayerIds = playerToTeam.entries
        .where((entry) => entry.value == teamId)
        .map((entry) => entry.key)
        .toList();

    int total = 0;
    for (final playerId in teamPlayerIds) {
      total += getCricketPoints(playerId);
    }
    return total;
  }

  int getTeamLegsWon(String teamId) => teamLegsWon[teamId] ?? 0;
  int getTeamSetsWon(String teamId) => teamSetsWon[teamId] ?? 0;
  int getTeamIndex(String teamId) {
    final teams = orderedTeamIds; // ✅ usa ordine reale di gioco

    final index = teams.indexOf(teamId);
    return index == -1 ? 0 : index;
  }
  /// Osservatore perenne: verifica se il checkout è bloccato per il giocatore corrente
  bool get isCheckoutBlocked {
    // Calcola tutti i punteggi live dei team
    final allTeamScores = <String, int>{};
    final teams = playerToTeam.values.toSet();
    for (final team in teams) {
      allTeamScores[team] = getTeamScore(team);
    }

    // Ottieni il team corrente
    final currentTeamId = getPlayerTeam(currentPlayerId);
    if (currentTeamId == null) return false;

    // Ottieni il punteggio del giocatore corrente
    final currentPlayerScore = getPlayerLiveScore(currentPlayerId);

    // Chiama la funzione di X01Rules
    return X01Rules.isCheckoutBlocked(
      allTeamScores: allTeamScores,
      currentTeamId: currentTeamId,
      currentPlayerScore: currentPlayerScore,
    );
  }

  int getPlayerLiveScore(String playerId) {
    final baseScore = playerScores[playerId] ?? gameConfig.startingScore ?? 0;
    if (playerId == currentPlayerId) {
      return currentTurn.score;  // ← usa score del turno corrente, non calcolare!
    }
    return baseScore;
  }

// Modifica getPlayerAverage per distinguere X01 e Cricket

  double getPlayerAverage(String playerId) {
    final turns = getTurnsForPlayer(playerId);
    if (turns.isEmpty) return 0.0;

    int totalValue = 0;
    int totalDarts = 0;

    for (final turn in turns) {
      if (isCricket) {
        // Cricket: usa totalMarks (somma dei moltiplicatori)
        totalValue += turn.totalMarks;
      } else {
        // X01: usa total (somma dei punteggi)
        totalValue += turn.total;
      }
      totalDarts += turn.throws.length;
    }

    if (totalDarts == 0) return 0.0;
    // Media su 3 dardi
    return (totalValue / totalDarts) * 3;
  }

// Aggiungi un getter separato per la media Cricket (opzionale)
  double getPlayerCricketAverage(String playerId) {
    final turns = getTurnsForPlayer(playerId);
    if (turns.isEmpty || !isCricket) return 0.0;

    int totalMarks = 0;
    int totalDarts = 0;

    for (final turn in turns) {
      totalMarks += turn.totalMarks;
      totalDarts += turn.throws.length;
    }

    if (totalDarts == 0) return 0.0;
    return (totalMarks / totalDarts) * 3;
  }

// Per completezza, aggiungi getter per il totale marks di un giocatore
  int getPlayerTotalMarks(String playerId) {
    final turns = getTurnsForPlayer(playerId);
    return turns.fold(0, (sum, turn) => sum + turn.totalMarks);
  }

  int getPlayerBestTurn(String playerId) {
    final turns = getTurnsForPlayer(playerId);
    if (turns.isEmpty) return 0;
    return turns.map((t) => t.total).reduce((a, b) => a > b ? a : b);
  }

  double getPlayerCheckoutPercentage(String playerId) {
    final turns = getTurnsForPlayer(playerId);
    if (turns.isEmpty) return 0.0;
    final checkouts = turns.where((t) => t.isCheckout).length;
    return (checkouts / turns.length) * 100;
  }
// In game_state.dart

  int getLegsWonByPlayer(String playerId) => legsWon[playerId] ?? 0;
  int getSetsWonByPlayer(String playerId) => setsWon[playerId] ?? 0;

  int getCurrentLegNumber() {
    return match.sets.isEmpty ? 1 : (match.sets.last.legs.length + 1);
  }

  int getCurrentSetNumber() {
    return match.sets.length + 1;
  }
  int getCurrentRoundNumber() {
    return currentRoundNumber;
  }
  // Aggiungi questi metodi nella classe GameState:

  int getCricketPoints(String playerId) {
    return cricketPoints[playerId] ?? 0;
  }

  bool hasPlayerClosedAllCricketNumbers(String playerId) {
    final marks = cricketMarks[playerId];
    if (marks == null) return false;

    const numbers = [20, 19, 18, 17, 16, 15, 25];
    for (final number in numbers) {
      if ((marks[number] ?? 0) < 3) return false;
    }
    return true;
  }
// In game_state.dart, aggiungi dopo i metodi esistenti:

  // ========== CRICKET TEAM SUPPORT ==========

  /// Verifica se un numero è aperto per un team (tutti i giocatori del team hanno 3+ marks)
  bool isCricketNumberOpenForTeam(int number, String teamId) {
    final teamPlayers = playerToTeam.entries
        .where((e) => e.value == teamId)
        .map((e) => e.key)
        .toList();

    if (teamPlayers.isEmpty) return false;

    for (final playerId in teamPlayers) {
      if ((cricketMarks[playerId]?[number] ?? 0) < 3) return false;
    }
    return true;
  }

  /// Verifica se un numero è chiuso globalmente (tutti i giocatori hanno 3+ marks)
  bool isCricketNumberClosedGlobally(int number) {
    for (final player in players) {
      if ((cricketMarks[player.id]?[number] ?? 0) < 3) return false;
    }
    return true;
  }


  GameState copyWith({
    Match? match,
    GameConfig? gameConfig,
    MatchConfig? matchConfig,
    List<PlayerTurn>? allTurns,
    PlayerTurn? currentTurn,
    String? currentPlayerId,
    Map<String, int>? playerScores,
    Map<String, List<PlayerTurn>>? playerTurnsHistory,
    Map<String, bool>? playersOpened,
    Map<String, Map<int, int>>? cricketMarks,
    Map<String, int>? cricketPoints,
    int? currentRoundNumber,
    List<PlayerInfo>? players,
    Map<String, int>? legsWon,
    Map<String, int>? setsWon,
    Map<String, int>? teamScores,
    Map<String, String>? playerToTeam,
    Map<String, int>? teamLegsWon,
    Map<String, int>? teamSetsWon,
    int? teamSize,
  }) {
    return GameState(
      match: match ?? this.match,
      gameConfig: gameConfig ?? this.gameConfig,
      matchConfig: matchConfig ?? this.matchConfig,
      allTurns: allTurns ?? this.allTurns,
      currentTurn: currentTurn ?? this.currentTurn,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      playerScores: playerScores ?? this.playerScores,
      playerTurnsHistory: playerTurnsHistory ?? this.playerTurnsHistory,
      playersOpened: playersOpened ?? this.playersOpened,
      cricketMarks: cricketMarks ?? this.cricketMarks,
      cricketPoints: cricketPoints ?? this.cricketPoints,
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
      players: players ?? this.players,
      teamScores: teamScores ?? this.teamScores,
      playerToTeam: playerToTeam ?? this.playerToTeam,
      teamLegsWon: teamLegsWon ?? this.teamLegsWon,
      teamSetsWon: teamSetsWon ?? this.teamSetsWon,
      teamSize: teamSize ?? this.teamSize,
    );
  }
}
