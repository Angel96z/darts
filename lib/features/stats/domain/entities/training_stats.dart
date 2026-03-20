import 'dart:math';

import '../../../game/domain/entities/dart_models.dart';

class TrainingStats {
  final List<DartThrow> throws;

  TrainingStats(this.throws);

  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _std(List<double> values) {
    if (values.length < 2) return 0;
    final m = _mean(values);
    final v = values
        .map((e) => pow(e - m, 2).toDouble())
        .reduce((a, b) => a + b) /
        values.length;
    return sqrt(v);
  }

  int get totalThrows => throws.length;

  int get totalTurns => (throws.length / 3).floor();

  double get averageDistanceMm {
    if (throws.isEmpty) return 0;
    return throws.map((e) => e.distanceMm).reduce((a, b) => a + b) / throws.length;
  }

  int targetHits(String target) {
    return throws.where((t) => t.sector == target).length;
  }

  int targetMiss(String target) {
    return throws.where((t) => t.sector != target).length;
  }

  int currentStreak(String target) {
    int streak = 0;

    for (int i = throws.length - 1; i >= 0; i--) {
      if (throws[i].sector == target) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int bestStreak(String target) {
    int best = 0;
    int current = 0;

    for (final t in throws) {
      if (t.sector == target) {
        current++;
        if (current > best) {
          best = current;
        }
      } else {
        current = 0;
      }
    }

    return best;
  }

  Map<String, double> centroid() {
    if (throws.isEmpty) {
      return {
        'x': 0,
        'y': 0,
      };
    }

    final xs = throws.map((t) => t.position.dx).toList();
    final ys = throws.map((t) => t.position.dy).toList();

    return {
      'x': _mean(xs),
      'y': _mean(ys),
    };
  }

  Map<String, double> dispersionStats() {
    final distances = throws.map((t) => t.distanceMm).toList();

    return {
      'meanRadiusMm': _mean(distances),
      'stdRadiusMm': _std(distances),
    };
  }

  Map<String, Map<String, double>> dartStats(String target) {
    final res = <String, Map<String, double>>{};

    for (int d = 1; d <= 3; d++) {
      final list = throws.where((t) => t.dartInTurn == d).toList();
      final hits = list.where((t) => t.sector == target).length;
      final total = list.length;
      final distances = list.map((e) => e.distanceMm).toList();

      res['dart$d'] = {
        'total': total.toDouble(),
        'hits': hits.toDouble(),
        'hitPercent': total == 0 ? 0 : (hits / total) * 100,
        'avgDistanceMm': _mean(distances),
      };
    }

    return res;
  }

  Map<String, int> quadrantHits() {
    final q = {
      'tl': 0,
      'tr': 0,
      'bl': 0,
      'br': 0,
    };

    for (final t in throws) {
      final quad = t.targetQuadrant;
      if (quad == null || quad == 'center') continue;

      if (q.containsKey(quad)) {
        q[quad] = q[quad]! + 1;
      }
    }

    return q;
  }

  String _sectorNumber(String sector) {
    return sector.replaceAll(RegExp(r'[TDS]'), '');
  }

  String _sectorType(String sector) {
    if (sector.startsWith('T')) return 'T';
    if (sector.startsWith('D')) return 'D';
    if (sector.startsWith('S')) return 'S';
    return 'S';
  }

  Map<String, Map<String, int>> sectorStats(String target) {
    final Map<String, Map<String, int>> stats = {};
    final targetNumber = _sectorNumber(target);

    stats[targetNumber] = {'T': 0, 'D': 0, 'S': 0};

    for (final t in throws) {
      if (t.sector == 'MISS') {
        stats.putIfAbsent('MISS', () => {'T': 0, 'D': 0, 'S': 0});
        stats['MISS']!['S'] = stats['MISS']!['S']! + 1;
        continue;
      }

      final number = _sectorNumber(t.sector);
      final type = _sectorType(t.sector);

      stats.putIfAbsent(number, () => {'T': 0, 'D': 0, 'S': 0});
      stats[number]![type] = stats[number]![type]! + 1;
    }

    return stats;
  }
}