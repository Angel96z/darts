/// File: dart_rules.dart. Contiene componenti condivisi usati in più parti dell'app.

import 'dart:math';

class DartRuleResult {
  final String sector;
  final int score;
  final double distanceMm;
  final String? targetQuadrant;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const DartRuleResult({
    required this.sector,
    required this.score,
    required this.distanceMm,
    this.targetQuadrant,
  });
}

class DartRules {
  static const List<int> sectors = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static DartRuleResult calculateHit({
    required double dx,
    required double dy,
    required double boardRadius,
    required double boardX,
    required double boardY,
    String? target,
  }) {
    final distance = sqrt(dx * dx + dy * dy);
    final centerX = boardRadius;
    final centerY = boardRadius;
    final scoringOuterRadius = boardRadius * (170 / 225.5);

    if (distance > scoringOuterRadius) {
      return const DartRuleResult(sector: 'MISS', score: 0, distanceMm: 0);
    }

    final bullInner = boardRadius * (6.35 / 225.5);
    final bullOuter = boardRadius * (15.9 / 225.5);
    final tripleInner = boardRadius * (99 / 225.5);
    final tripleOuter = boardRadius * (107 / 225.5);
    final doubleInner = boardRadius * (162 / 225.5);
    final doubleOuter = boardRadius * (170 / 225.5);

    final angleDeg = (atan2(dy, dx) * 180 / pi + 360 + 90) % 360;
    final sectorIndex = ((angleDeg + 9) ~/ 18) % 20;
    final base = sectors[sectorIndex];

    late final String sector;
    late final int score;

    if (distance <= bullInner) {
      sector = 'D25';
      score = 50;
    } else if (distance <= bullOuter) {
      sector = 'S25';
      score = 25;
    } else if (distance >= tripleInner && distance <= tripleOuter) {
      sector = 'T$base';
      score = base * 3;
    } else if (distance >= doubleInner && distance <= doubleOuter) {
      sector = 'D$base';
      score = base * 2;
    } else {
      sector = 'S$base';
      score = base;
    }

    double distanceMm = 0;
    String? targetQuadrant;

    if (target != null && target.endsWith('25')) {
      final ddx = boardX - centerX;
      final ddy = boardY - centerY;
      distanceMm = (sqrt(ddx * ddx + ddy * ddy) / boardRadius) * 225.5;
      targetQuadrant = _quadrant(ddx, ddy, sector == target);
      return DartRuleResult(
        sector: sector,
        score: score,
        distanceMm: distanceMm,
        targetQuadrant: targetQuadrant,
      );
    }

    if (target != null) {
      const sectorAngle = 2 * pi / 20;
      const startOffset = -pi / 2 - sectorAngle / 2;
      final ring = target[0];
      final value = int.tryParse(target.substring(1));

      if (value != null) {
        final index = sectors.indexOf(value);
        if (index != -1) {
          final angle = startOffset + index * sectorAngle + sectorAngle / 2;
          double targetRadius;
          if (ring == 'T') {
            targetRadius = (tripleInner + tripleOuter) / 2;
          } else if (ring == 'D') {
            targetRadius = (doubleInner + doubleOuter) / 2;
          } else {
            targetRadius = (bullOuter + tripleInner) / 2;
          }

          final targetX = centerX + cos(angle) * targetRadius;
          final targetY = centerY + sin(angle) * targetRadius;
          final ddx = boardX - targetX;
          final ddy = boardY - targetY;
          distanceMm = (sqrt(ddx * ddx + ddy * ddy) / boardRadius) * 225.5;
          targetQuadrant = _quadrant(ddx, ddy, sector == target);
        }
      }
    }

    return DartRuleResult(
      sector: sector,
      score: score,
      distanceMm: distanceMm,
      targetQuadrant: targetQuadrant,
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static String _quadrant(double ddx, double ddy, bool isCenter) {
    if (isCenter) return 'center';
    if (ddx < 0 && ddy < 0) return 'tl';
    if (ddx >= 0 && ddy < 0) return 'tr';
    if (ddx < 0 && ddy >= 0) return 'bl';
    return 'br';
  }
}
