import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../game/domain/entities/dart_models.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/training_sector_hits.dart';

class TrainingCharts {
  static List<DartThrow> _sortThrowsChronologically(List<DartThrow> throws) {
    final ordered = [...throws];
    ordered.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) return byTime;

      final byTurn = a.turnNumber.compareTo(b.turnNumber);
      if (byTurn != 0) return byTurn;

      return a.dartInTurn.compareTo(b.dartInTurn);
    });
    return ordered;
  }

  static List<SessionPerformancePoint> _sortSessionsChronologically(
      List<SessionPerformancePoint> sessions,
      ) {
    final ordered = [...sessions];
    ordered.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return ordered;
  }
  // =========================
  // PUBLIC API (compatibile)
  // =========================

  static Widget dartBreakdown(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    final dartMap = <int, List<DartThrow>>{
      1: [],
      2: [],
      3: [],
    };

    for (final t in orderedThrows) {
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

    final turns = <int, List<DartThrow>>{};

    for (int i = 0; i < orderedThrows.length; i++) {
      final turnIndex = i ~/ 3;
      turns.putIfAbsent(turnIndex, () => []).add(orderedThrows[i]);
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

      final hitsOnTarget =
          turnThrows.where((t) => t.sector == target).length;

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
          title: 'Hit per freccia del turno',
          data: percentMap,
          isPercent: true,
          extraLabels: ratioMap,
          description: 'Percentuale di hit su D1, D2 e D3.',
          insight: 'Se D3 scende rispetto a D1, perdi stabilità nel finale.',
          tip: 'Rallenta il ritmo e resetta la routine tra una freccia e l’altra.',
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
          description: 'Quanti turni completi chiudi con 1, 2 o 3 hit.',
          insight:
          'La base solida è aumentare i turni da 2 hit, non solo cercare 3/3.',
          tip: 'Lavora per rendere frequenti i turni con almeno 2 hit.',
        ),
      ],
    );
  }
  static Widget hitTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final dartSet = orderedThrows.map((t) => t.dartInTurn).toSet();
    final bool singleDart = dartSet.length == 1;
    final int? selectedDart = singleDart ? dartSet.first : null;
    final turns = _buildTurns(orderedThrows);

    if (turns.isEmpty) return _empty();

    final series = ChartDataSource.hitTrendSeries(
      turns: turns,
      target: target,
      singleDart: singleDart,
      selectedDart: selectedDart,
    );
    final mmByTurn = turns
        .map((t) =>
    t.map((e) => e.distanceMm).reduce((a, b) => a + b) / t.length)
        .toList();

    return BaseChartWidget(
      title:
      singleDart ? 'Hit nel tempo (D$selectedDart)' : 'Trend hit per turno',
      series: [series],
      description: 'Numero di hit per ogni turno da 3 freccette.',
      insight: 'Se la linea scende stai perdendo controllo.',
      tip: 'Rallenta il ritmo e resetta la routine base.',
      config: ChartConfig(
        minY: 0,
        maxY: singleDart ? 1 : 3,
        yInterval: 1,
        xInterval: 1,
        yLabelBuilder: (v) => v % 1 == 0 ? '${v.toInt()}' : '',
      ),
      tooltipBuilder: (index) {
        if (index < 0 || index >= series.points.length) return '';
        final v = series.points[index].y.toInt();
        return 'Turno ${index + 1}\n'
            'Hit: $v\n'
            'Distanza: ${mmByTurn[index].toStringAsFixed(1)} mm';
      },
      legendText:
      'Controlla la direzione generale: salita = più controllo, discesa = meno controllo.',
      rendererBuilder: (ctx) => LineChartRenderer(ctx: ctx, showDots: true),
    );
  }

  static Widget mmTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = _buildTurns(orderedThrows);

    if (turns.isEmpty) return _empty();

    final series = ChartDataSource.mmTrendSeries(turns: turns);
    if (series.points.isEmpty) return _empty();
    final maxY = series.points.map((e) => e.y).fold<double>(0, max);
    final hitByTurn =
    turns.map((t) => t.where((e) => e.sector == target).length).toList();

    return BaseChartWidget(
      title: 'Precisione nel tempo',
      series: [series],
      description: 'Distanza media dal target in ogni turno.',
      insight: 'Se i mm salgono, la precisione sta calando.',
      tip: 'Riduci forza e cerca un rilascio più morbido.',
      config: ChartConfig(
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        yInterval: (maxY / 4).clamp(5, 50).toDouble(),
        xInterval: 1,
        yLabelBuilder: (v) => v.toStringAsFixed(0),
      ),
      tooltipBuilder: (index) {
        if (index < 0 || index >= series.points.length) return '';
        return 'Turno ${index + 1}\n'
            'Hit: ${hitByTurn[index]}\n'
            'Distanza: ${series.points[index].y.toStringAsFixed(1)} mm';
      },
      legendText: 'Linea più bassa = migliore precisione.',
      rendererBuilder: (ctx) => LineChartRenderer(ctx: ctx, showDots: false),
    );
  }
  static Widget topSessions(List<SessionPerformancePoint> sessions) {
    if (sessions.isEmpty) return _empty();

    final selected = [...sessions]
      ..sort((a, b) => b.performance.compareTo(a.performance));
    final top = _sortSessionsChronologically(selected.take(5).toList());

    return _sessionScatterChart(
      title: 'Top 5 sessioni',
      sessions: top,
      color: Colors.green,
    );
  }
  static Widget worstSessions(List<SessionPerformancePoint> sessions) {
    if (sessions.isEmpty) return _empty();

    final selected = [...sessions]
      ..sort((a, b) => a.performance.compareTo(b.performance));
    final worst = _sortSessionsChronologically(selected.take(5).toList());

    return _sessionScatterChart(
      title: 'Worst 5 sessioni',
      sessions: worst,
      color: Colors.red,
    );
  }
  static Widget _sessionScatterChart({
    required String title,
    required List<SessionPerformancePoint> sessions,
    required Color color,
  }) {
    final points = <ChartDataPoint>[];
    for (int i = 0; i < sessions.length; i++) {
      points.add(ChartDataPoint(x: i.toDouble(), y: sessions[i].performance));
    }

    final sums = <String, double>{
      'Focus': 0,
      'Stress': 0,
      'Energia': 0,
      'Fiducia': 0,
      'Distrazioni': 0,
    };
    final counts = <String, int>{
      'Focus': 0,
      'Stress': 0,
      'Energia': 0,
      'Fiducia': 0,
      'Distrazioni': 0,
    };

    void collect(String key, num? value) {
      if (value == null) return;
      sums[key] = (sums[key] ?? 0) + value.toDouble();
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final s in sessions) {
      collect('Focus', s.focus);
      collect('Stress', s.stress);
      collect('Energia', s.energia);
      collect('Fiducia', s.fiducia);
      collect('Distrazioni', s.distrazioni);
    }

    final averages = <String, double>{};
    for (final entry in sums.entries) {
      final count = counts[entry.key] ?? 0;
      if (count > 0) averages[entry.key] = entry.value / count;
    }

    Widget mediaRow(String label, double value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final chart = BaseChartWidget(
      title: title,
      series: [ChartSeries(name: 'Performance', points: points, color: color)],
      config: const ChartConfig(
        minY: 0,
        maxY: 100,
        yInterval: 10,
        xInterval: 1,
      ),
      description: 'Ogni punto è una sessione.',
      tooltipBuilder: (index) {
        if (index < 0 || index >= sessions.length) return '';
        final s = sessions[index];
        return 'Performance: ${s.performance.toStringAsFixed(1)}%\n'
            'Focus: ${s.focus ?? '-'}  Stress: ${s.stress ?? '-'}\n'
            'Energia: ${s.energia ?? '-'}  Fiducia: ${s.fiducia ?? '-'}\n'
            'Distrazioni: ${s.distrazioni ?? '-'}\n'
            'Commento: ${s.commento?.isNotEmpty == true ? s.commento : 'Nessun commento'}';
      },
      legendText: 'Confronta i contesti mentali/fisici delle sessioni migliori e peggiori.',
      rendererBuilder: (ctx) => LineChartRenderer(ctx: ctx, showDots: true),
    );

    if (averages.isEmpty) return chart;

    return Column(
      children: [
        chart,
        _box(
          'Media sessioni',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (averages.containsKey('Focus'))
                mediaRow('Focus', averages['Focus']!),
              if (averages.containsKey('Stress'))
                mediaRow('Stress', averages['Stress']!),
              if (averages.containsKey('Energia'))
                mediaRow('Energia', averages['Energia']!),
              if (averages.containsKey('Fiducia'))
                mediaRow('Fiducia', averages['Fiducia']!),
              if (averages.containsKey('Distrazioni'))
                mediaRow('Distrazioni', averages['Distrazioni']!),
            ],
          ),
        ),
      ],
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
      description: 'Mostra dove tende a spostarsi il gruppo frecce.',
      insight: 'Se lo spostamento è sempre nella stessa direzione, l’errore è strutturale.',
      tip: 'Correggi setup iniziale e allineamento del corpo.',
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
      'Serie consecutive',
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
      description: 'Miglior serie di hit consecutive su freccette e turni.',
      insight: 'Serie corte ma frequenti indicano controllo reale.',
      tip: 'Difendi serie brevi e stabili prima di cercare sequenze lunghe.',
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
      'Indice performance',
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
      description: 'Sintesi unica di hit, precisione e consistenza.',
      insight: 'La metrica più bassa è il tuo collo di bottiglia.',
      tip: 'Allena prima la metrica più bassa tra le tre.',
    );
  }

  static Widget relationalPerformance(
      List<DartThrow> throws,
      String target, {
        bool showSessionTime = false,
      }) {
    if (throws.length < 3) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = _buildTurns(orderedThrows);
    if (turns.isEmpty) return _empty();

    final metrics = TurnMetricsBuilder.build(
      turns: turns,
      target: target,
      showSessionTime: showSessionTime,
    );
    if (metrics.isEmpty) return _empty();

    final sortedByScore = [...metrics]
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = sortedByScore.first;
    final worst = sortedByScore.last;

    final series = ChartDataSource.relationalSeries(metrics);

    return BaseChartWidget(
      title: 'Confronto performance',
      series: series,
      description:
      'Confronto tra hit, precisione e consistenza turno per turno.',
      insight: 'La linea più instabile è la priorità tecnica.',
      tip: 'Nella prossima sessione lavora sulla linea più instabile.',
      config: const ChartConfig(
        minY: 0,
        maxY: 100,
        yInterval: 20,
        xInterval: 1,
      ),
      highlightedRanges: [
        ChartRange(
          start: metrics.indexOf(best).toDouble(),
          end: metrics.indexOf(best).toDouble(),
          color: Colors.green.withOpacity(0.18),
        ),
        ChartRange(
          start: metrics.indexOf(worst).toDouble(),
          end: metrics.indexOf(worst).toDouble(),
          color: Colors.red.withOpacity(0.18),
        ),
      ],
      tooltipBuilder: (index) {
        if (index < 0 || index >= metrics.length) return '';

        final m = metrics[index];

        return 'Turno ${m.turnNumber}\n'
            'Hit: ${m.hits}/3\n'
            'Distanza: ${m.avgMm.toStringAsFixed(1)} mm';
      },
      legendText:
      'Confronta le tre linee e trova subito la metrica più fragile.',
      rendererBuilder: (ctx) => MultiLineChartRenderer(ctx: ctx),
    );
  }

  static Widget bestWorstAnalysis(List<DartThrow> throws, String target) {
    if (throws.length < 3) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = _buildTurns(orderedThrows);
    if (turns.isEmpty) return _empty();

    final metrics = TurnMetricsBuilder.build(
      turns: turns,
      target: target,
      showSessionTime: false,
    );
    if (metrics.isEmpty) return _empty();

    final sortedByScore = [...metrics]
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = sortedByScore.first;
    final worst = sortedByScore.last;

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
      'Migliore vs peggiore',
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
      description: 'Confronto diretto tra turno migliore e peggiore.',
      insight:
      'Il delta mostra dove perdi più punti: hit, distanza o consistenza.',
      tip: 'Replica la routine del turno migliore e correggi subito l’errore principale.',
    );
  }
  static Widget consistencyTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = _buildTurns(orderedThrows);
    if (turns.isEmpty) return _empty();

    final varianceByTurn = turns.map((turn) {
      final avgMm =
          turn.map((e) => e.distanceMm).reduce((a, b) => a + b) / turn.length;
      return turn
          .map((e) => pow(e.distanceMm - avgMm, 2).toDouble())
          .reduce((a, b) => a + b) /
          turn.length;
    }).toList();

    final maxVariance =
    varianceByTurn.fold<double>(0, (p, v) => v > p ? v : p);

    final points = <ChartDataPoint>[];
    for (int i = 0; i < varianceByTurn.length; i++) {
      final consistency = maxVariance == 0
          ? 100.0
          : (1 - (varianceByTurn[i] / maxVariance)).clamp(0.0, 1.0) * 100;
      points.add(ChartDataPoint(x: i.toDouble(), y: consistency));
    }

    final series =
    ChartSeries(name: 'Consistenza', points: points, color: Colors.purple);
    final hitByTurn =
    turns.map((t) => t.where((e) => e.sector == target).length).toList();
    final mmByTurn = turns
        .map((t) =>
    t.map((e) => e.distanceMm).reduce((a, b) => a + b) / t.length)
        .toList();

    return BaseChartWidget(
      title: 'Controllo nel tempo',
      series: [series],
      description: 'Stabilità delle 3 frecce in ogni turno.',
      insight: 'Linea alta e stabile = esecuzione sotto controllo.',
      tip: 'Mantieni stesso ritmo e stessa routine nei turni migliori.',
      config: const ChartConfig(
        minY: 0,
        maxY: 100,
        yInterval: 20,
        xInterval: 1,
      ),
      tooltipBuilder: (index) {
        if (index < 0 || index >= points.length) return '';
        return 'Turno ${index + 1}\n'
            'Hit: ${hitByTurn[index]}\n'
            'Distanza: ${mmByTurn[index].toStringAsFixed(1)} mm';
      },
      legendText: 'Più la linea resta alta, più il gesto è ripetibile.',
      rendererBuilder: (ctx) => LineChartRenderer(ctx: ctx, showDots: false),
    );
  }
  static List<List<DartThrow>> _buildTurns(List<DartThrow> throws) {
    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = <List<DartThrow>>[];
    for (int i = 0; i < orderedThrows.length; i += 3) {
      final turn = orderedThrows.skip(i).take(3).toList();
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
      'Analisi distanza dal target',
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
      description: 'Distanza media totale e per freccia D1, D2, D3.',
      insight: 'Se una freccia è molto peggiore delle altre, c’è un problema di ritmo o postura.',
      tip: 'Inserisci un micro-reset prima della freccia più debole.',
    );
  }
  static Widget ringDistribution(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final stats = _buildSectorStats(throws);

    return _box(
      'Distribuzione colpi',
      SizedBox(
        height: 400,
        child: TrainingSectorHits(
          stats: stats,
          target: target,
          totalThrows: throws.length,
        ),
      ),
      description: 'Dove finiscono i lanci tra settori e moltiplicatori.',
      insight: 'I settori più frequenti fuori target mostrano la tua deriva tipica.',
      tip: 'Allena prima i settori dove sbagli più spesso.',
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
    String? description,
    String? insight,
    String? tip,
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
      description: description,
      insight: insight,
      tip: tip,
    );
  }

  static Widget _box(
    String title,
    Widget child, {
    String? description,
    String? insight,
    String? tip,
  }) {
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          if (insight != null) ...[
            const SizedBox(height: 8),
            Text('Cosa guardare: $insight'),
          ],
          if (tip != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cosa fare: $tip',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue,
              ),
            ),
          ],
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

