import 'package:darts/features/room_v2/core/room_match_engine.dart';
import 'package:darts/features/room_v2/core/room_match_engine_history.dart';
import 'package:darts/features/room_v2/core/room_match_engine_state.dart';
import 'package:darts/features/room_v2/games/cricket_engine.dart';
import 'package:darts/features/room_v2/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:darts/features/room_v2/games_darts.dart';
import 'package:darts/features/room_v2/room_current_user.dart';
import 'package:darts/features/room_v2/room_data.dart';

import 'checkout_resolver.dart';

class RoomMatchEngineView extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;

  const RoomMatchEngineView({
    super.key,
    required this.data,
    required this.repo,
  });

  Widget? _buildWinnerOverlay(BuildContext context) {
    final uid = RoomCurrentUser.current.uid;
    final winner = buildWinnerOverlayData(data, uid);
    if (winner == null) return null;

    final isCricket = data.game.type == GameType.cricket;

    final rawTitle = winner['title'] as String? ?? '';

    final title = isCricket && rawTitle.toUpperCase().contains('CHECKOUT')
        ? 'WIN'
        : rawTitle;

    final name = winner['name'] as String? ?? '-';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await repo.enqueue(() async {
                            final newState =
                            RoomMatchEngineLogic.undoLastThrow(repo.current!);
                            await repo.update(newState);
                          });
                        },
                        child: const Text('Undo'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await repo.saveMatchResults(data);

                          await Future.delayed(const Duration(milliseconds: 800));

                          await repo.enqueue(() async {
                            await repo.update(
                              repo.current!.copyWith(
                                phase: RoomPhase.lobby,
                              ),
                            );
                          });
                        },
                        child: const Text('Vai ai risultati'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.phase == RoomPhase.lobby) {
      return const Center(
        child: Text('ENGINE NON ATTIVO'),
      );
    }

    final winnerOverlay = _buildWinnerOverlay(context);

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = 1100.0;
            final contentWidth =
            constraints.maxWidth > maxWidth ? maxWidth : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  children: [
                    /// SINISTRA (ridimensionabile)
                    SizedBox(
                      width: contentWidth < 700 ? 0 : 280,
                      child: contentWidth < 700
                          ? const SizedBox.shrink()
                          : _CurrentPlayerPanel(data: data),
                    ),

                    /// DESTRA (main area)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                              children: [
                                const SizedBox(height: 12),
                                ..._buildUnifiedList(data),
                              ],
                            ),
                          ),
                          _LiveTurnBar(data: data),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        if (winnerOverlay != null) winnerOverlay,
      ],
    );
  }
}

List<Widget> _buildUnifiedList(RoomData data) {
  if (data.teamSize > 1) {
    final teams = data.buildTeams();

    return List.generate(teams.length, (i) {
      final team = teams[i];

      final teamScore = team.fold<int>(
        0,
            (sum, p) => sum + ((p['score'] as int?) ?? 0),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'TEAM ${i + 1}  •  $teamScore',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...team.map((p) => _PlayerCard(player: p, data: data)),
        ],
      );
    });
  }

  return data.players.map((p) => _PlayerCard(player: p, data: data)).toList();
}

