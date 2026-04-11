import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'room_data.dart';
import 'room_repository.dart';
import 'local_match_storage.dart';

class RoomResultPage extends StatelessWidget {
  final RoomData data;
  final RoomRepository repo;
  final VoidCallback onClose;

  const RoomResultPage({
    super.key,
    required this.data,
    required this.repo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final playerNames = _buildPlayerNames(data.players);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 900),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _header(context),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: loadMatchResults(data),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final playerResults = snapshot.data!;
                      if (playerResults.isEmpty) {
                        return const Center(
                          child: Text('Nessun risultato disponibile'),
                        );
                      }

                      final summary = buildResultSummary(
                        data: data,
                        playerResults: playerResults,
                        playerNames: playerNames,
                      );

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _winnerCard(summary),
                          const SizedBox(height: 12),
                          _bestStatsCard(summary),
                          const SizedBox(height: 12),
                          _rankingCard(summary),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Risultati',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _winnerCard(Map summary) {
    final winners = List<Map<String, dynamic>>.from(summary['winners']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('VINCITORE'),
            const SizedBox(height: 8),
            Text(
              winners.map((e) => e['name']).join(', '),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bestStatsCard(Map summary) {
    final bestAvg = summary['bestAvg'];
    final bestCheckout = summary['bestCheckout'];
    final bestTurn = summary['bestTurn'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Best Avg', '${bestAvg['name']} • ${bestAvg['avg'].toStringAsFixed(1)}'),
            _row('Best Checkout', '${bestCheckout['name']} • ${bestCheckout['bestCheckout']}'),
            _row('Best Turn', '${bestTurn['name']} • ${bestTurn['bestTurn']}'),
          ],
        ),
      ),
    );
  }

