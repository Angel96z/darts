// TARGET: Overlay risultati match completi con supporto UI TEAM
// LOGIC GOAL: Mostrare UI che supporta sia singoli che team
// NOTE: Le statistiche rimangono PER SINGOLO GIOCATORE

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../domain/models/match.dart';
import '../../domain/models/set.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/round.dart';
import '../../domain/models/player_turn.dart';
import '../../domain/models/dart_throw.dart';
import '../../domain/models/player_info.dart';
import '../../application/room_notifier.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class MatchResultOverlay extends ConsumerStatefulWidget {
  const MatchResultOverlay({super.key});

  @override
  ConsumerState<MatchResultOverlay> createState() => _MatchResultOverlayState();
}

class _MatchResultOverlayState extends ConsumerState<MatchResultOverlay> {
  @override
  Widget build(BuildContext context) {
    final completedMatch = ref.watch(roomNotifierProvider.select((s) => s.completedMatch));
    final matchWinnerId = ref.watch(roomNotifierProvider.select((s) => s.matchWinnerId));
    final players = ref.watch(roomNotifierProvider.select((s) => s.players));
    final showOverlay = ref.watch(roomNotifierProvider.select((s) => s.showResultOverlay));
    final teamSize = ref.watch(roomNotifierProvider.select((s) => s.teamSize));
    final playerToTeam = ref.watch(roomNotifierProvider.select((s) => s.builderState?.playerToTeam ?? {}));

    if (!showOverlay || completedMatch == null) {
      return const SizedBox.shrink();
    }

    final isTeamMode = teamSize > 1;

    return Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.85),
          child: const Center(child: SizedBox.shrink()),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(context, completedMatch, matchWinnerId, players, isTeamMode, playerToTeam),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWinnerSection(matchWinnerId, players, isTeamMode, playerToTeam),
                          const SizedBox(height: 24),
                          _buildStatsSection(completedMatch, players, isTeamMode, playerToTeam),
                          const SizedBox(height: 24),
                          _buildMatchDetails(completedMatch, players, isTeamMode, playerToTeam),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Match match, String? winnerId, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    final winnerName = isTeamMode
        ? _getTeamName(winnerId, players, playerToTeam)
        : _getPlayerName(winnerId, players);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MATCH COMPLETATO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🏆 Vincitore: $winnerName 🏆',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(roomNotifierProvider.notifier).closeResultOverlay();
            },
            icon: const Icon(Icons.close, size: 28),
            tooltip: 'Chiudi risultati',
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerSection(String? winnerId, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    final displayName = isTeamMode
        ? _getTeamName(winnerId, players, playerToTeam)
        : _getPlayerName(winnerId, players);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTeamMode ? 'TEAM VINCITORE' : 'VINCITORE DEL MATCH',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Colors.brown,
            ),
          ),
        ],
      ),
    );
  }

  // STATISTICHE GIOCATORI (invariato, ma con supporto team per mostrare a quale team appartengono)
  Widget _buildStatsSection(Match match, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    return FutureBuilder<Map<String, PlayerStats>>(
      future: _calculatePlayerStats(match, players),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Errore nel caricamento statistiche');
        }

        final stats = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 STATISTICHE GIOCATORI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...stats.entries.map((entry) => _buildPlayerStatCard(
                entry.key,
                entry.value,
                players,
                match,
                isTeamMode,
                playerToTeam
            )),
          ],
        );
      },
    );
  }

  Widget _buildPlayerStatCard(String playerId, PlayerStats stats, List<PlayerInfo> players, Match match, bool isTeamMode, Map<String, String> playerToTeam) {
    final playerName = _getPlayerName(playerId, players);
    final isGuest = players.firstWhere((p) => p.id == playerId).isGuest;
    final teamId = isTeamMode ? playerToTeam[playerId] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: stats.isWinner ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: stats.isWinner ? Border.all(color: Colors.amber, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  playerName.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (teamId != null)
                      Text(
                        teamId,
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              if (stats.isWinner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'WINNER',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              if (!isGuest) ...[
                const SizedBox(width: 8),
                _SyncStatusWidget(
                  initialStatus: stats.syncStatus,
                  matchId: match.id,
                  playerId: playerId,
                  players: players,
                  onTap: () {
                    _showDatabaseStructure(context, match, playerId, players);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _StatChip(label: 'Media', value: '${stats.average.toStringAsFixed(1)}', icon: Icons.show_chart),
              _StatChip(label: 'Checkout %', value: '${stats.checkoutPercentage.toStringAsFixed(0)}%', icon: Icons.check_circle),
              _StatChip(label: 'Miglior turno', value: '${stats.bestTurn}', icon: Icons.trending_up),
              _StatChip(label: 'Turni giocati', value: '${stats.totalTurns}', icon: Icons.repeat),
              _StatChip(label: 'Dardi totali', value: '${stats.totalDarts}', icon: Icons.arrow_right_alt),
              _StatChip(label: 'Leg vinti', value: '${stats.legsWon}', icon: Icons.sports_score),
              _StatChip(label: 'Set vinti', value: '${stats.setsWon}', icon: Icons.emoji_events),
            ],
          ),
        ],
      ),
    );
  }

  // DETTAGLIO MATCH con supporto TEAM
  Widget _buildMatchDetails(Match match, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📋 DETTAGLIO SET, LEG E ROUND',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...match.sets.asMap().entries.map((setEntry) {
          final setIndex = setEntry.key;
          final set = setEntry.value;
          return _buildSetCard(setIndex, set, players, isTeamMode, playerToTeam);
        }),
      ],
    );
  }

  Widget _buildSetCard(int setIndex, Set set, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    final winnerName = isTeamMode
        ? _getTeamName(set.winnerId, players, playerToTeam)
        : _getPlayerName(set.winnerId, players);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SET ${setIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🏆 Vincitore: $winnerName',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          ...set.legs.asMap().entries.map((legEntry) {
            final legIndex = legEntry.key;
            final leg = legEntry.value;
            return _buildLegCard(legIndex, leg, players, isTeamMode, playerToTeam);
          }),
        ],
      ),
    );
  }

  Widget _buildLegCard(int legIndex, Leg leg, List<PlayerInfo> players, bool isTeamMode, Map<String, String> playerToTeam) {
    final winnerName = isTeamMode
        ? _getTeamName(leg.winnerId, players, playerToTeam)
        : _getPlayerName(leg.winnerId, players);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LEG ${legIndex + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🏆 Vincitore: $winnerName',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${leg.winningScore} pts',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(
              '${leg.rounds.length} round giocati',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            dense: true,
            children: leg.rounds.map((round) => _buildRoundCard(round)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(Round round) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${round.roundNumber}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          ...round.turns.map((turn) => _buildTurnCard(turn)),
        ],
      ),
    );
  }

  Widget _buildTurnCard(PlayerTurn turn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: turn.isCheckout ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              turn.playerId,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(3, (i) {
                final hasDart = turn.throws.length > i;
                final dart = hasDart ? turn.throws[i] : null;
                return Expanded(
                  child: Text(
                    hasDart ? dart!.label : '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasDart ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                );
              }),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${turn.total} pts',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: turn.isCheckout ? Colors.green : Colors.black87,
                ),
              ),
              Text(
                '${turn.initialScore} → ${turn.score}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (turn.isCheckout)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check_circle, size: 14, color: Colors.green),
            ),
          if (turn.isBust)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.cancel, size: 14, color: Colors.red),
            ),
        ],
      ),
    );
  }

  // UTILITY FUNCTIONS
  String _getPlayerName(String? playerId, List<PlayerInfo> players) {
    if (playerId == null) return 'Sconosciuto';
    final player = players.firstWhere(
          (p) => p.id == playerId,
      orElse: () => PlayerInfo(id: playerId, name: playerId, isGuest: false, order: 0),
    );
    return player.name;
  }

  String _getTeamName(String? winnerId, List<PlayerInfo> players, Map<String, String> playerToTeam) {
    if (winnerId == null) return 'Sconosciuto';

    // Se winnerId è già un team ID (es. "T1", "T2")
    if (winnerId.startsWith('T')) {
      return winnerId;
    }

    // Se winnerId è un playerId, trova il suo team
    final teamId = playerToTeam[winnerId];
    return teamId ?? winnerId;
  }

  List<PlayerTurn> _getPlayerTurnsFromMatch(Match match, String playerId) {
    final turns = <PlayerTurn>[];
    for (final set in match.sets) {
      for (final leg in set.legs) {
        for (final round in leg.rounds) {
          for (final turn in round.turns) {
            if (turn.playerId == playerId) {
              turns.add(turn);
            }
          }
        }
      }
    }
    return turns;
  }

  Future<Map<String, PlayerStats>> _calculatePlayerStats(Match match, List<PlayerInfo> players) async {
    final stats = <String, PlayerStats>{};

    for (final player in players) {
      stats[player.id] = PlayerStats(playerId: player.id);
    }

    final isTeamMode = ref.read(roomNotifierProvider).teamSize > 1;

    for (final set in match.sets) {
      for (final leg in set.legs) {
        // ✅ LEG: il vincitore è un GIOCATORE (anche in team mode)
        // leg.winnerId è sempre l'ID del giocatore che ha fatto checkout
        if (leg.winnerId != null && stats.containsKey(leg.winnerId)) {
          stats[leg.winnerId!] = stats[leg.winnerId!]!.copyWith(
              legsWon: stats[leg.winnerId!]!.legsWon + 1
          );
        }

        for (final round in leg.rounds) {
          for (final turn in round.turns) {
            final playerStats = stats[turn.playerId]!;
            playerStats.totalTurns++;
            playerStats.totalScore += turn.total;
            playerStats.totalDarts += turn.throws.length;
            if (turn.isCheckout) playerStats.checkouts++;
            if (turn.total > playerStats.bestTurn) playerStats.bestTurn = turn.total;
            stats[turn.playerId] = playerStats;
          }
        }
      }
    }

    // ❌ SET: in team mode NON aggiorniamo setsWon per i singoli giocatori
    // i set sono vinti dai team, non dai giocatori
    if (!isTeamMode) {
      for (final set in match.sets) {
        if (set.winnerId != null && stats.containsKey(set.winnerId)) {
          stats[set.winnerId!] = stats[set.winnerId!]!.copyWith(
              setsWon: stats[set.winnerId!]!.setsWon + 1
          );
        }
      }
    }

    for (final entry in stats.entries) {
      final playerStats = entry.value;
      final avg = playerStats.totalDarts > 0
          ? (playerStats.totalScore / playerStats.totalDarts) * 3
          : 0.0;
      final checkoutPct = playerStats.totalTurns > 0
          ? (playerStats.checkouts / playerStats.totalTurns) * 100
          : 0.0;

      // ✅ In team mode, il vincitore del match è un TEAM
      // quindi nessun giocatore individuale è winner
      final isWinner = !isTeamMode && match.winnerId == entry.key;

      stats[entry.key] = playerStats.copyWith(
        average: avg,
        checkoutPercentage: checkoutPct,
        isWinner: isWinner,
      );
    }

    final matchRecord = await LocalMatchSyncService.instance.getById(match.id);

    for (final entry in stats.entries) {
      final player = players.firstWhere((p) => p.id == entry.key);
      if (!player.isGuest && matchRecord != null) {
        stats[entry.key] = entry.value.copyWith(syncStatus: matchRecord.syncStatus);
      } else {
        stats[entry.key] = entry.value.copyWith(syncStatus: null);
      }
    }

    return stats;
  }

  void _showDatabaseStructure(BuildContext context, Match match, String playerId, List<PlayerInfo> players) {
    // Variabile per tracciare la fonte dei dati (locale o db)
    bool useDbSource = false;
    // Variabile per memorizzare l'ID del match nel database
    String? dbMatchId;
    // Variabile per i dati caricati dal DB
    Map<String, dynamic>? dbStructure;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Header con switch
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storage, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Struttura dati salvata',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    useDbSource
                                        ? 'Fonte: DATABASE REMOTO'
                                        : 'Fonte: DATABASE LOCALE',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Switch per scegliere fonte dati
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.phone_android, size: 18, color: useDbSource ? Colors.white70 : Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Locale',
                                    style: TextStyle(
                                      color: useDbSource ? Colors.white70 : Colors.white,
                                      fontWeight: useDbSource ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: useDbSource,
                                onChanged: (value) async {
                                  setDialogState(() {
                                    useDbSource = value;
                                  });

                                  if (value && dbMatchId == null) {
                                    // Carica i dati dal database remoto
                                    setDialogState(() {
                                      dbStructure = null;
                                    });

                                    // Mostra indicatore di caricamento
                                    setDialogState(() {});

                                    // Recupera l'ID del match dal database
                                    final remoteMatchId = await _fetchRemoteMatchId(match.id);

                                    if (remoteMatchId != null) {
                                      dbMatchId = remoteMatchId;
                                      // Recupera la struttura completa dal database
                                      dbStructure = await _fetchRemoteMatchStructure(remoteMatchId, playerId, players);
                                    }

                                    setDialogState(() {});
                                  }
                                },
                                activeColor: Colors.white,
                                activeTrackColor: Colors.green,
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Database',
                                    style: TextStyle(
                                      color: useDbSource ? Colors.white : Colors.white70,
                                      fontWeight: useDbSource ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.cloud, size: 18, color: useDbSource ? Colors.white : Colors.white70),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (useDbSource && dbMatchId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'DB Match ID: ${dbMatchId!.substring(0, dbMatchId!.length > 12 ? 12 : dbMatchId!.length)}...',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Body con JSON formattato
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: useDbSource
                          ? (dbStructure != null
                          ? SelectableText(
                        _formatJson(dbStructure),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      )
                          : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Caricamento dati dal database...'),
                          ],
                        ),
                      ))
                          : SelectableText(
                        _buildLocalStructure(match, playerId, players),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          useDbSource
                              ? 'Dati recuperati dal database remoto (match ID: ${dbMatchId ?? "N/A"})'
                              : 'Solo turni del giocatore selezionato (fonte locale)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Chiudi'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// Funzione per recuperare l'ID del match nel database remoto
  Future<String?> _fetchRemoteMatchId(String localMatchId) async {
    try {
      // Forza la sincronizzazione
      await LocalMatchSyncService.instance.syncAll();

      // Cerca il record per localId (che ora è match.id)
      final record = await LocalMatchSyncService.instance.getById(localMatchId);

      if (record != null && record.remoteId != null) {
        debugPrint('✅ Remote ID trovato: ${record.remoteId} per localId: $localMatchId');
        return record.remoteId;
      }

      debugPrint('❌ Remote ID non trovato per localId: $localMatchId');
      return null;
    } catch (e) {
      debugPrint('❌ Errore nel recupero remoteId: $e');
      return null;
    }
  }

// Funzione per recuperare la struttura del match dal database remoto
  Future<Map<String, dynamic>?> _fetchRemoteMatchStructure(
      String remoteMatchId,
      String playerId,
      List<PlayerInfo> players
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ Utente non autenticato');
        return null;
      }

      final matchRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('matches')
          .doc(remoteMatchId);

      // 1. Recupera i dati base del match
      final matchDoc = await matchRef.get();
      if (!matchDoc.exists) {
        debugPrint('❌ Match non trovato su Firestore: $remoteMatchId');
        return null;
      }

      final matchData = matchDoc.data()!;

      // 2. Recupera l'intera gerarchia
      final matchSets = await _fetchFirestoreHierarchy(matchRef);

      // 3. Costruisci la struttura
      return {
        'match': {
          'id': remoteMatchId,
          'localId': matchData['matchId'],
          'source': 'DATABASE REMOTO (FIRESTORE)',
          'winnerId': matchData['winnerId'],
          'winnerName': matchData['winnerName'],
          'startTime': matchData['startTime']?.toString(),
          'endTime': matchData['endTime']?.toString(),
          'sets': matchSets.map((setMap) {
            return {
              'setNumber': setMap['setNumber'],
              'winnerId': setMap['winnerId'],
              'startTime': setMap['startTime']?.toString(),
              'endTime': setMap['endTime']?.toString(),
              'legs': (setMap['legs'] as List).map((legMap) {
                return {
                  'legNumber': legMap['legNumber'],
                  'winnerId': legMap['winnerId'],
                  'winningScore': legMap['winningScore'],
                  'startTime': legMap['startTime']?.toString(),
                  'endTime': legMap['endTime']?.toString(),
                  'rounds': (legMap['rounds'] as List).map((roundMap) {
                    return {
                      'roundNumber': roundMap['roundNumber'],
                      'timestamp': roundMap['timestamp']?.toString(),
                      'turns': (roundMap['turns'] as List)
                          .where((turn) => turn['playerId'] == playerId)
                          .map((turnMap) {
                        return {
                          'playerId': turnMap['playerId'],
                          'turnNumber': turnMap['turnNumber'],
                          'throws': (turnMap['throws'] as List).map((dartMap) {
                            return {
                              'dartNumber': dartMap['dartNumber'],
                              'target': dartMap['target'],
                              'multiplier': dartMap['multiplier'],
                              'score': dartMap['score'],
                              'label': _dartToLabel(dartMap),
                              'timestamp': dartMap['timestamp']?.toString(),
                            };
                          }).toList(),
                          'total': turnMap['total'],
                          'initialScore': turnMap['initialScore'],
                          'score': turnMap['score'],
                          'isBust': turnMap['isBust'],
                          'isCheckout': turnMap['isCheckout'],
                        };
                      }).toList(),
                    };
                  }).toList(),
                };
              }).toList(),
            };
          }).toList(),
        },
      };
    } catch (e) {
      debugPrint('❌ Errore nel recupero struttura remota: $e');
      return null;
    }
  }

}