class ChartDataPoint {
  final double x;
  final double y;

  const ChartDataPoint({required this.x, required this.y});
}

class SessionPerformancePoint {
  final String id;
  final double performance;
  final DateTime sessionDate;
  final int? focus;
  final int? stress;
  final int? energia;
  final int? fiducia;
  final int? distrazioni;
  final String? commento;

  const SessionPerformancePoint({
    required this.id,
    required this.performance,
    required this.sessionDate,
    this.focus,
    this.stress,
    this.energia,
    this.fiducia,
    this.distrazioni,
    this.commento,
  });
}

class ChartSeries {
  final String name;
  final List<ChartDataPoint> points;
  final Color color;

  const ChartSeries({
    required this.name,
    required this.points,
    required this.color,
  });
}

class ChartRange {
  final double start;
  final double end;
  final Color color;

  const ChartRange({
    required this.start,
    required this.end,
    required this.color,
  });
}

class ChartConfig {
  final double minY;
  final double maxY;
  final double yInterval;
  final double xInterval;
  final String Function(double)? yLabelBuilder;

  const ChartConfig({
    required this.minY,
    required this.maxY,
    required this.yInterval,
    required this.xInterval,
    this.yLabelBuilder,
  });
}

class ChartDataSource {
  static ChartSeries hitTrendSeries({
    required List<List<DartThrow>> turns,
    required String target,
    required bool singleDart,
    required int? selectedDart,
  }) {
    final points = <ChartDataPoint>[];
    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      final hits = singleDart
          ? ((turn.firstWhere(
                (t) => t.dartInTurn == selectedDart,
                orElse: () => turn.first,
              ).sector ==
              target)
              ? 1
              : 0)
          : turn.where((t) => t.sector == target).length;
      points.add(ChartDataPoint(x: i.toDouble(), y: hits.toDouble()));
    }
    return ChartSeries(
      name: singleDart ? 'D${selectedDart ?? 1}' : 'Hit',
      points: points,
      color: Colors.blue,
    );
  }

  static ChartSeries mmTrendSeries({required List<List<DartThrow>> turns}) {
    final points = <ChartDataPoint>[];
    for (int i = 0; i < turns.length; i++) {
      final avgMm = turns[i].map((e) => e.distanceMm).reduce((a, b) => a + b) / 3;
      points.add(ChartDataPoint(x: i.toDouble(), y: avgMm));
    }
    return ChartSeries(name: 'Distanza', points: points, color: Colors.orange);
  }

  static List<ChartSeries> relationalSeries(List<_TurnMetric> metrics) {
    final hit = <ChartDataPoint>[];
    final precision = <ChartDataPoint>[];
    final consistency = <ChartDataPoint>[];
    for (int i = 0; i < metrics.length; i++) {
      final x = i.toDouble();
      hit.add(ChartDataPoint(x: x, y: metrics[i].hitRate));
      precision.add(ChartDataPoint(x: x, y: metrics[i].precisionForChart));
      consistency.add(ChartDataPoint(x: x, y: metrics[i].consistencyNorm));
    }
    return [
      ChartSeries(name: 'Hit', color: Colors.blue, points: hit),
      ChartSeries(name: 'Precisione', color: Colors.orange, points: precision),
      ChartSeries(name: 'Consistenza', color: Colors.purple, points: consistency),
    ];
  }
}

