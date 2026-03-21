import 'dart:math';

import 'package:flutter/material.dart';
import '../../../game/domain/entities/dart_models.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/training_sector_hits.dart';

class TrainingCharts {
  // =========================
  // PUBLIC API (compatibile)
  // =========================

  static Widget dartBreakdown(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // =========================
    // HIT PER FRECCIA 1 / 2 / 3
    // =========================
    final dartMap = <int, List<DartThrow>>{
      1: [],
      2: [],
      3: [],
    };

    for (final t in throws) {
      if (dartMap.containsKey(t.dartInTurn)) {
        dartMap[t.dartInTurn]!.add(t);
      }
    }

    final percentMap = <String, double>{};
    final ratioMap = <String, String>{};

    for (final entry in dartMap.entries) {
      final dart = entry.key;
      final list = entry.value;

      if (list.isEmpty) {
        percentMap['D$dart'] = 0;
        ratioMap['D$dart'] = 'mai';
        continue;
      }

      final hits = list.where((t) => t.sector == target).length;
      final total = list.length;

      final percent = (hits / total) * 100.0;
      percentMap['D$dart'] = percent;

      if (hits == 0) {
        ratioMap['D$dart'] = 'mai';
      } else {
        final oneEvery = (total / hits).round();
        ratioMap['D$dart'] = '1 su $oneEvery';
      }
    }

    // =========================
    // HIT ESATTE PER TURNO
    // usa solo turni completi da 3 freccette
    // =========================
    final turns = <int, List<DartThrow>>{};

// costruzione turni sequenziale: ogni 3 freccette = 1 turno
    for (int i = 0; i < throws.length; i++) {
      final turnIndex = i ~/ 3;
      turns.putIfAbsent(turnIndex, () => []).add(throws[i]);
    }

    final exactHitsCount = <int, int>{
      1: 0,
      2: 0,
      3: 0,
    };

    int totalCompleteTurns = 0;

    for (final turnThrows in turns.values) {
      if (turnThrows.length != 3) continue;

      totalCompleteTurns++;

      final hitsOnTarget = turnThrows.where((t) => t.sector == target).length;

      if (hitsOnTarget >= 1 && hitsOnTarget <= 3) {
        exactHitsCount[hitsOnTarget] =
            (exactHitsCount[hitsOnTarget] ?? 0) + 1;
      }
    }

    Widget buildTurnRow({
      required String label,
      required int hitCount,
    }) {
      if (totalCompleteTurns == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$label: Nessun turno completo'),
        );
      }

      final count = exactHitsCount[hitCount] ?? 0;

      if (count == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$label: 0 turni (mai)'),
        );
      }