class _SyncStatusWidget extends StatefulWidget {
  final LocalMatchSyncStatus? initialStatus;
  final String matchId;
  final String playerId;
  final List<PlayerInfo> players;
  final VoidCallback onTap;

  const _SyncStatusWidget({
    required this.initialStatus,
    required this.matchId,
    required this.playerId,
    required this.players,
    required this.onTap,
  });

  @override
  State<_SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<_SyncStatusWidget> {
  LocalMatchSyncStatus? _currentStatus;
  late final StreamSubscription _syncSubscription;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;

    // 🔥 ASCOLTA LO STREAM DI SINCRONIZZAZIONE
    _syncSubscription = LocalMatchSyncService.instance.onSyncStatusChanged.listen((statusMap) {
      if (mounted && statusMap.containsKey(widget.matchId)) {
        setState(() {
          _currentStatus = statusMap[widget.matchId];
        });
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;

    switch (_currentStatus) {
      case LocalMatchSyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        tooltip = 'Salvato sul cloud';
        break;
      case LocalMatchSyncStatus.syncing:
        icon = Icons.cloud_sync;
        color = Colors.blue;
        tooltip = 'Sincronizzazione in corso...';
        break;
      case LocalMatchSyncStatus.pending:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        tooltip = 'In attesa di sincronizzazione';
        break;
      case LocalMatchSyncStatus.failed:
        icon = Icons.cloud_off;
        color = Colors.red;
        tooltip = 'Sincronizzazione fallita - Tocca per riprovare';
        break;
      default:
        icon = Icons.storage;
        color = Colors.grey;
        tooltip = 'Mostra struttura dati';
    }

    return GestureDetector(
      onTap: _currentStatus == LocalMatchSyncStatus.failed
          ? () => _retrySync(context)
          : widget.onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (_currentStatus == LocalMatchSyncStatus.syncing) ...[
                const SizedBox(width: 4),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retrySync(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Riprovo sincronizzazione...'), duration: Duration(seconds: 1)),
    );

    await LocalMatchSyncService.instance.syncAll();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronizzazione completata'), duration: Duration(seconds: 1)),
      );
      widget.onTap();
    }
  }
}

/// Recupera la gerarchia completa da Firestore
Future<List<Map<String, dynamic>>> _fetchFirestoreHierarchy(DocumentReference matchRef) async {
  final matchSets = <Map<String, dynamic>>[];

  final setsSnapshot = await matchRef
      .collection('sets')
      .orderBy('setNumber')
      .get();

  for (final setDoc in setsSnapshot.docs) {
    final setData = setDoc.data();
    final legs = <Map<String, dynamic>>[];

    final legsSnapshot = await setDoc.reference
        .collection('legs')
        .orderBy('legNumber')
        .get();

    for (final legDoc in legsSnapshot.docs) {
      final legData = legDoc.data();
      final rounds = <Map<String, dynamic>>[];

      final roundsSnapshot = await legDoc.reference
          .collection('rounds')
          .orderBy('roundNumber')
          .get();

      for (final roundDoc in roundsSnapshot.docs) {
        final roundData = roundDoc.data();
        final turns = <Map<String, dynamic>>[];

        final turnsSnapshot = await roundDoc.reference
            .collection('turns')
            .orderBy('turnNumber')
            .get();

        for (final turnDoc in turnsSnapshot.docs) {
          final turnData = turnDoc.data();
          turns.add(turnData);
        }

        rounds.add({
          'roundNumber': roundData['roundNumber'],
          'timestamp': roundData['timestamp'],
          'turns': turns,
        });
      }

      legs.add({
        'legNumber': legData['legNumber'],
        'winnerId': legData['winnerId'],
        'winningScore': legData['winningScore'],
        'startTime': legData['startTime'],
        'endTime': legData['endTime'],
        'rounds': rounds,
      });
    }

    matchSets.add({
      'setNumber': setData['setNumber'],
      'winnerId': setData['winnerId'],
      'startTime': setData['startTime'],
      'endTime': setData['endTime'],
      'legs': legs,
    });
  }

  return matchSets;
}

/// Helper per convertire un dart in label leggibile
String _dartToLabel(Map<String, dynamic> dartMap) {
  final multiplier = dartMap['multiplier'];
  final target = dartMap['target'];

  if (multiplier == 1) return target.toString();
  if (multiplier == 2) return 'D$target';
  if (multiplier == 3) return 'T$target';
  return 'Miss';

}

// Funzione per costruire la struttura locale (estrarre dal codice esistente)
String _buildLocalStructure(Match match, String playerId, List<PlayerInfo> players) {
  final structure = <String, dynamic>{
    'match': {
      'id': match.id,
      'source': 'DATABASE LOCALE (IN-MEMORY)',
      'winnerId': match.winnerId,
      'startTime': match.startTime.toIso8601String(),
      'endTime': match.endTime?.toIso8601String(),
      'sets': match.sets.map((set) {
        return {
          'setNumber': set.setNumber,
          'winnerId': set.winnerId,
          'startTime': set.startTime.toIso8601String(),
          'endTime': set.endTime?.toIso8601String(),
          'legs': set.legs.map((leg) {
            return {
              'legNumber': leg.legNumber,
              'winnerId': leg.winnerId,
              'winningScore': leg.winningScore,
              'startTime': leg.startTime.toIso8601String(),
              'endTime': leg.endTime?.toIso8601String(),
              'rounds': leg.rounds.map((round) {
                return {
                  'roundNumber': round.roundNumber,
                  'timestamp': round.timestamp.toIso8601String(),
                  'turns': round.turns.where((turn) => turn.playerId == playerId).map((turn) {
                    return {
                      'playerId': turn.playerId,
                      'turnNumber': turn.turnNumber,
                      'throws': turn.throws.map((dart) {
                        return {
                          'dartNumber': dart.dartNumber,
                          'target': dart.target,
                          'multiplier': dart.multiplier,
                          'score': dart.score,
                          'label': dart.label,
                          'timestamp': dart.timestamp.toIso8601String(),
                        };
                      }).toList(),
                      'total': turn.total,
                      'initialScore': turn.initialScore,
                      'score': turn.score,
                      'isBust': turn.isBust,
                      'isCheckout': turn.isCheckout,
                    };
                  }).toList(),
                };
              }).toList(),
            };
          }).toList(),
        };
      }).toList(),
    },
  };

  return _formatJson(structure);
}

String _formatJson(dynamic json) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(json);
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class PlayerStats {
  final String playerId;
  int totalTurns;
  int totalScore;
  int totalDarts;
  int checkouts;
  int bestTurn;
  int legsWon;
  int setsWon;
  double average;
  double checkoutPercentage;
  bool isWinner;
  LocalMatchSyncStatus? syncStatus;  // ← AGGIUNGI QUESTO

  PlayerStats({
    required this.playerId,
    this.totalTurns = 0,
    this.totalScore = 0,
    this.totalDarts = 0,
    this.checkouts = 0,
    this.bestTurn = 0,
    this.legsWon = 0,
    this.setsWon = 0,
    this.average = 0.0,
    this.checkoutPercentage = 0.0,
    this.isWinner = false,
    this.syncStatus,  // ← AGGIUNGI QUESTO
  });

  PlayerStats copyWith({
    int? totalTurns,
    int? totalScore,
    int? totalDarts,
    int? checkouts,
    int? bestTurn,
    int? legsWon,
    int? setsWon,
    double? average,
    double? checkoutPercentage,
    bool? isWinner,
    LocalMatchSyncStatus? syncStatus,  // ← AGGIUNGI QUESTO
  }) {
    return PlayerStats(
      playerId: playerId,
      totalTurns: totalTurns ?? this.totalTurns,
      totalScore: totalScore ?? this.totalScore,
      totalDarts: totalDarts ?? this.totalDarts,
      checkouts: checkouts ?? this.checkouts,
      bestTurn: bestTurn ?? this.bestTurn,
      legsWon: legsWon ?? this.legsWon,
      setsWon: setsWon ?? this.setsWon,
      average: average ?? this.average,
      checkoutPercentage: checkoutPercentage ?? this.checkoutPercentage,
      isWinner: isWinner ?? this.isWinner,
      syncStatus: syncStatus ?? this.syncStatus,  // ← AGGIUNGI QUESTO
    );
  }
}