class TurnMetricsBuilder {
  static List<_TurnMetric> build({
    required List<List<DartThrow>> turns,
    required String target,
    required bool showSessionTime,
  }) {
    return TrainingCharts._buildTurnMetrics(
      turns: turns,
      target: target,
      showSessionTime: showSessionTime,
    );
  }
}

typedef _ChartRendererBuilder = Widget Function(_BaseChartContext ctx);

class BaseChartWidget extends StatefulWidget {
  final String title;
  final List<ChartSeries> series;
  final ChartConfig config;
  final String? description;
  final String? insight;
  final String? tip;
  final String Function(int index)? tooltipBuilder;
  final List<ChartRange> highlightedRanges;
  final String legendText;
  final _ChartRendererBuilder rendererBuilder;

  const BaseChartWidget({
  required this.title,
  required this.series,
  required this.config,
  this.description,
  this.insight,
  this.tip,
  this.legendText = '',
  this.rendererBuilder = _defaultRenderer,
  this.tooltipBuilder,
  this.highlightedRanges = const [],
  super.key,
  });

  static Widget _defaultRenderer(_BaseChartContext ctx) {
  return LineChartRenderer(ctx: ctx);
  }

  @override
  State<BaseChartWidget> createState() => _BaseChartWidgetState();
}