class _PlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final RoomData data;

  const _PlayerCard({
    required this.player,
    required this.data,
  });

  Map<String, dynamic>? _getLastTurn(String playerId) {
    if (data.match.isEmpty) return null;

    final lastSet = data.match.last;
    final legs = List<Map<String, dynamic>>.from(lastSet['legs'] ?? []);
    if (legs.isEmpty) return null;

    final lastLeg = legs.last;
    final turns = List<Map<String, dynamic>>.from(lastLeg['turns'] ?? []);

    for (int i = turns.length - 1; i >= 0; i--) {
      final t = turns[i];
      if (t['playerId'] == playerId) return t;
    }

    return null;
  }

  String _buildLabel(Map<String, dynamic>? turn) {
    if (turn == null) return '';

    final inputMode = turn['inputMode'];
    if (inputMode == 'total') return 'TOTAL';

    final throws = List<Map<String, dynamic>>.from(turn['throws'] ?? []);
    if (throws.isEmpty) return '';

    final labels = throws.map((t) {
      final meta = t['label'];
      if (meta != null) return meta.toString();

      final n = t['number'];
      final m = t['multiplier'];

      if (n == null) return 'MISS';
      if (m == 3) return 'T$n';
      if (m == 2) return 'D$n';
      return '$n';
    }).toList();

    return labels.join(' ');
  }

  int _buildTotal(Map<String, dynamic>? turn) {
    if (turn == null) return 0;

    if (turn['inputMode'] == 'total') {
      return (turn['total'] as int?) ?? 0;
    }

    final throws = List<Map<String, dynamic>>.from(turn['throws'] ?? []);
    final isCricket = data.game.type == GameType.cricket;

    return isCricket
        ? throws.fold<int>(0, (s, t) => s + ((t['marks'] as int?) ?? 0))
        : throws.fold<int>(0, (s, t) => s + ((t['appliedValue'] as int?) ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final isTurn = player['turn'] == true;

    final name = player['name'] ?? '-';
    final score = player['score'] ?? 0;

    final legs = player['legs'] ?? 0;
    final sets = player['sets'] ?? 0;

    final lastTurn = _getLastTurn(player['id']);
    final label = _buildLabel(lastTurn);
    final total = _buildTotal(lastTurn);
    final endKind = lastTurn?['endKind'];

    final bg = isTurn ? const Color(0xFF1E293B) : const Color(0xFF111827);
    final border = isTurn ? Colors.blueAccent : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.2),
      ),
      child: SizedBox(
        height: 84,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// 🔹 COLONNA 1 — NOME + STORICO (PROPORZIONI PERFETTE)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    /// RIGA 1 — NOME
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            if (isTurn)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    /// RIGA 2 — STORICO (DARTS + RISULTATO)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    endKind == 'checkout'
                                        ? (data.game.type == GameType.cricket ? 'WIN' : '$total')
                                        : (data.game.type != GameType.cricket && endKind == 'bust')
                                        ? 'BUST'
                                        : '$total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: endKind == 'checkout'
                                          ? Colors.greenAccent
                                          : (data.game.type != GameType.cricket &&
                                          endKind == 'bust')
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 🔹 SET
            _sideCellTight(
              label: 'set',
              value: sets,
              max: data.matchConfig.setsToWin,
            ),

            /// 🔹 LEG
            _sideCellTight(
              label: 'leg',
              value: legs,
              max: data.matchConfig.legsToWin,
            ),

            /// 🔹 SCORE (DOMINANTE)
            Container(
              width: 78,
              alignment: Alignment.centerRight,
              child: Text(
                '$score',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
// SOSTITUISCI SOLO QUESTA FUNZIONE

  Widget _sideCellTight({
    required String label,
    required int value,
    required int max,
  }) {
    return Container(
      width: 58,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '/$max',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _statBlock({
    required int value,
    required int max,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          '/$max',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}


class _CurrentPlayerPanel extends StatelessWidget {
  final RoomData data;

  const _CurrentPlayerPanel({required this.data});

  Map<String, dynamic>? _currentPlayer() {
    for (final p in data.players) {
      if (p['turn'] == true) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> _buildTurns() {
    if (data.match.isEmpty) return [];

    final lastSet = data.match.last;
    final legs = List<Map<String, dynamic>>.from(lastSet['legs'] ?? []);
    if (legs.isEmpty) return [];

    final lastLeg = legs.last;
    final turns = List<Map<String, dynamic>>.from(lastLeg['turns'] ?? []);

    final player = _currentPlayer();
    if (player == null) return [];

    final id = player['id'];

    final result = <Map<String, dynamic>>[];

    final isCricket = data.game.type == GameType.cricket;

    int runningScore = isCricket
        ? (player['cricketScore'] as int? ?? 0)
        : (data.game.startingScore ?? 501);

    for (final t in turns) {
      if (t['playerId'] != id) continue;

      final total = (t['total'] as int?) ?? 0;
      final endKind = t['endKind'];

      if (!isCricket && endKind == 'bust') {
        result.add({
          'score': runningScore,
          'total': total,
          'type': 'bust',
        });
      } else {
        if (!isCricket) {
          runningScore -= total;
        } else {
          runningScore += total;
        }

        result.add({
          'score': runningScore,
          'total': total,
          'type': endKind,
        });
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final player = _currentPlayer();

    if (player == null) {
      return const Center(child: Text('NO PLAYER'));
    }

    final isCricket = data.game.type == GameType.cricket;

    final name = player['name'] ?? '-';
    final score = isCricket
        ? (player['cricketScore'] ?? 0)
        : (player['score'] ?? 0);

    final turns = _buildTurns();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: turns.length,
              itemBuilder: (context, i) {
                final t = turns[i];
                final score = t['score'];
                final total = t['total'];
                final type = t['type'];

                Color? color;

                if (!isCricket && type == 'bust') {
                  color = Colors.red;
                } else if (!isCricket && type == 'checkout') {
                  color = Colors.green;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$score',
                          style: TextStyle(color: color),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$total',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: color),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildPlayerOrTeamList(RoomData data) {
  if (data.teamSize > 1) {
    return _buildTeams(data);
  }
  return _buildSinglePlayers(data);
}

// 🟡 SINGLE PLAYER MODE
List<Widget> _buildSinglePlayers(RoomData data) {
  Map<String, dynamic>? _getLastTurn(String playerId) {
    if (data.match.isEmpty) return null;

    final lastSet = data.match.last;
    final legs = List<Map<String, dynamic>>.from(lastSet['legs'] ?? []);
    if (legs.isEmpty) return null;

    final lastLeg = legs.last;
    final turns = List<Map<String, dynamic>>.from(lastLeg['turns'] ?? []);

    for (int i = turns.length - 1; i >= 0; i--) {
      final t = turns[i];
      if (t['playerId'] == playerId) return t;
    }

    return null;
  }

  String _buildLabel(Map<String, dynamic>? turn) {
    if (turn == null) return '';

    final inputMode = turn['inputMode'];

    if (inputMode == 'total') {
      return 'TOTAL';
    }

    final throws = List<Map<String, dynamic>>.from(turn['throws'] ?? []);
    if (throws.isEmpty) return '';

    final labels = throws.map((t) {
      final meta = t['label'];
      if (meta != null) return meta.toString();

      final n = t['number'];
      final m = t['multiplier'];

      if (n == null) return 'MISS';
      if (m == 3) return 'T$n';
      if (m == 2) return 'D$n';
      return '$n';
    }).toList();

    return labels.join(' ');
  }

  int _buildTotal(Map<String, dynamic>? turn) {
    if (turn == null) return 0;

    final inputMode = turn['inputMode'];

    if (inputMode == 'total') {
      return (turn['total'] as int?) ?? 0;
    }

    final throws = List<Map<String, dynamic>>.from(turn['throws'] ?? []);
    return throws.fold<int>(
      0,
          (s, t) => s + ((t['appliedValue'] as int?) ?? 0),
    );
  }

  String? _buildEndKind(Map<String, dynamic>? turn) {
    if (turn == null) return null;
    return turn['endKind'];
  }

  return data.players.map((p) {
    final isTurn = p['turn'] == true;
    final hasPlayed = (p['dart'] ?? 0) == 0 && !isTurn;

    final name = p['name'] ?? '-';
    final score = p['score'] ?? 0;
    final legs = p['legs'] ?? 0;
    final sets = p['sets'] ?? 0;

    final playerId = p['id'];
    final lastTurn = _getLastTurn(playerId);

    final label = _buildLabel(lastTurn);
    final total = _buildTotal(lastTurn);
    final endKind = _buildEndKind(lastTurn);

    return Transform.scale(
      scale: isTurn ? 1.05 : 1,
      child: Opacity(
        opacity: hasPlayed ? 0.5 : 1,
        child: Card(
          color: isTurn ? Colors.blue.withOpacity(0.1) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'S $sets/${data.matchConfig.setsToWin}  •  L $legs/${data.matchConfig.legsToWin}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),

                if (lastTurn != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      Text(
                        endKind == 'bust'
                            ? 'BUST'
                            : endKind == 'checkout'
                            ? '$total'
                            : '$total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: endKind == 'checkout'
                              ? Colors.green
                              : endKind == 'bust'
                              ? Colors.red
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }).toList();
}

// 🟣 TEAM MODE
List<Widget> _buildTeams(RoomData data) {
  final teams = data.buildTeams();

  return List.generate(teams.length, (i) {
    final team = teams[i];

    final teamScore = team.fold<int>(
      0,
          (sum, p) => sum + ((p['score'] as int?) ?? 0),
    );

    final legs = (team.first['legs'] as int?) ?? 0;
    final sets = (team.first['sets'] as int?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TEAM HEADER
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'TEAM ${i + 1}  •  $teamScore',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // PLAYERS
        ...team.map((p) {
          final isTurn = p['turn'] == true;
          final hasPlayed = (p['dart'] ?? 0) == 0 && !isTurn;

          final name = p['name'] ?? '-';
          final score = p['score'] ?? 0;

          return Transform.scale(
            scale: isTurn ? 1.05 : 1,
            child: Opacity(
              opacity: hasPlayed ? 0.5 : 1,
              child: Card(
                color: isTurn
                    ? Colors.blue.withOpacity(0.1)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(child: Text(name)),
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // TEAM PROGRESS
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'SET $sets/${data.matchConfig.setsToWin}  •  LEG $legs/${data.matchConfig.legsToWin}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  });
}

class _CricketPlayerStats extends StatelessWidget {
  final Map<String, dynamic> player;
  final List<Map<String, dynamic>> allPlayers;

  const _CricketPlayerStats({
    required this.player,
    required this.allPlayers,
  });

  static const targets = ['20', '19', '18', '17', '16', '15', '25'];

  @override
  Widget build(BuildContext context) {
    final cricket = Map<String, dynamic>.from(player['cricket'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        /// 🔴 NUMERI IN UNA RIGA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: targets
              .map(
                (t) => Expanded(
              child: Center(
                child: Text(
                  t == '25' ? 'B' : t,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
              .toList(),
        ),

        const SizedBox(height: 4),

        /// 🟢 SEGNI SOTTO (UNA RIGA)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: targets.map((t) {
            final value = (cricket[t] as int?) ?? 0;

            final allOpened = allPlayers.every((p) {
              final c = Map<String, dynamic>.from(p['cricket'] ?? {});
              return (c[t] as int? ?? 0) >= 3;
            });

            final isClosed = allOpened;

            return Expanded(
              child: Center(
                child: _markStack(value, isClosed),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _markStack(int value, bool isClosed) {
    final color = isClosed ? Colors.red : Colors.green;

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (value >= 1)
            Transform.rotate(
              angle: 0.8,
              child: Icon(
                Icons.remove,
                size: 18,
                color: color,
              ),
            ),
          if (value >= 2)
            Transform.rotate(
              angle: -0.8,
              child: Icon(
                Icons.remove,
                size: 18,
                color: color,
              ),
            ),
          if (value >= 3)
            Icon(
              Icons.radio_button_unchecked,
              size: 16,
              color: color,
            ),
        ],
      ),
    );
  }
}

class _LiveTurnBar extends StatelessWidget {
  final RoomData data;

  const _LiveTurnBar({required this.data});

  Map<String, dynamic>? _currentPlayer() {
    for (final p in data.players) {
      if (p['turn'] == true) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final player = _currentPlayer();
    if (player == null) return const SizedBox.shrink();

    final inputMode = player['inputMode'] ?? 'dart';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      ),
      child: inputMode == 'total'
          ? _TotalView(player: player)
          : _DartView(
        player: player,
        data: data,
      ),
    );
  }
}

class _DartView extends StatelessWidget {
  final Map<String, dynamic> player;
  final RoomData data;

  const _DartView({
    required this.player,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {

    final raw = List<Map<String, dynamic>>.from(player['throws'] ?? []);

    final darts = List.generate(3, (i) {
      if (i >= raw.length) return '-';

      final t = raw[i];

      final n = t['number'];
      final m = t['multiplier'];

      if (n == null) return 'MISS';
      if (m == 3) return 'T$n';
      if (m == 2) return 'D$n';
      return '$n';
    });
    final cannotCheckout = player['cannotCheckout'] == true;

    final isCricket = (player['cricket'] != null);

    final total = isCricket
        ? raw.fold<int>(
      0,
          (s, t) => s + ((t['marks'] as int?) ?? 0),
    )
        : raw.fold<int>(
      0,
          (s, t) => s + ((t['appliedValue'] as int?) ?? 0),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final value = darts[i];
            final isReal = i < (player['dart'] ?? 0);

            return Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isReal ? Colors.blue : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    color: isReal ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          (isCricket)
              ? 'TOT $total'
              : (cannotCheckout ? 'NON PUOI CHIUDERE' : 'TOT $total'),
          style: TextStyle(
            color: cannotCheckout ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
class _TotalView extends StatelessWidget {
  final Map<String, dynamic> player;

  const _TotalView({required this.player});

  @override
  Widget build(BuildContext context) {
    final raw = List<Map<String, dynamic>>.from(player['throws'] ?? []);

    final isCricket = (player['cricket'] != null);

    final total = isCricket
        ? raw.fold<int>(
      0,
          (s, t) => s + ((t['marks'] as int?) ?? 0),
    )
        : raw.fold<int>(
      0,
          (s, t) => s + ((t['appliedValue'] as int?) ?? 0),
    );

    final isBust = player['pendingBust'] == true;
    final isCheckout = !isCricket && player['pendingCheckout'] == true;

    final cannotCheckout = player['cannotCheckout'] == true;

    final hasValue = raw.isNotEmpty;

    final label = !hasValue
        ? '-'
        : isBust
        ? 'BUST'
        : '$total';

    final color = cannotCheckout
        ? Colors.red
        : isBust
        ? Colors.red
        : (isCheckout && !isCricket)
        ? Colors.green
        : hasValue
        ? Colors.white
        : Colors.white38;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasValue ? Colors.blue : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!isCricket && cannotCheckout) ...[
            const SizedBox(height: 6),
            const Text(
              'NON PUOI CHIUDERE',
              style: TextStyle(color: Colors.red),
            ),
          ]
        ],
      ),
    );
  }
}