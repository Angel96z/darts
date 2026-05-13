/// File: training_quadrant_distance.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

class TrainingQuadrantDistance extends StatelessWidget {
  final Map<String, int> quadrants;
  final int totalMiss;
  final double distanceMm;
  final double hitPercent;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingQuadrantDistance({
    super.key,
    required this.quadrants,
    required this.totalMiss,
    required this.distanceMm,
    required this.hitPercent,
  });

  static const _cellBg = Color(0xFFF2F4F7);
  static const _cellBorder = Color(0xFFE0E4EC);
  static const _distBg = Color(0xFFF2F4F7);
  static const _distText = Color(0xFF4A5568);

  static const double _gridSize = 150;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Color _cellColor(int value, int total) {
    if (total == 0) return _cellBg;

    final ratio = value / total;

    return Color.lerp(
      _cellBg,
      const Color(0xFFFFD6D6),
      (ratio * 3).clamp(0.0, 1.0),
    )!;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _cell(int value, int total) {

    final percent = total == 0 ? 0 : ((value / total) * 100).round();
    final isEmpty = percent == 0;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cellColor(value, total),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cellBorder),
      ),
      child: Text(
        isEmpty ? "—" : "$percent%",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isEmpty ? Colors.black26 : Colors.black54,
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    final total = totalMiss == 0 ? 1 : totalMiss;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.of(context).size.width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackWidth;

        final availableHeight = constraints.maxHeight;

        double gridSize = availableWidth.clamp(96.0, 260.0).toDouble();

        if (availableHeight.isFinite) {
          final maxGridByHeight = (availableHeight - 48).clamp(80.0, 260.0).toDouble();
          if (maxGridByHeight < gridSize) {
            gridSize = maxGridByHeight;
          }
        }

        const gap = 5.0;
        final cellSize = (gridSize - gap) / 2;
        final circleSize = gridSize * 0.32;

        final percent = hitPercent;

        String freqText;

        if (percent <= 0) {
          freqText = "—";
        } else {
          final n = (100 / percent).round();
          freqText = "1/$n";
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: gridSize,
                height: gridSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: _cell(quadrants["tl"] ?? 0, total),
                            ),
                            const SizedBox(width: gap),
                            SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: _cell(quadrants["tr"] ?? 0, total),
                            ),
                          ],
                        ),
                        const SizedBox(height: gap),
                        Row(
                          children: [
                            SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: _cell(quadrants["bl"] ?? 0, total),
                            ),
                            const SizedBox(width: gap),
                            SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: _cell(quadrants["br"] ?? 0, total),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${percent.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (gridSize * 0.095).clamp(10.0, 14.0),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            freqText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (gridSize * 0.075).clamp(8.0, 11.0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _distBg,
                  border: Border.all(color: _cellBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 16,
                      color: _distText.withOpacity(0.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${distanceMm.toStringAsFixed(1)} mm",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _distText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