class _BaseChartWidgetState extends State<BaseChartWidget> {
  static const double _minWindowTurns = 6;
  double _viewStart = 0;
  double _viewEnd = 0;
  double _lastScale = 1;
  String? _tooltipText;
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _widgetFocusNode = FocusNode();

  int get _totalTurns {
    if (widget.series.isEmpty) return 0;
    return widget.series.first.points.length;
  }

  @override
  void initState() {
    super.initState();
    _resetView();
  }

  @override
  void didUpdateWidget(covariant BaseChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) {
      _resetView();
    }
  }

  void _resetView() {
    final maxIndex = max(0, _totalTurns - 1).toDouble();
    _viewStart = 0;
    _viewEnd = maxIndex;
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _widgetFocusNode.dispose();
    super.dispose();
  }

  void _onHoverIndex(int? index) {
    if (widget.tooltipBuilder == null) return;
    setState(() {
      _tooltipText = index == null ? null : widget.tooltipBuilder!(index);
    });
  }

  void _zoomAround(double factor, double centerX) {
    if (_totalTurns <= 1) return;

    final minIndex = 0.0;
    final maxIndex = (_totalTurns - 1).toDouble();

    final currentSpan = (_viewEnd - _viewStart).clamp(1.0, maxIndex);
    final newSpan = (currentSpan / factor).clamp(_minWindowTurns, maxIndex);

    final centerRatio = (centerX - _viewStart) / currentSpan;

    double newStart = centerX - newSpan * centerRatio;
    double newEnd = newStart + newSpan;

    if (newStart < minIndex) {
      newStart = minIndex;
      newEnd = newStart + newSpan;
    }

    if (newEnd > maxIndex) {
      newEnd = maxIndex;
      newStart = newEnd - newSpan;
    }

    setState(() {
      _viewStart = newStart.clamp(minIndex, maxIndex);
      _viewEnd = newEnd.clamp(minIndex, maxIndex);
    });
  }

  void _pan(double deltaTurns) {
    if (_totalTurns <= 1) return;
    final minIndex = 0.0;
    final maxIndex = (_totalTurns - 1).toDouble();
    final span = (_viewEnd - _viewStart).clamp(1.0, _totalTurns.toDouble());
    double newStart = _viewStart - deltaTurns;
    double newEnd = _viewEnd - deltaTurns;
    if (newStart < minIndex) {
      newStart = minIndex;
      newEnd = newStart + span;
    }
    if (newEnd > maxIndex) {
      newEnd = maxIndex;
      newStart = newEnd - span;
    }
    setState(() {
      _viewStart = newStart.clamp(minIndex, maxIndex);
      _viewEnd = newEnd.clamp(minIndex, maxIndex);
    });
  }

  bool _isCtrlPressed() {
    return RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlRight);
  }

  @override
  Widget build(BuildContext context) {
    if (_totalTurns == 0) return TrainingCharts._empty();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth <= 0 ? 320.0 : constraints.maxWidth;
        final span = max(1.0, _viewEnd - _viewStart);
        final sampledSeries = widget.series.map((s) {
          final start = _viewStart.floor().clamp(0, s.points.length - 1);
          final end = _viewEnd.ceil().clamp(0, s.points.length - 1);
          final slice = s.points.sublist(start, end + 1);
          final maxPoints = max(40, (width / 4).round());
          if (slice.length <= maxPoints) return ChartSeries(name: s.name, points: slice, color: s.color);
          final step = (slice.length / maxPoints).ceil();
          final sampled = <ChartDataPoint>[];
          for (int i = 0; i < slice.length; i += step) {
            sampled.add(slice[i]);
          }
          if (sampled.last.x != slice.last.x) sampled.add(slice.last);
          return ChartSeries(name: s.name, points: sampled, color: s.color);
        }).toList();

        final ctx = _BaseChartContext(
          series: sampledSeries,
          config: widget.config,
          minX: _viewStart,
          maxX: _viewEnd,
          onHoverIndex: _onHoverIndex,
          highlightedRanges: widget.highlightedRanges,
        );

        return TrainingCharts._box(
          widget.title,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && _isCtrlPressed()) {
                    final centerX =
                        _viewStart + ((event.localPosition.dx / width) * span);

                    final factor = event.scrollDelta.dy > 0 ? 1.2 : 0.8;

                    _zoomAround(factor, centerX);

                  }
                },
                child: RawKeyboardListener(
                  focusNode: _keyboardFocusNode,
                  onKey: (_) {},
                  child: Focus(
                    focusNode: _widgetFocusNode,
                    autofocus: true,
                    child: GestureDetector(
                      onTap: () => _widgetFocusNode.requestFocus(),                      onScaleStart: (_) => _lastScale = 1,
                      onScaleUpdate: (details) {
                        if (details.pointerCount != 2) return;
                        if ((details.scale - _lastScale).abs() > 0.02) {
                          final centerX = _viewStart + ((details.localFocalPoint.dx / width) * span);
                          final factor = details.scale / _lastScale;
                          _zoomAround(factor, centerX);
                          _lastScale = details.scale;
                        } else {
                          final deltaTurns = (details.focalPointDelta.dx / width) * span;
                          _pan(deltaTurns);
                        }
                      },
                      child: SizedBox(height: 220, width: double.infinity, child: widget.rendererBuilder(ctx)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_tooltipText ?? 'Tocca un punto del grafico per vedere Turno, Hit e Distanza'),
              ),
              const SizedBox(height: 8),
              _SimpleLegend(series: widget.series, text: widget.legendText),
            ],
          ),
          description: widget.description,
          insight: widget.insight,
          tip: widget.tip,
        );
      },
    );
  }
}

