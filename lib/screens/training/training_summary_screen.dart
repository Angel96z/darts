import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'local_training_sync_service.dart';
import 'training_repository.dart';
import 'training_stats.dart';

class TrainingSummaryScreen extends StatefulWidget {
  final String trainingId;

  const TrainingSummaryScreen({
    super.key,
    required this.trainingId,
  });

  @override
  State<TrainingSummaryScreen> createState() => _TrainingSummaryScreenState();
}

class _TrainingSummaryScreenState extends State<TrainingSummaryScreen> {
  late final LocalTrainingSyncService _sync = LocalTrainingSyncService.instance;


  LocalTrainingSyncStatus? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
// Assicuriamoci che l'istanza sia disponibile
    assert(LocalTrainingSyncService.instance != null, 'SyncService non inizializzato');
  }
  Future<void> _loadStatus() async {
    final local = await _sync.getById(widget.trainingId);
    if (!mounted || local == null) return;

    setState(() {
      _syncStatus = local.syncStatus;
    });
  }

  Future<Map<String, dynamic>?> _loadTraining() async {
    final local = await _sync.getById(widget.trainingId);

    if (local != null) {
      final stats = TrainingStats(local.throwsList);

      return {
        'mode': local.mode,
        'target': local.target,
        'totalThrows': stats.totalThrows,
        'totalTurns': stats.totalTurns,
        'durationSeconds':
        local.endTime.difference(local.startTime).inSeconds,
        'stats': {
          'hits': stats.targetHits(local.target),
          'miss': stats.targetMiss(local.target),
          'hitPercent': stats.totalThrows == 0
              ? 0
              : ((stats.targetHits(local.target) / stats.totalThrows) * 100)
              .round(),
          'avgDistanceMm': stats.averageDistanceMm,
          'bestStreak': stats.bestStreak(local.target),
        },
        '_syncStatus': local.syncStatus,
      };
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .doc(widget.trainingId)
        .get();

    if (!snap.exists) return null;

    return {
      ...snap.data()!,
      '_syncStatus': LocalTrainingSyncStatus.synced,
    };
  }

  Widget _syncIndicator(LocalTrainingSyncStatus status) {
    switch (status) {
      case LocalTrainingSyncStatus.synced:
        return const Icon(Icons.cloud_done, color: Colors.green);

      case LocalTrainingSyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case LocalTrainingSyncStatus.failed:
        return const Icon(Icons.error, color: Colors.red);

      case LocalTrainingSyncStatus.pending:
        return const Text("Offline");
    }
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$value'),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riepilogo allenamento')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _loadTraining(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;

          final stats = Map<String, dynamic>.from(data['stats'] ?? {});
          final status = _syncStatus;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Stato sync'),
                  if (status != null) _syncIndicator(status),
                ],
              ),

              const SizedBox(height: 20),

              _row('Modalità', data['mode']),
              _row('Target', data['target']),
              _row('Throws', data['totalThrows']),
              _row('Turns', data['totalTurns']),
              _row(
                'Durata',
                _formatDuration(data['durationSeconds'] ?? 0),
              ),

              const SizedBox(height: 20),

              _row('Hits', stats['hits'] ?? 0),
              _row('Miss', stats['miss'] ?? 0),
              _row('Hit %', '${stats['hitPercent'] ?? 0}%'),
              _row('Avg distance', stats['avgDistanceMm'] ?? 0),
              _row('Best streak', stats['bestStreak'] ?? 0),

              const SizedBox(height: 20),

              if (status == LocalTrainingSyncStatus.failed ||
                  status == LocalTrainingSyncStatus.pending)
                ElevatedButton(
                  onPressed: () async {
                    await _sync.syncAll();
                    await _loadStatus();
                  },
                  child: const Text("Riprova sync"),
                ),
              const SizedBox(height: 20),

              OutlinedButton(
                onPressed: () async {
                  await _sync.debugPrintAllRecords();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug log stampato in console')),
                  );
                },
                child: const Text("Debug: mostra record locali"),
              ),
            ],
          );
        },
      ),
    );
  }
}