/// File: training_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../game/domain/entities/dart_models.dart';
import '../../../score/presentation/state/score_controller.dart';
import '../../../game/presentation/state/dartboard_manager.dart';

import '../../../game/domain/usecases/bull_training_engine.dart';
import '../../../game/domain/entities/training_mode.dart';

import '../../../game/presentation/widgets/dartboard_widget.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../../domain/usecases/training_save_logic.dart';
import '../../domain/entities/training_stats.dart';
import 'training_feedback_screen.dart';
import 'training_stats_screen.dart';
import '../widgets/target_sector_selector.dart';
import '../widgets/training_quadrant_distance.dart';
import '../widgets/training_throws_turns.dart';
import '../widgets/training_hit_stats.dart';
import '../widgets/training_sector_hits.dart';

class TrainingScreen extends StatefulWidget {
  final String title;
  final TrainingMode mode;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingScreen({
    super.key,
    required this.title,
    required this.mode,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  Timer? _elapsedTimer;

  late final LocalTrainingSyncService _syncService = LocalTrainingSyncService.instance;

  late final DateTime _trainingStartTime = DateTime.now();

  final ScoreController scoreController = ScoreController();
  final DartThrowManagerController throwController =
  DartThrowManagerController();

  late final DartGameEngine engine;

  late Duration _elapsed = Duration.zero;
  late final Stopwatch _stopwatch = Stopwatch();

  TrainingStats get stats => TrainingStats(throwController.throws);

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
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

      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    });
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void dispose() {
    _elapsedTimer?.cancel();
    _stopwatch.stop();
    scoreController.dispose();
    throwController.dispose();
    super.dispose();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _buildBoard() {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return DartboardManager(
      controller: throwController,
      target: scoreController.target,
      overlays: const {DartboardOverlayType.throws},
      onScore: (_, __, ___) {
        setState(() {});
      },
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) {
            /// Funzione: descrive in modo semplice questo blocco di logica.
            return AlertDialog(
              title: const Text("Uscire dall'allenamento"),
              content: const Text(
                  "Se esci ora i progressi non verranno salvati."),
              actions: [
                /// Funzione: descrive in modo semplice questo blocco di logica.
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Resta"),
                ),
                /// Funzione: descrive in modo semplice questo blocco di logica.
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
            /// Funzione: descrive in modo semplice questo blocco di logica.
            IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final result = TrainingSaveLogic.validateSave(throwController);

                  if (!result.canSave) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message)),
                    );
                    return;
                  }

                  try {
                    final feedbackResult = await Navigator.push<TrainingFeedbackResult>(
                      context,
                      /// Funzione: descrive in modo semplice questo blocco di logica.
                      MaterialPageRoute(
                        builder: (_) => TrainingFeedbackScreen(
                          onSave: (feedback) {
                            return _syncService.saveSession(
                              mode: widget.mode.name,
                              target: scoreController.target,
                              start: _trainingStartTime,
                              end: _trainingStartTime.add(_elapsed),
                              throwsList: throwController.throws,
                              focus: feedback.focus,
                              stress: feedback.stress,
                              energia: feedback.energia,
                              fiducia: feedback.fiducia,
                              distrazioni: feedback.distrazioni,
                              commento: feedback.commento,
                            );
                          },
                        ),
                      ),
                    );
                    if (feedbackResult == null || !mounted) return;

                    if (feedbackResult.action == TrainingFeedbackAction.goToStats) {
                      Navigator.pushReplacement(
                        context,
                        /// Funzione: descrive in modo semplice questo blocco di logica.
                        MaterialPageRoute(
                          builder: (_) => TrainingStatsScreen(
                            title: 'Statistiche allenamento',
                            mode: widget.mode,
                            initialSessionId: feedbackResult.savedSessionId,
                            initialTarget: scoreController.target,
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Errore salvataggio: $e')),
                    );
                  }
                }
            ),
          ],
        ),
        body: Stack(
          children: [
            /// Funzione: descrive in modo semplice questo blocco di logica.
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
                                  /// Funzione: descrive in modo semplice questo blocco di logica.
                                  TrainingThrowsTurns(
                                    throwsCount: stats.totalThrows,
                                    turns: stats.totalTurns,
                                  ),
                                  /// Funzione: descrive in modo semplice questo blocco di logica.
                                  Row(
                                    children: [
                                      /// Funzione: descrive in modo semplice questo blocco di logica.
                                      IconButton(
                                        icon: const Icon(Icons.undo),
                                        onPressed: () {
                                          throwController.undoLastThrow();
                                          /// Funzione: descrive in modo semplice questo blocco di logica.
                                          setState(() {});
                                        },
                                      ),
                                      /// Funzione: descrive in modo semplice questo blocco di logica.
                                      const SizedBox(width: 6),
                                      /// Funzione: descrive in modo semplice questo blocco di logica.
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
                                /// Funzione: descrive in modo semplice questo blocco di logica.
                                TrainingThrowsTurns(
                                  throwsCount: stats.totalThrows,
                                  turns: stats.totalTurns,
                                ),
                                /// Funzione: descrive in modo semplice questo blocco di logica.
                                Row(
                                  children: [
                                    /// Funzione: descrive in modo semplice questo blocco di logica.
                                    IconButton(
                                      icon: const Icon(Icons.undo),
                                      onPressed: () {
                                        throwController.undoLastThrow();
                                        /// Funzione: descrive in modo semplice questo blocco di logica.
                                        setState(() {});
                                      },
                                    ),
                                    /// Funzione: descrive in modo semplice questo blocco di logica.
                                    const SizedBox(width: 6),
                                    /// Funzione: descrive in modo semplice questo blocco di logica.
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
          ],
        ),
      ),
    );
  }
}