class _BaseChartContext {
  final List<ChartSeries> series;
  final ChartConfig config;
  final double minX;
  final double maxX;
  final void Function(int? index) onHoverIndex;
  final List<ChartRange> highlightedRanges;

  const _BaseChartContext({
    required this.series,
    required this.config,
    required this.minX,
    required this.maxX,
    required this.onHoverIndex,
    required this.highlightedRanges,
  });
}

class LineChartRenderer extends StatelessWidget {
  final _BaseChartContext ctx;
  final bool showDots;

  const LineChartRenderer({required this.ctx, this.showDots = false, super.key});

  @override
  Widget build(BuildContext context) {
    final s = ctx.series.first;
    return LineChart(
      LineChartData(
        minX: ctx.minX,
        maxX: ctx.maxX,
        minY: ctx.config.minY,
        maxY: ctx.config.maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: _titles(ctx.config),
        lineTouchData: _touch(ctx.onHoverIndex),
        lineBarsData: [
          LineChartBarData(
            spots: s.points.map((p) => FlSpot(p.x, p.y)).toList(),
            color: s.color,
            isCurved: false,
            barWidth: 2,
            dotData: FlDotData(show: showDots),
          ),
        ],
      ),
    );
  }
}

class MultiLineChartRenderer extends StatelessWidget {
  final _BaseChartContext ctx;

