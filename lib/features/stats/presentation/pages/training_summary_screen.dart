import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/local_training_sync_service.dart';
import '../../data/repositories_impl/training_repository.dart';
import '../../domain/entities/training_stats.dart';

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
  int? _focus;
  int? _stress;
  int? _energia;
  int? _fiducia;
  int? _distrazioni;
  final TextEditingController _commentoController = TextEditingController();
  bool _savingReview = false;

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
      _focus = local.focus;
      _stress = local.stress;
      _energia = local.energia;
      _fiducia = local.fiducia;
      _distrazioni = local.distrazioni;
      _commentoController.text = local.commento ?? '';
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

  Widget _scoreField(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int?>(
            value: value,
            hint: const Text('—'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('—')),
              DropdownMenuItem(value: 1, child: Text('1')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 5, child: Text('5')),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _saveReview() async {
    setState(() {
      _savingReview = true;
    });

    await _sync.updateSessionReview(
      id: widget.trainingId,
      focus: _focus,
      stress: _stress,
      energia: _energia,
      fiducia: _fiducia,
      distrazioni: _distrazioni,
      commento: _commentoController.text.trim().isEmpty
          ? null
          : _commentoController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _savingReview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valutazione salvata')),
    );
  }

  @override
  void dispose() {
    _commentoController.dispose();
    super.dispose();
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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Valutazione sessione (opzionale)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _scoreField('Focus', _focus, (v) => setState(() => _focus = v)),
                    _scoreField('Stress', _stress, (v) => setState(() => _stress = v)),
                    _scoreField('Energia fisica', _energia, (v) => setState(() => _energia = v)),
                    _scoreField('Fiducia', _fiducia, (v) => setState(() => _fiducia = v)),
                    _scoreField('Distrazioni', _distrazioni, (v) => setState(() => _distrazioni = v)),
                    TextField(
                      controller: _commentoController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Commento libero',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _savingReview ? null : _saveReview,
                        child: _savingReview
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salva valutazione'),
                      ),
                    ),
                  ],
                ),
              ),

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
