/// File: dartboard_overlays.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'package:flutter/material.dart';

class HitFeedbackOverlay extends StatefulWidget {
  final String sector;
  final int score;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const HitFeedbackOverlay({
    super.key,
    required this.sector,
    required this.score,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  State<HitFeedbackOverlay> createState() => _HitFeedbackOverlayState();
}

class _HitFeedbackOverlayState extends State<HitFeedbackOverlay> {
  bool _visible = false;

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void initState() {
    super.initState();
    /// Funzione: descrive in modo semplice questo blocco di logica.
    Future.microtask(() {
      if (!mounted) return;
      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          offset: _visible ? Offset.zero : const Offset(0, 0.1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.sector,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.score}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
}