  const MultiLineChartRenderer({required this.ctx, super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: ctx.minX,
        maxX: ctx.maxX,
        minY: ctx.config.minY,
        maxY: ctx.config.maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: _titles(ctx.config),
        lineTouchData: _touch(ctx.onHoverIndex),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: ctx.highlightedRanges
              .map((r) => VerticalRangeAnnotation(
                    x1: r.start - 0.5,
                    x2: r.end + 0.5,
                    color: r.color,
                  ))
              .toList(),
        ),
        lineBarsData: ctx.series
            .map((s) => LineChartBarData(
                  spots: s.points.map((p) => FlSpot(p.x, p.y)).toList(),
                  isCurved: false,
                  barWidth: 2,
                  color: s.color,
                  dotData: const FlDotData(show: false),
                ))
            .toList(),
      ),
    );
  }
}

FlTitlesData _titles(ChartConfig config) {
  return FlTitlesData(
    topTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    ),
    rightTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: config.yInterval,
        reservedSize: 36,
        getTitlesWidget: (v, _) {
          final text =
              config.yLabelBuilder?.call(v) ?? v.toStringAsFixed(0);
          if (text.isEmpty) return const SizedBox.shrink();
          return Text(text, style: const TextStyle(fontSize: 10));
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: config.xInterval,
        reservedSize: 28,
        getTitlesWidget: (v, _) {
          final isInt =
              (v - v.roundToDouble()).abs() < 0.001;
          if (!isInt) return const SizedBox.shrink();
          return Text(
            '${v.toInt() + 1}',
            style: const TextStyle(fontSize: 10),
          );
        },
      ),
    ),
  );
}

LineTouchData _touch(void Function(int? index) onHoverIndex) {
  return LineTouchData(
    enabled: true,
    handleBuiltInTouches: true,
    touchCallback: (event, response) {
      if (response == null ||
          response.lineBarSpots == null ||
          response.lineBarSpots!.isEmpty) {
        onHoverIndex(null);
        return;
      }

      final spot = response.lineBarSpots!.first;
      onHoverIndex(spot.x.toInt());
    },
    touchTooltipData: LineTouchTooltipData(
      getTooltipItems: (_) => [],
    ),
  );
}

class _SimpleLegend extends StatelessWidget {
  final List<ChartSeries> series;
  final String text;

  const _SimpleLegend({required this.series, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: series
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: s.color),
                    const SizedBox(width: 4),
                    Text(s.name, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ],
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
