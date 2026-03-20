import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../logic/dart_throw_logic.dart';
import '../../logic/score_controller.dart';
import '../../logic/dartboard_manager.dart';

import '../../training/bull_training_engine.dart';
import '../../training/training_mode.dart';

import '../../widgets/dartboard_widget.dart';
import 'local_training_sync_service.dart';
import 'training_repository.dart';
import 'training_save_logic.dart';
import 'training_stats.dart';
import 'training_summary_screen.dart';
import 'widgets/target_sector_selector.dart';
import 'widgets/training_quadrant_distance.dart';
import 'widgets/training_throws_turns.dart';
import 'widgets/training_hit_stats.dart';
import 'widgets/training_sector_hits.dart';

enum SaveOverlayState { loading, success, error }

class TrainingScreen extends StatefulWidget {
  final String title;
  final TrainingMode mode;

  const TrainingScreen({
    super.key,
    required this.title,
    required this.mode,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  Timer? _elapsedTimer;

  final TrainingRepository _trainingRepo = TrainingRepository();
  late final LocalTrainingSyncService _syncService = LocalTrainingSyncService.instance;
  SaveOverlayState? _overlayState;
  String? _overlayMessage;

  late final DateTime _trainingStartTime = DateTime.now();

  final ScoreController scoreController = ScoreController();
  final DartThrowManagerController throwController =
  DartThrowManagerController();

  late final DartGameEngine engine;

  late Duration _elapsed = Duration.zero;
  late final Stopwatch _stopwatch = Stopwatch();

  TrainingStats get stats => TrainingStats(throwController.throws);

  @override
  void initState() {
    super.initState();

    engine = BullTrainingEngine(scoreController);
    throwController.setEngine(engine);

    final user = FirebaseAuth.instance.currentUser;

    throwController.configureSingles(
      players: [
        DartPlayer(
          id: user?.uid ?? "guest",
          name: user?.displayName ?? user?.email ?? "Player",
        ),
      ],
    );

    _stopwatch.start();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _stopwatch.stop();
    scoreController.dispose();
    throwController.dispose();
    super.dispose();
  }

  Widget _buildOverlay() {
    if (_overlayState == null) return const SizedBox();

    IconData icon;
    Color color;
    bool showSpinner = false;

    switch (_overlayState) {
      case SaveOverlayState.loading:
        showSpinner = true;
        icon = Icons.hourglass_empty;
        color = Colors.white;
        break;
      case SaveOverlayState.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case SaveOverlayState.error:
        icon = Icons.close;
        color = Colors.red;
        break;
      case null:
        icon = Icons.info;
        color = Colors.white;
        break;
    }
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner) const CircularProgressIndicator(),
                  if (!showSpinner)
                    Icon(icon, size: 48, color: color),
                  const SizedBox(height: 16),
                  Text(_overlayMessage ?? "",
                      textAlign: TextAlign.center),
                  if (_overlayState == SaveOverlayState.error)
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _overlayState = null;
                          });
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

  Widget _buildBoard() {
    return DartboardManager(
      controller: throwController,
      target: scoreController.target,
      overlays: const {DartboardOverlayType.throws},
      onScore: (_, __, ___) {
        setState(() {});
      },
    );
  }

  Widget _buildStatsPanel() {
    final isMobile = MediaQuery.of(context).size.width <= 900;

    final hits = stats.targetHits(scoreController.target);
    final miss = stats.targetMiss(scoreController.target);

    final double percent = stats.totalThrows == 0
        ? 0.0
        : (hits / stats.totalThrows) * 100.0;

    if (!isMobile) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TrainingQuadrantDistance(
              quadrants: stats.quadrantHits(),
              totalMiss: miss,
              distanceMm: scoreController.avgDistanceMm,
              hitPercent: percent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TrainingHitStats(
              hit: hits,
              miss: miss,
              streak: stats.currentStreak(scoreController.target),
              best: stats.bestStreak(scoreController.target),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TrainingSectorHits(
                stats: stats.sectorStats(scoreController.target),
                target: scoreController.target,
                totalThrows: stats.totalThrows,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: TrainingQuadrantDistance(
              quadrants: stats.quadrantHits(),
              totalMiss: miss,
              distanceMm: scoreController.avgDistanceMm,
              hitPercent: percent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrainingHitStats(
                  hit: hits,
                  miss: miss,
                  streak: stats.currentStreak(scoreController.target),
                  best: stats.bestStreak(scoreController.target),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: TrainingSectorHits(
                    stats: stats.sectorStats(scoreController.target),
                    target: scoreController.target,
                    totalThrows: stats.totalThrows,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Uscire dall'allenamento"),
              content: const Text(
                  "Se esci ora i progressi non verranno salvati."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Resta"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Esci"),
                ),
              ],
            );
          },
        );
        return leave ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final result = TrainingSaveLogic.validateSave(throwController);

                  if (!result.canSave) {
                    setState(() {
                      _overlayState = SaveOverlayState.error;
                      _overlayMessage = result.message;
                    });
                    return;
                  }

                  setState(() {
                    _overlayState = SaveOverlayState.loading;
                    _overlayMessage = "Salvataggio in corso...";
                  });

                  try {
// 1. Salva locale con transaction
                    final localId = await _syncService.saveLocalTransactional(
                      mode: widget.mode.name,
                      target: scoreController.target,
                      start: _trainingStartTime,
                      end: _trainingStartTime.add(_elapsed),
                      throwsList: throwController.throws,
                    );

// 2. Tenta sincronizzazione con retry (con timeout breve)
                    try {
// Esegui sync con timeout di 3 secondi
                      await _syncService.syncAllWithRetry(maxRetries: 1)
                          .timeout(const Duration(seconds: 5));
                    } catch (e) {
// Se fallisce, marca come pending per sync successivo
                      await _syncService.markPendingSync(localId);

                      String message = "Salvato in locale";
                      if (e.toString().contains("Timeout")) {
                        message = "Salvato in locale (sync troppo lento)";
                      } else {
                        message = "Salvato in locale (offline)";
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }

                      debugPrint('Sync non riuscito: $e');
                    }

                    if (!mounted) return;

// 3. Naviga al summary
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainingSummaryScreen(
                          trainingId: localId,
                        ),
                      ),
                    );
                  } catch (e) {
                    setState(() {
                      _overlayState = SaveOverlayState.error;
                      _overlayMessage = "Errore salvataggio: $e";
                    });
                  }
                }
            ),
          ],
        ),
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth > 900;

                if (desktop) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  TrainingThrowsTurns(
                                    throwsCount: stats.totalThrows,
                                    turns: stats.totalTurns,
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.undo),
                                        onPressed: () {
                                          throwController.undoLastThrow();
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      TargetSectorSelector(
                                        currentTarget:
                                        scoreController.target,
                                        onSelected: (sector) {
                                          scoreController.setTarget(sector);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: _buildBoard(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            Expanded(child: _buildStatsPanel()),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                TrainingThrowsTurns(
                                  throwsCount: stats.totalThrows,
                                  turns: stats.totalTurns,
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.undo),
                                      onPressed: () {
                                        throwController.undoLastThrow();
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    TargetSectorSelector(
                                      currentTarget:
                                      scoreController.target,
                                      onSelected: (sector) {
                                        scoreController.setTarget(sector);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: _buildBoard(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildStatsPanel(),
                    ),
                  ],
                );
              },
            ),
            _buildOverlay(),
          ],
        ),
      ),
    );
  }
}
