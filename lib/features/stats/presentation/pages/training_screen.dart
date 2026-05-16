/// File: training_screen.dart - UI ridisegnata
/// Selettore target in top bar, stats sotto il bersaglio, undo grande a sinistra

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../game/domain/entities/dart_models.dart';
import '../../../score/presentation/state/score_controller.dart';
import '../../../game/presentation/state/dartboard_manager.dart';
import '../../../game/domain/usecases/bull_training_engine.dart';
import '../../../game/domain/entities/training_mode.dart';
import '../../../game/presentation/widgets/dartboard_widget.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../../domain/services/stats_aggregator_service.dart';
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

  late final LocalTrainingSyncService _syncService = LocalTrainingSyncService.instance;

  late final DateTime _trainingStartTime = DateTime.now();

  final ScoreController scoreController = ScoreController();
  final DartThrowManagerController throwController = DartThrowManagerController();

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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: t.overlay,
            title: Text(
              "Leave training?",
              style: TextStyle(color: t.textPrimary),
            ),
            content: Text(
              "If you leave now, your progress will not be saved.",
              style: TextStyle(color: t.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Stay", style: TextStyle(color: t.accent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Leave", style: TextStyle(color: t.red)),
              ),
            ],
          ),
        );
        return leave ?? false;
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          title: Text(widget.title, style: TextStyle(color: t.textPrimary)),
          backgroundColor: t.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            TargetSectorSelector(
              currentTarget: scoreController.target,
              enabled: throwController.throws.isEmpty,
              onSelected: (sector) {
                if (throwController.throws.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Target locked: save or undo all throws to change it.',
                      ),
                      backgroundColor: t.red,
                    ),
                  );
                  return;
                }

                scoreController.setTarget(sector);
                setState(() {});
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.save, color: t.accent),
              onPressed: () async {
                final result = TrainingSaveLogic.validateSave(throwController);

                if (!result.canSave) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: t.red,
                    ),
                  );
                  return;
                }

                try {
                  final feedbackResult = await Navigator.push<TrainingFeedbackResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingFeedbackScreen(
                        onSave: (feedback) async {
                          final result = await _syncService.saveSession(
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
                          await StatsAggregatorService.instance.updateUserStats();
                          return result;
                        },
                      ),
                    ),
                  );
                  if (feedbackResult == null || !mounted) return;

                  if (feedbackResult.action == TrainingFeedbackAction.goToStats) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainingStatsScreen(
                          title: 'Training statistics',
                          mode: widget.mode,
                          initialSessionId: feedbackResult.savedSessionId,
                          initialTarget: scoreController.target,
                          showAppBar: true,
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).popUntil((route) => route.isFirst);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Save error: $e'),
                      backgroundColor: t.red,
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            double rightPanelWidth = (screenWidth * 0.25).clamp(280.0, 420.0);
            final isDesktop = screenWidth >= 900;

            // Widget di UNDO e INFO
            Widget buildOverlayControls() {
              final roundNumber = (stats.totalTurns ~/ 3) + 1;
              final throwsCount = stats.totalThrows;

              // Calcolo dimensioni responsive
              final buttonWidth = (screenWidth * 0.18).clamp(120.0, 200.0);
              final buttonHeight = (screenHeight * 0.06).clamp(44.0, 56.0);

              return Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // UNDO button
                    Container(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          throwController.undoLastThrow();
                          setState(() {});
                        },
                        icon: Icon(Icons.undo, size: 20, color: t.textPrimary),
                        label: Text(
                          "Undo",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.surfaceHigh,
                          foregroundColor: t.textPrimary,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: t.border),
                          ),
                        ),
                      ),
                    ),

                    // Info container (round e freccette)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat, size: 16, color: t.accent),
                          const SizedBox(width: 6),
                          Text(
                            "R$roundNumber",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: t.divider,
                          ),
                          Icon(Icons.sports_score, size: 16, color: t.accent),
                          const SizedBox(width: 6),
                          Text(
                            "$throwsCount",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Darts",
                            style: TextStyle(
                              fontSize: 11,
                              color: t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!isDesktop) {
              // Layout mobile
              return Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: Stack(
                      children: [
                        // BOARD REALE
                        DartboardManager(
                          controller: throwController,
                          target: scoreController.target,
                          overlays: const {DartboardOverlayType.throws},
                          onScore: (_, __, ___) {
                            setState(() {});
                          },
                        ),
                        // SOVRAPPOSIZIONE CONTROLLI
                        buildOverlayControls(),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: t.surface.withOpacity(0.5),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: buildStatsPanel(
                          context,
                          isDesktop,
                          stats,
                          scoreController,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Layout desktop
            return Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // BOARD REALE
                      DartboardManager(
                        controller: throwController,
                        target: scoreController.target,
                        overlays: const {DartboardOverlayType.throws},
                        onScore: (_, __, ___) {
                          setState(() {});
                        },
                      ),
                      // SOVRAPPOSIZIONE CONTROLLI
                      buildOverlayControls(),
                    ],
                  ),
                ),

                Container(
                  width: rightPanelWidth,
                  constraints: const BoxConstraints(
                    minWidth: 380,
                    maxWidth: 420,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface.withOpacity(0.95),
                    border: Border(
                      left: BorderSide(
                        color: t.border.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: buildStatsPanel(
                        context,
                        isDesktop,
                        stats,
                        scoreController,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// STATS PANEL COMPONENT - SOLO RIORGANIZZAZIONE LAYOUT

Widget buildStatsPanel(
    BuildContext context,
    bool isDesktop,
    TrainingStats stats,
    ScoreController scoreController,
    ) {
  final t = AppTokens.of(context);

  Widget piece(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: Text(
        text,
        style: t.bodyBold(t.textPrimary),
      ),
    );
  }

  final text1 = TrainingHitStats(
    hit: stats.targetHits(scoreController.target),
    miss: stats.targetMiss(scoreController.target),
    streak: stats.currentStreak(scoreController.target),
    best: stats.bestStreak(scoreController.target),
  );

  final text2 = TrainingQuadrantDistance(
    quadrants: stats.quadrantHits(),
    totalMiss: stats.targetMiss(scoreController.target),
    distanceMm: scoreController.avgDistanceMm,
    hitPercent: stats.totalThrows == 0
        ? 0.0
        : (stats.targetHits(scoreController.target) / stats.totalThrows) * 100.0,
  );

  final text3 = TrainingSectorHits(
    stats: stats.sectorStats(scoreController.target),
    target: scoreController.target,
    totalThrows: stats.totalThrows,
  );

  if (isDesktop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text1,
        const SizedBox(height: 10),
        text2,
        const SizedBox(height: 10),
        text3,
      ],
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: text2),
          const SizedBox(width: 10),
          Expanded(child: text3),
        ],
      ),
      const SizedBox(height: 10),
      text1,
    ],
  );
}