      final percent = (count / totalCompleteTurns) * 100.0;
      final oneEvery = (totalCompleteTurns / count).round();

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '$label: $count turni • ${percent.toStringAsFixed(0)}% • 1 su $oneEvery',
        ),
      );
    }

    return Column(
      children: [
        _barChart(
          title: 'Hit per freccia',
          data: percentMap,
          isPercent: true,
          extraLabels: ratioMap,
        ),
        _box(
          'Hit esatte per turno',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Turni completi analizzati: $totalCompleteTurns'),
              const SizedBox(height: 8),
              buildTurnRow(label: '1 obiettivo', hitCount: 1),
              buildTurnRow(label: '2 obiettivi', hitCount: 2),
              buildTurnRow(label: '3 obiettivi', hitCount: 3),
            ],
          ),
        ),
      ],
    );
  }

  static Widget hitTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // capisci se stai filtrando una sola freccetta
    final dartSet = throws.map((t) => t.dartInTurn).toSet();
    final bool singleDart = dartSet.length == 1;
    final int? selectedDart = singleDart ? dartSet.first : null;

    // =========================
    // COSTRUZIONE TURNI
    // =========================
    final turns = <List<DartThrow>>[];

    for (int i = 0; i < throws.length; i += 3) {
      final turn = throws.skip(i).take(3).toList();
      if (turn.length == 3) turns.add(turn);
    }

    if (turns.isEmpty) return _empty();

    final visibleTurns = turns;

    final spots = <FlSpot>[];

    for (int i = 0; i < visibleTurns.length; i++) {
      final turn = visibleTurns[i];

      int hits = 0;

      if (singleDart) {
        // usa solo quella freccetta
        final dart = turn.firstWhere(
              (t) => t.dartInTurn == selectedDart,
          orElse: () => turn.first,
        );

        hits = dart.sector == target ? 1 : 0;
      } else {
        // usa tutte e 3
        hits = turn.where((t) => t.sector == target).length;
      }

      final percent = singleDart
          ? (hits * 100.0) // 0 o 100
          : (hits / 3) * 100.0;

      spots.add(FlSpot(i.toDouble(), percent));
    }

    return _ZoomableTrendBox(
      title: singleDart ? 'Trend D$selectedDart' : 'Trend turni (3 freccette)',
      spots: spots,
      minY: 0,
      maxY: 100,
      showDots: true,
      leftTitleBuilder: (v) {
        if (singleDart) {
          if (v == 0) return const Text('0');
          if (v == 100) return const Text('1');
          return const SizedBox.shrink();
        } else {
          if (v == 0) return const Text('0');
          if (v == 33) return const Text('1');
          if (v == 66) return const Text('2');
          if (v == 100) return const Text('3');
          return const SizedBox.shrink();
        }
      },
      leftInterval: singleDart ? 100 : 33,
    );
  }


  static Widget mmTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // =========================
    // COSTRUZIONE TURNI (3 FRECCETTE)
    // =========================
    final turns = <List<DartThrow>>[];

    for (int i = 0; i < throws.length; i += 3) {
      final turn = throws.skip(i).take(3).toList();
      if (turn.length == 3) turns.add(turn);
    }

    if (turns.isEmpty) return _empty();

    final visibleTurns = turns;

    final spots = <FlSpot>[];

    double maxY = 0;

    for (int i = 0; i < visibleTurns.length; i++) {
      final turn = visibleTurns[i];

      final avgMm = turn
          .map((e) => e.distanceMm)
          .reduce((a, b) => a + b) /
          3;

      if (avgMm > maxY) maxY = avgMm;

      spots.add(FlSpot(i.toDouble(), avgMm));
    }

    if (spots.isEmpty) return _empty();

    return _ZoomableTrendBox(
      title: 'Trend distanza (mm)',
      spots: spots,
      minY: 0,
      maxY: maxY == 0 ? 100 : maxY * 1.2,
      showDots: false,
      leftTitleBuilder: (v) => Text('${v.toInt()}'),
      leftInterval: (maxY / 4).clamp(5, 50),
    );
  }
  static Widget directionalBias(List<DartThrow> throws) {
    if (throws.isEmpty) return _empty();

    final valid = throws.where((t) => !t.isPass).toList();
    if (valid.isEmpty) return _empty();

    final meanX = valid.map((t) => t.position.dx).reduce((a, b) => a + b) / valid.length;
    final meanY = valid.map((t) => t.position.dy).reduce((a, b) => a + b) / valid.length;

    double varX = 0;
    double varY = 0;
    for (final t in valid) {
      varX += pow(t.position.dx - meanX, 2);
      varY += pow(t.position.dy - meanY, 2);
    }

    final stdX = sqrt(varX / valid.length);
    final stdY = sqrt(varY / valid.length);

    const boardMm = 451.0;
    final meanXmm = (meanX - 0.5) * boardMm;
    final meanYmm = (meanY - 0.5) * boardMm;
    final stdXmm = stdX * boardMm;
    final stdYmm = stdY * boardMm;

    final xDir = meanXmm >= 0 ? 'destra' : 'sinistra';
    final yDir = meanYmm >= 0 ? 'basso' : 'alto';

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return _box(
      'Bias direzionale',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Orizzontale', '${meanXmm >= 0 ? '+' : ''}${meanXmm.toStringAsFixed(0)} mm ($xDir)'),
          row('Verticale', '${meanYmm >= 0 ? '+' : ''}${meanYmm.toStringAsFixed(0)} mm ($yDir)'),
          const Divider(),
          row('Dispersione X', '${stdXmm.toStringAsFixed(0)} mm'),
          row('Dispersione Y', '${stdYmm.toStringAsFixed(0)} mm'),
        ],
      ),
    );
  }
  static Widget streak(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // =========================
    // STREAK FRECCETTE CONSECUTIVE
    // =========================
    int currentDartStreak = 0;
    int bestDartStreak = 0;

    for (final t in throws) {
      if (t.sector == target) {
        currentDartStreak++;
        if (currentDartStreak > bestDartStreak) {
          bestDartStreak = currentDartStreak;
        }
      } else {
        currentDartStreak = 0;
      }
    }

    // =========================
    // COSTRUZIONE TURNI (3 FRECCETTE)
    // =========================
    final turns = <List<DartThrow>>[];

    for (int i = 0; i < throws.length; i += 3) {
      final turn = throws.skip(i).take(3).toList();
      if (turn.length == 3) turns.add(turn);
    }

    int best1 = 0, best2 = 0, best3 = 0;
    int curr1 = 0, curr2 = 0, curr3 = 0;

    for (final turn in turns) {
      final hits = turn.where((t) => t.sector == target).length;

      // >=1
      if (hits >= 1) {
        curr1++;
        if (curr1 > best1) best1 = curr1;
      } else {
        curr1 = 0;
      }

      // >=2
      if (hits >= 2) {
        curr2++;
        if (curr2 > best2) best2 = curr2;
      } else {
        curr2 = 0;
      }

      // ==3
      if (hits == 3) {
        curr3++;
        if (curr3 > best3) best3 = curr3;
      } else {
        curr3 = 0;
      }
    }

    Widget row(String label, int value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return _box(
      'Streak',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Freccette consecutive', bestDartStreak),
          const Divider(),
          row('1 hit', best1),
          row('2 hit', best2),
          row('3 hit', best3),
        ],
      ),
    );
  }

  static Widget performanceScore(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // =========================
    // 1. HIT RATE
    // =========================
    final total = throws.length;
    final hits = throws.where((t) => t.sector == target).length;
    final hitRate = total == 0 ? 0.0 : hits / total; // 0-1

    // =========================
    // 2. PRECISIONE (mm → score)
    // =========================
    final avgMm = throws
        .map((e) => e.distanceMm)
        .reduce((a, b) => a + b) /
        total;

    // normalizzazione: 0mm = perfetto, 100mm = pessimo
    final precisionScore = (1 - (avgMm / 100)).clamp(0.0, 1.0);

    // =========================
    // 3. CONSISTENZA (varianza per turno)
    // =========================
    final turns = <List<DartThrow>>[];

    for (int i = 0; i < throws.length; i += 3) {
      final turn = throws.skip(i).take(3).toList();
      if (turn.length == 3) turns.add(turn);
    }

    double consistencyScore = 0;

    if (turns.isNotEmpty) {
      final hitPerTurn = turns
          .map((t) => t.where((e) => e.sector == target).length.toDouble())
          .toList();

      final mean =
          hitPerTurn.reduce((a, b) => a + b) / hitPerTurn.length;

      final variance = hitPerTurn
          .map((v) => (v - mean) * (v - mean))
          .reduce((a, b) => a + b) /
          hitPerTurn.length;

      // più varianza = meno consistenza
      consistencyScore = (1 - (variance / 2)).clamp(0.0, 1.0);
    }

    // =========================
    // SCORE FINALE
    // =========================
    final score =
        (hitRate * 0.5 +
            precisionScore * 0.3 +
            consistencyScore * 0.2) *
            100;

    return _box(
      'Performance',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _perfRow('Hit rate', (hitRate * 100)),
          _perfRow('Precisione', (precisionScore * 100)),
          _perfRow('Consistenza', (consistencyScore * 100)),
          const Divider(),
          Center(
            child: Text(
              score.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget relationalPerformance(
    List<DartThrow> throws,
    String target, {
    bool showSessionTime = false,
  }) {
    if (throws.length < 3) return _empty();

    final turns = _buildTurns(throws);
    if (turns.isEmpty) return _empty();

    final metrics = _buildTurnMetrics(
      turns: turns,
      target: target,
      showSessionTime: showSessionTime,
    );
    if (metrics.isEmpty) return _empty();

    final sorted = [...metrics]..sort((a, b) => b.score.compareTo(a.score));
    final best = sorted.first;
    final worst = sorted.last;

    final hitSpots = <FlSpot>[];
    final precisionSpots = <FlSpot>[];
    final consistencySpots = <FlSpot>[];

    for (int i = 0; i < metrics.length; i++) {
      final x = i.toDouble();
      hitSpots.add(FlSpot(x, metrics[i].hitRate));
      precisionSpots.add(FlSpot(x, metrics[i].precisionForChart));
      consistencySpots.add(FlSpot(x, metrics[i].consistencyNorm));
    }

    return _ZoomableMultiTrendBox(
      title: 'Relational performance',
      allSeries: [
        _SeriesData(name: 'Hit', color: Colors.blue, spots: hitSpots),
        _SeriesData(name: 'Precisione', color: Colors.orange, spots: precisionSpots),
        _SeriesData(name: 'Consistenza', color: Colors.purple, spots: consistencySpots),
      ],
      bestRange: _RangeMarker(
        start: metrics.indexOf(best).toDouble(),
        end: metrics.indexOf(best).toDouble(),
        color: Colors.green.withOpacity(0.18),
      ),
      worstRange: _RangeMarker(
        start: metrics.indexOf(worst).toDouble(),
        end: metrics.indexOf(worst).toDouble(),
        color: Colors.red.withOpacity(0.18),
      ),
      tooltipBuilder: (index) {
        if (index < 0 || index >= metrics.length) return '';
        final m = metrics[index];
        final session = showSessionTime && m.sessionDuration != null
            ? '\nSessione: ${_formatDurationHHmm(m.sessionDuration!)}'
            : '';
        return 'Turno ${m.turnNumber}\n'
            'Hit: ${m.hits}/3\n'
            'Precisione: ${m.avgMm.toStringAsFixed(1)} mm\n'
            'Consistenza: ${m.variance.toStringAsFixed(1)}$session';
      },
    );
  }

  static Widget bestWorstAnalysis(List<DartThrow> throws, String target) {
    if (throws.length < 3) return _empty();

    final turns = _buildTurns(throws);
    if (turns.isEmpty) return _empty();

    final metrics = _buildTurnMetrics(turns: turns, target: target, showSessionTime: false);
    if (metrics.isEmpty) return _empty();

    final sorted = [...metrics]..sort((a, b) => b.score.compareTo(a.score));
    final best = sorted.first;
    final worst = sorted.last;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    String signed(double v, {String unit = ''}) {
      final sign = v > 0 ? '+' : '';
      return '$sign${v.toStringAsFixed(1)}$unit';
    }

    final deltaHit = best.hitRate - worst.hitRate;
    final deltaMm = best.avgMm - worst.avgMm;
    final deltaConsistency = best.consistencyNorm - worst.consistencyNorm;

    return _box(
      'Best vs Worst',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BEST', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          row('Turno', '#${best.turnNumber}'),
          row('Hit rate', '${best.hitRate.toStringAsFixed(1)}%'),
          row('Avg mm', '${best.avgMm.toStringAsFixed(1)} mm'),
          row('Consistenza', '${best.variance.toStringAsFixed(1)}'),
          const Divider(),
          const Text('WORST', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          row('Turno', '#${worst.turnNumber}'),
          row('Hit rate', '${worst.hitRate.toStringAsFixed(1)}%'),
          row('Avg mm', '${worst.avgMm.toStringAsFixed(1)} mm'),
          row('Consistenza', '${worst.variance.toStringAsFixed(1)}'),
          const Divider(),
          Text('${signed(deltaHit, unit: '%')} hit'),
          Text('${signed(deltaMm, unit: 'mm')} distanza'),
          Text('${signed(deltaConsistency, unit: '%')} consistency'),
        ],
      ),
    );
  }

  static List<List<DartThrow>> _buildTurns(List<DartThrow> throws) {
    final turns = <List<DartThrow>>[];
    for (int i = 0; i < throws.length; i += 3) {
      final turn = throws.skip(i).take(3).toList();
      if (turn.length == 3) turns.add(turn);
    }
    return turns;
  }

  static List<_TurnMetric> _buildTurnMetrics({
    required List<List<DartThrow>> turns,
    required String target,
    required bool showSessionTime,
  }) {
    if (turns.isEmpty) return [];

    final maxMm = turns
        .expand((t) => t)
        .map((t) => t.distanceMm)
        .fold(0.0, (p, v) => v > p ? v : p);

    final raw = <_TurnMetricRaw>[];
    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      final hits = turn.where((t) => t.sector == target).length;
      final avgMm = turn.map((t) => t.distanceMm).reduce((a, b) => a + b) / turn.length;
      final variance = turn
          .map((t) => pow(t.distanceMm - avgMm, 2).toDouble())
          .reduce((a, b) => a + b) /
          turn.length;
      raw.add(_TurnMetricRaw(turnNumber: i + 1, hits: hits, hitRate: (hits / 3) * 100, avgMm: avgMm, variance: variance));
    }

    final maxVariance = raw.fold(0.0, (p, e) => e.variance > p ? e.variance : p);
    final minMm = raw.fold<double>(raw.first.avgMm, (p, e) => e.avgMm < p ? e.avgMm : p);
    final maxAvgMm = raw.fold<double>(raw.first.avgMm, (p, e) => e.avgMm > p ? e.avgMm : p);

    final sessionDurations = showSessionTime ? _buildSessionDurations(turns) : <int, Duration>{};

    return raw.map((r) {
      final consistencyNorm = maxVariance == 0 ? 100.0 : (1 - (r.variance / maxVariance)).clamp(0.0, 1.0) * 100;
      final precisionForChart = maxAvgMm == minMm ? 100.0 : (1 - ((r.avgMm - minMm) / (maxAvgMm - minMm))).clamp(0.0, 1.0) * 100;
      final score = r.hitRate * 0.6 +
          ((maxMm == 0 ? 0 : (1 - r.avgMm / maxMm)) * 100) * 0.3 +
          consistencyNorm * 0.1;
      return _TurnMetric(
        turnNumber: r.turnNumber,
        hits: r.hits,
        hitRate: r.hitRate,
        avgMm: r.avgMm,
        variance: r.variance,
        consistencyNorm: consistencyNorm,
        precisionForChart: precisionForChart,
        score: score,
        sessionDuration: sessionDurations[r.turnNumber],
      );
    }).toList();
  }

  static Map<int, Duration> _buildSessionDurations(List<List<DartThrow>> turns) {
    final out = <int, Duration>{};
    int sessionStart = 0;

    void flush(int endExclusive) {
      if (sessionStart >= endExclusive) return;
      final block = turns.sublist(sessionStart, endExclusive).expand((e) => e).toList();
      if (block.isEmpty) return;
      final start = block.map((e) => e.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
      final end = block.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
      final duration = end.isAfter(start) ? end.difference(start) : Duration.zero;
      for (int i = sessionStart; i < endExclusive; i++) {
        out[i + 1] = duration;
      }
    }

    for (int i = 1; i < turns.length; i++) {
      final prevTurnNumber = turns[i - 1].first.turnNumber;
      final currTurnNumber = turns[i].first.turnNumber;
      if (currTurnNumber <= prevTurnNumber) {
        flush(i);
        sessionStart = i;
      }
    }
    flush(turns.length);
    return out;
  }

  static String _formatDurationHHmm(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  static Widget _perfRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${value.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
  static Widget distanceAnalysis(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    // =========================
    // MEDIA TOTALE
    // =========================
    final totalAvg = throws
        .map((e) => e.distanceMm)
        .reduce((a, b) => a + b) /
        throws.length;

    // =========================
    // MEDIA PER FRECCIA
    // =========================
    final dartMap = <int, List<DartThrow>>{
      1: [],
      2: [],
      3: [],
    };

    for (final t in throws) {
      if (dartMap.containsKey(t.dartInTurn)) {
        dartMap[t.dartInTurn]!.add(t);
      }
    }

    double avg(List<DartThrow> list) {
      if (list.isEmpty) return 0;
      return list.map((e) => e.distanceMm).reduce((a, b) => a + b) /
          list.length;
    }

    final d1 = avg(dartMap[1]!);
    final d2 = avg(dartMap[2]!);
    final d3 = avg(dartMap[3]!);

    Widget row(String label, double value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${value.toStringAsFixed(0)} mm',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return _box(
      'Distanza dal target',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Media totale', totalAvg),
          const Divider(),
          row('D1', d1),
          row('D2', d2),
          row('D3', d3),
        ],
      ),
    );
  }
  static Widget ringDistribution(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final stats = _buildSectorStats(throws);

    return _box(
      'Distribuzione settori',
      SizedBox(
        height: 400,
        child: TrainingSectorHits(
          stats: stats,
          target: target,
          totalThrows: throws.length,
        ),
      ),
    );
  }
  static Map<String, Map<String, int>> _buildSectorStats(List<DartThrow> throws) {
    final result = <String, Map<String, int>>{};

    for (final t in throws) {
      final raw = t.sector.toUpperCase().trim();

      // =========================
      // MISS
      // =========================
      if (raw == 'MISS') {
        result.putIfAbsent('MISS', () => {});
        result['MISS']!['M'] = (result['MISS']!['M'] ?? 0) + 1;
        continue;
      }

      // =========================
      // BULL
      // =========================
      if (raw == '25' || raw == 'BULL') {
        result.putIfAbsent('25', () => {});
        result['25']!['S'] = (result['25']!['S'] ?? 0) + 1;
        continue;
      }

      // =========================
      // PARSING
      // =========================
      String type = 'S';
      String number = raw;

      if (raw.startsWith('T')) {
        type = 'T';
        number = raw.substring(1);
      } else if (raw.startsWith('D')) {
        type = 'D';
        number = raw.substring(1);
      } else if (raw.startsWith('S')) {
        type = 'S';
        number = raw.substring(1);
      }

      // fallback sicurezza
      if (int.tryParse(number) == null) continue;

      result.putIfAbsent(number, () => {});
      result[number]![type] = (result[number]![type] ?? 0) + 1;
    }

    return result;
  }

  // =========================
  // DATA
  // =========================

  // =========================
  // UI
  // =========================

  static Widget _barChart({
    required String title,
    required Map<String, double> data,
    bool isPercent = false,
    Map<String, String>? extraLabels,
  }) {
    if (data.isEmpty) return _empty();

    final double max = isPercent
        ? 100.0
        : (data.values.isEmpty
        ? 1.0
        : data.values.reduce((a, b) => a > b ? a : b));

    return _box(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) {
          final double percent = max == 0 ? 0.0 : e.value / max;
          final extra = extraLabels?[e.key];

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text(e.key)),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPercent
                      ? '${e.value.toStringAsFixed(0)}%${extra != null ? ' ($extra)' : ''}'
                      : e.value.toInt().toString(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _box(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  static Widget _empty() {
    return const Center(child: Text('Nessun dato'));
  }
}

class _ZoomableTrendBox extends StatefulWidget {
  final String title;
  final List<FlSpot> spots;
  final double minY;
  final double maxY;
  final bool showDots;
  final Widget Function(double) leftTitleBuilder;
  final double leftInterval;

  const _ZoomableTrendBox({
    required this.title,
    required this.spots,
    required this.minY,
    required this.maxY,
    required this.showDots,
    required this.leftTitleBuilder,
    required this.leftInterval,
  });

  @override
  State<_ZoomableTrendBox> createState() => _ZoomableTrendBoxState();
}

class _ZoomableMultiTrendBox extends StatefulWidget {
  final String title;
  final List<_SeriesData> allSeries;
  final _RangeMarker bestRange;
  final _RangeMarker worstRange;
  final String Function(int index)? tooltipBuilder;

  const _ZoomableMultiTrendBox({
    required this.title,
    required this.allSeries,
    required this.bestRange,
    required this.worstRange,
    this.tooltipBuilder,
  });

  @override
  State<_ZoomableMultiTrendBox> createState() => _ZoomableMultiTrendBoxState();
}

class _ZoomableMultiTrendBoxState extends State<_ZoomableMultiTrendBox> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FlSpot> _visibleSpots(List<FlSpot> input, double zoomX) {
    if (input.length <= 2) return input;

    const baseWidth = 360.0;
    const minPxPerPoint = 3.0;
    final visibleCapacity = max(40, ((baseWidth * zoomX) / minPxPerPoint).round());
    if (input.length <= visibleCapacity) return input;

    final step = (input.length / visibleCapacity).ceil();
    final out = <FlSpot>[];
    for (int i = 0; i < input.length; i += step) {
      out.add(input[i]);
    }
    if (out.isEmpty || out.last.x != input.last.x) {
      out.add(input.last);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final zoomX = _controller.value.getMaxScaleOnAxis().clamp(1.0, 6.0);

    final series = widget.allSeries.map((s) {
      return _SeriesData(
        name: s.name,
        color: s.color,
        spots: _visibleSpots(s.spots, zoomX),
      );
    }).toList();

    final totalPoints = widget.allSeries.isEmpty ? 0 : widget.allSeries.first.spots.length;
    final chartWidth = max(360.0, totalPoints * 18.0);
    final bottomInterval = max(1, (max(1, totalPoints) / 8).round()).toDouble();

    return TrainingCharts._box(
      widget.title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: widget.allSeries.map((s) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: s.color),
                    const SizedBox(width: 4),
                    Text(s.name, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: InteractiveViewer(
              transformationController: _controller,
              constrained: false,
              minScale: 1,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.symmetric(horizontal: 80),
              child: SizedBox(
                width: chartWidth,
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(show: true),
                    rangeAnnotations: RangeAnnotations(
                      verticalRangeAnnotations: [
                        VerticalRangeAnnotation(
                          x1: widget.bestRange.start - 0.5,
                          x2: widget.bestRange.end + 0.5,
                          color: widget.bestRange.color,
                        ),
                        VerticalRangeAnnotation(
                          x1: widget.worstRange.start - 0.5,
                          x2: widget.worstRange.end + 0.5,
                          color: widget.worstRange.color,
                        ),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          getTitlesWidget: (v, _) => Text('${v.toInt()}'),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: bottomInterval,
                          getTitlesWidget: (v, _) => Text('${v.toInt() + 1}'),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: series.map((s) {
                      return LineChartBarData(
                        spots: s.spots,
                        isCurved: false,
                        barWidth: 2,
                        color: s.color,
                        dotData: const FlDotData(show: false),
                      );
                    }).toList(),
                    lineTouchData: LineTouchData(
                      enabled: widget.tooltipBuilder != null,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touched) {
                          if (widget.tooltipBuilder == null || touched.isEmpty) return [];
                          final index = touched.first.x.toInt();
                          return touched
                              .map(
                                (_) => LineTooltipItem(
                                  widget.tooltipBuilder!(index),
                                  const TextStyle(color: Colors.white),
                                ),
                              )
                              .toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnMetricRaw {
  final int turnNumber;
  final int hits;
  final double hitRate;
  final double avgMm;
  final double variance;

  const _TurnMetricRaw({
    required this.turnNumber,
    required this.hits,
    required this.hitRate,
    required this.avgMm,
    required this.variance,
  });
}

class _TurnMetric {
  final int turnNumber;
  final int hits;
  final double hitRate;
  final double avgMm;
  final double variance;
  final double consistencyNorm;
  final double precisionForChart;
  final double score;
  final Duration? sessionDuration;

  const _TurnMetric({
    required this.turnNumber,
    required this.hits,
    required this.hitRate,
    required this.avgMm,
    required this.variance,
    required this.consistencyNorm,
    required this.precisionForChart,
    required this.score,
    this.sessionDuration,
  });
}

class _SeriesData {
  final String name;
  final Color color;
  final List<FlSpot> spots;

  const _SeriesData({
    required this.name,
    required this.color,
    required this.spots,
  });
}

class _RangeMarker {
  final double start;
  final double end;
  final Color color;

  const _RangeMarker({
    required this.start,
    required this.end,
    required this.color,
  });
}

class _ZoomableTrendBoxState extends State<_ZoomableTrendBox> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FlSpot> _visibleSpots(double zoomX) {
    if (widget.spots.length <= 2) return widget.spots;

    const baseWidth = 360.0;
    const minPxPerPoint = 3.0;

    final visibleCapacity = max(40, ((baseWidth * zoomX) / minPxPerPoint).round());
    if (widget.spots.length <= visibleCapacity) return widget.spots;

    final step = (widget.spots.length / visibleCapacity).ceil();
    final out = <FlSpot>[];
    for (int i = 0; i < widget.spots.length; i += step) {
      out.add(widget.spots[i]);
    }
    if (out.isEmpty || out.last.x != widget.spots.last.x) {
      out.add(widget.spots.last);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final zoomX = _controller.value.getMaxScaleOnAxis().clamp(1.0, 6.0);
    final spots = _visibleSpots(zoomX);
    final bottomInterval = max(1, (spots.length / 8).round()).toDouble();
    final chartWidth = max(360.0, widget.spots.length * 12.0);

    return TrainingCharts._box(
      widget.title,
      SizedBox(
        height: 180,
        child: InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: 1,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.symmetric(horizontal: 80),
          child: SizedBox(
            width: chartWidth,
            height: 180,
            child: LineChart(
              LineChartData(
                minY: widget.minY,
                maxY: widget.maxY,
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: widget.leftInterval,
                      getTitlesWidget: (v, _) => widget.leftTitleBuilder(v),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: bottomInterval,
                      getTitlesWidget: (v, _) => Text('${v.toInt() + 1}'),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 2,
                    dotData: FlDotData(show: widget.showDots),
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
