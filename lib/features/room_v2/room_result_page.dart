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
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 900),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Result',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: loadMatchResults(data),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final players = snapshot.data!;

                        if (players.isEmpty) {
                          return const Center(
                            child: Text('Nessun dato disponibile'),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: players.map((p) {
                            final playerId =
                                p['playerId']?.toString() ?? 'UNKNOWN';
                            final sets = List<Map<String, dynamic>>.from(
                              p['sets'] ?? const [],
                            );

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PLAYER: $playerId'),
                                    const SizedBox(height: 8),
                                    ...sets.map((set) {
                                      final setNumber = set['setNumber'];
                                      final legs =
                                      List<Map<String, dynamic>>.from(
                                        set['legs'] ?? const [],
                                      );

                                      return Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text('SET $setNumber'),
                                          ...legs.map((leg) {
                                            final legNumber = leg['legNumber'];
                                            final turns =
                                            List<Map<String, dynamic>>.from(
                                              leg['turns'] ?? const [],
                                            );

                                            return Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text('  LEG $legNumber'),
                                                ...turns.map((t) {
                                                  final rawDarts = List.from(
                                                    t['darts'] ?? const [],
                                                  );

                                                  final darts = rawDarts
                                                      .map(
                                                        (e) => e == null
                                                        ? '-'
                                                        : e.toString(),
                                                  )
                                                      .toList();

                                                  final total =
                                                  t['total'] is int
                                                      ? t['total'] as int
                                                      : 0;

                                                  final kind =
                                                      t['endKind']?.toString() ??
                                                          'normal';

                                                  return Text(
                                                    '    ${darts.join(", ")} → $total ($kind)',
                                                  );
                                                }),
                                                const SizedBox(height: 4),
                                              ],
                                            );
                                          }),
                                          const SizedBox(height: 8),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> loadMatchResults(RoomData data) async {
    final matchId = data.matchId;
    if (matchId == null) return [];

    final local = LocalMatchStorage.get(matchId);
    if (local != null) {
      final players = local['players'] as Map<String, dynamic>;
      return players.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final db = FirebaseFirestore.instance;
    final results = <Map<String, dynamic>>[];

    for (final p in data.players) {
      final uid = p['id'];
      final isGuest = p['isGuest'] == true;

      if (uid == null || isGuest) continue;

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('match_legs')
          .doc(matchId)
          .get();

      if (!doc.exists) continue;

      results.add(doc.data()!);
    }

    return results;
  }
}