  Widget _rankingCard(Map summary) {
    final ranking = List<Map<String, dynamic>>.from(summary['ranking']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(ranking.length, (i) {
            final p = ranking[i];

            return ListTile(
              leading: Text('#${i + 1}'),
              title: Text(p['name']),
              subtitle: Text(
                'Set ${p['setsWon']} • Leg ${p['legsWon']} • Score ${p['remaining']}',
              ),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Avg ${p['avg'].toStringAsFixed(1)}'),
                  Text('Best ${p['bestTurn']}'),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _row(String l, String v) {
    return Row(
      children: [
        Expanded(child: Text(l)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> loadMatchResults(RoomData data) async {
    final matchId = data.matchId;
    if (matchId == null) return [];

    final db = FirebaseFirestore.instance;
    final local = LocalMatchStorage.get(matchId);

    final localPlayers = local != null
        ? Map<String, dynamic>.from(local['players'] ?? {})
        : {};

    final results = <Map<String, dynamic>>[];

    results.addAll(localPlayers.values.map((e) => Map<String, dynamic>.from(e)));

    for (final p in data.players) {
      final uid = p['id'];
      final isGuest = p['isGuest'] == true;

      if (uid == null || isGuest) continue;
      if (localPlayers.containsKey(uid)) continue;

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('match_legs')
          .doc(matchId)
          .get();

      if (!doc.exists) continue;

      results.add(Map<String, dynamic>.from(doc.data()!));
    }

    return results;
  }
}

Map<String, String> _buildPlayerNames(List<Map<String, dynamic>> players) {
  return {
    for (var p in players)
      p['id']: p['name'] ?? p['id'],
  };
}

Map<String, dynamic> buildResultSummary({
  required RoomData data,
  required List<Map<String, dynamic>> playerResults,
  required Map<String, String> playerNames,
}) {
  final perPlayer = <Map<String, dynamic>>[];

  for (final r in playerResults) {
    final id = r['playerId'];
    final name = playerNames[id] ?? id;

    final sets = List<Map<String, dynamic>>.from(r['sets'] ?? []);

    int setsWon = 0;
    int legsWon = 0;
    int total = 0;
    int turns = 0;
    int bestTurn = 0;
    int bestCheckout = 0;

    int lastStartScore = 0;
    bool didCheckout = false;

    for (final set in sets) {
      final legs = List<Map<String, dynamic>>.from(set['legs'] ?? []);
      int legCount = 0;

      for (final leg in legs) {
        final turnsList =
        List<Map<String, dynamic>>.from(leg['turns'] ?? []);
        bool won = false;

        for (final t in turnsList) {
          final val = _toInt(t['total']);
          final kind = t['endKind'];

          total += val;
          turns++;

          if (val > bestTurn) bestTurn = val;

          if (kind == 'checkout') {
            won = true;
            didCheckout = true;

            if (val > bestCheckout) {
              bestCheckout = val;
            }
          }

          // ✅ QUESTO È IL DATO GIUSTO
          if (t['startScore'] != null) {
            lastStartScore = _toInt(t['startScore']);
          }
        }

        if (won) {
          legsWon++;
          legCount++;
        }
      }

      if (legCount >= data.matchConfig.legsToWin) {
        setsWon++;
      }
    }

    final remaining = didCheckout ? 0 : lastStartScore;

    perPlayer.add({
      'playerId': id,
      'name': name,
      'setsWon': setsWon,
      'legsWon': legsWon,
      'avg': turns == 0 ? 0.0 : total / turns,
      'bestTurn': bestTurn,
      'bestCheckout': bestCheckout,
      'remaining': remaining,
    });
  }

  // ======================
  // TEAM MODE
  // ======================
  if (data.teamSize > 1) {
    final teams = data.buildTeams();
    final teamStats = <Map<String, dynamic>>[];

    for (int i = 0; i < teams.length; i++) {
      final team = teams[i];

      int setsWon = 0;
      int legsWon = 0;
      int remaining = 0;
      final members = <String>[];

      for (final p in team) {
        final id = p['id'];

        final stats = perPlayer.firstWhere(
              (e) => e['playerId'] == id,
          orElse: () => {},
        );

        if (stats.isEmpty) continue;

        setsWon += _toInt(stats['setsWon']);
        legsWon += _toInt(stats['legsWon']);
        remaining += _toInt(stats['remaining']);

        members.add(playerNames[id] ?? id);
      }

      teamStats.add({
        'teamId': 'team_${i + 1}',
        'name': 'Team ${i + 1}',
        'members': members,
        'setsWon': setsWon,
        'legsWon': legsWon,
        'remaining': remaining,
      });
    }

    teamStats.sort((a, b) {
      final s = _toInt(b['setsWon']).compareTo(_toInt(a['setsWon']));
      if (s != 0) return s;

      final l = _toInt(b['legsWon']).compareTo(_toInt(a['legsWon']));
      if (l != 0) return l;

      return _toInt(a['remaining']).compareTo(_toInt(b['remaining']));
    });

    final top = teamStats.first;

    final winners = teamStats.where((t) =>
    _toInt(t['setsWon']) == _toInt(top['setsWon']) &&
        _toInt(t['legsWon']) == _toInt(top['legsWon']) &&
        _toInt(t['remaining']) == _toInt(top['remaining'])).toList();

    final bestAvg =
    perPlayer.reduce((a, b) => _toNum(a['avg']) >= _toNum(b['avg']) ? a : b);

    final bestCheckout =
    perPlayer.reduce((a, b) =>
    _toInt(a['bestCheckout']) >= _toInt(b['bestCheckout']) ? a : b);

    final bestTurn =
    perPlayer.reduce((a, b) =>
    _toInt(a['bestTurn']) >= _toInt(b['bestTurn']) ? a : b);

    return {
      'ranking': teamStats,
      'winners': winners,
      'bestAvg': bestAvg,
      'bestCheckout': bestCheckout,
      'bestTurn': bestTurn,
      'isTeamRanking': true,
    };
  }

  // ======================
  // SOLO PLAYER
  // ======================
  perPlayer.sort((a, b) {
    final s = _toInt(b['setsWon']).compareTo(_toInt(a['setsWon']));
    if (s != 0) return s;

    final l = _toInt(b['legsWon']).compareTo(_toInt(a['legsWon']));
    if (l != 0) return l;

    return _toInt(a['remaining']).compareTo(_toInt(b['remaining']));
  });

  final top = perPlayer.first;

  final winners = perPlayer.where((p) =>
  _toInt(p['setsWon']) == _toInt(top['setsWon']) &&
      _toInt(p['legsWon']) == _toInt(top['legsWon']) &&
      _toInt(p['remaining']) == _toInt(top['remaining'])).toList();

  final bestAvg =
  perPlayer.reduce((a, b) => _toNum(a['avg']) >= _toNum(b['avg']) ? a : b);

  final bestCheckout =
  perPlayer.reduce((a, b) =>
  _toInt(a['bestCheckout']) >= _toInt(b['bestCheckout']) ? a : b);

  final bestTurn =
  perPlayer.reduce((a, b) =>
  _toInt(a['bestTurn']) >= _toInt(b['bestTurn']) ? a : b);

  return {
    'ranking': perPlayer,
    'winners': winners,
    'bestAvg': bestAvg,
    'bestCheckout': bestCheckout,
    'bestTurn': bestTurn,
    'isTeamRanking': false,
  };
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toNum(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}