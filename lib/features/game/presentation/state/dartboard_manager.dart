/// File: dartboard_manager.dart. Contiene logica di presentazione per input dartboard.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/widgets/dartboard_overlays.dart';
import '../widgets/dartboard_widget.dart';
import '../../domain/entities/dart_models.dart';

class DartboardManager extends StatefulWidget {
  final DartThrowManagerController? controller;
  final String? target;

  final double minScale;
  final double maxScale;

  final void Function(String label, int score, double distanceMm)? onScore;
  final Set<DartboardOverlayType> overlays;

  const DartboardManager({
    super.key,
    this.controller,
    this.target,
    this.minScale = 1,
    this.maxScale = 20,
    this.onScore,
    this.overlays = const {DartboardOverlayType.throws},
  });

  @override
  State<DartboardManager> createState() => _DartboardManagerState();
}

class _DartboardManagerState extends State<DartboardManager> {
  late final DartThrowManagerController _internalController;
  late DartThrowManagerController _controller;

  String? _lastSector;
  int? _lastScore;

  int _feedbackVersion = 0;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _internalController = DartThrowManagerController();
    _controller = widget.controller ?? _internalController;
  }

  @override
  void didUpdateWidget(covariant DartboardManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextController = widget.controller ?? _internalController;
    if (!identical(nextController, _controller)) {
      _controller = nextController;
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();

    if (widget.controller == null) {
      _internalController.dispose();
    }

    super.dispose();
  }

  void _handleHit(DartHitData hit) {
    if (_controller.isWaitingNextTurn) return;

    _controller.registerHit(hit);

    widget.onScore?.call(
      hit.sector,
      hit.score,
      hit.distanceMm,
    );

    _feedbackTimer?.cancel();

    setState(() {
      _lastSector = hit.sector;
      _lastScore = hit.score;
      _feedbackVersion++;
    });

    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      _controller.finishVisualTurn();

      setState(() {
        _lastSector = null;
        _lastScore = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = min(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      ignoring: _controller.isWaitingNextTurn,
                      child: DartboardWidget(
                        minScale: widget.minScale,
                        maxScale: widget.maxScale,
                        throws: _controller.currentTurnThrows,
                        target: widget.target,
                        overlays: widget.overlays,
                        onHit: _handleHit,
                      ),
                    ),
                    if (_lastSector != null && _lastScore != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: HitFeedbackOverlay(
                            key: ValueKey(_feedbackVersion),
                            sector: _lastSector!,
                            score: _lastScore!,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}