/// File: dartboard_manager.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const DartboardManager({
    super.key,
    this.controller,
    this.target,
    this.minScale = 1,
    this.maxScale = 5,
    this.onScore,
    this.overlays = const {DartboardOverlayType.throws},
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void initState() {
    super.initState();
    _internalController = DartThrowManagerController();
    _controller = widget.controller ?? _internalController;
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void dispose() {
    _feedbackTimer?.cancel();
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void _handleHit(DartHitData hit) {

    _controller.registerHit(hit);

    widget.onScore?.call(
      hit.sector,
      hit.score,
      hit.distanceMm,
    );

    _feedbackTimer?.cancel();

    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _lastSector = hit.sector;
      _lastScore = hit.score;
      _feedbackVersion++;
    });

    _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {

      if (!mounted) return;

      _controller.finishVisualTurn();

      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() {
        _lastSector = null;
        _lastScore = null;
      });

    });
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {

        final side = MediaQuery.of(context).size.shortestSide;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
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
  }
}
