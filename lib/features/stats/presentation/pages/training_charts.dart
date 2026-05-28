/// File: training_charts.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app_theme.dart';
import '../../../game/domain/entities/dart_models.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/training_quadrant_distance.dart';
import '../widgets/training_sector_hits.dart';
import '../widgets/unified_stats_chart.dart';
import 'package:intl/intl.dart';

class TrainingCharts {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  static List<DartThrow> _sortThrowsChronologically(List<DartThrow> throws) {
    final ordered = [...throws];

    /// Funzione: descrive in modo semplice questo blocco di logica.
    ordered.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) return byTime;

      final byTurn = a.turnNumber.compareTo(b.turnNumber);
      if (byTurn != 0) return byTurn;

      return a.dartInTurn.compareTo(b.dartInTurn);
    });
    return ordered;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget dartBreakdown(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    final dartMap = <int, List<DartThrow>>{1: [], 2: [], 3: []};

    for (final t in orderedThrows) {
      if (dartMap.containsKey(t.dartInTurn)) {
        dartMap[t.dartInTurn]!.add(t);
      }
    }

    double hitPercent(List<DartThrow> list) {
      if (list.isEmpty) return 0;
      final hits = list.where((t) => t.sector == target).length;
      return (hits / list.length) * 100.0;
    }

    String hitText(List<DartThrow> list) {
      if (list.isEmpty) return '0% · mai';

      final hits = list.where((t) => t.sector == target).length;
      final total = list.length;
      final percent = (hits / total) * 100.0;

      if (hits == 0) {
        return '${percent.toStringAsFixed(0)}% · mai';
      }

      final oneEvery = (total / hits).round();
      return '${percent.toStringAsFixed(0)}% · 1 su $oneEvery';
    }

    final turns = _buildTurns(orderedThrows).where((turn) {
      if (turn.length != 3) return false;

      final dartIndexes = turn.map((t) => t.dartInTurn).toSet();
      return dartIndexes.contains(1) &&
          dartIndexes.contains(2) &&
          dartIndexes.contains(3);
    }).toList();

    final exactHitsCount = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};

    for (final turnThrows in turns) {
      final hitsOnTarget = turnThrows.where((t) => t.sector == target).length;
      exactHitsCount[hitsOnTarget] = (exactHitsCount[hitsOnTarget] ?? 0) + 1;
    }

    final totalCompleteTurns = turns.length;

    double turnPercent(int hitCount) {
      if (totalCompleteTurns == 0) return 0;
      final count = exactHitsCount[hitCount] ?? 0;
      return (count / totalCompleteTurns) * 100.0;
    }

    String turnText(int hitCount) {
      if (totalCompleteTurns == 0) return 'nessun turno completo';

      final count = exactHitsCount[hitCount] ?? 0;
      final percent = turnPercent(hitCount);

      if (count == 0) return '0 turni · 0% · mai';

      final oneEvery = (totalCompleteTurns / count).round();
      return '$count turni · ${percent.toStringAsFixed(0)}% · 1 su $oneEvery';
    }

    return Column(
      children: [
        _UnifiedTrainingMetricCard(
          icon: Icons.ads_click_rounded,
          title: 'Hit per freccia del turno',
          subtitle: 'Percentuale di hit separata per Dart 1, Dart 2 e Dart 3.',
          infoTitle: 'Hit per freccia del turno',
          infoText:
              'Mostra quanto spesso ogni freccia del turno colpisce il target $target. Serve a capire se perdi qualità tra prima, seconda e terza freccia.',
          advice: const [
            'Se Dart 3 cala rispetto a Dart 1, probabilmente perdi stabilità nel finale.',
            'Se Dart 1 è debole, lavora su setup iniziale e primo rilascio.',
            'Se Dart 2 o Dart 3 calano, inserisci un micro-reset tra le frecce.',
          ],
          child: _MetricBars(
            rows: [
              _MetricBarData(
                'Dart 1',
                hitPercent(dartMap[1]!),
                hitText(dartMap[1]!),
              ),
              _MetricBarData(
                'Dart 2',
                hitPercent(dartMap[2]!),
                hitText(dartMap[2]!),
              ),
              _MetricBarData(
                'Dart 3',
                hitPercent(dartMap[3]!),
                hitText(dartMap[3]!),
              ),
            ],
          ),
        ),
        _UnifiedTrainingMetricCard(
          icon: Icons.format_list_numbered_rounded,
          title: 'Hit esatte per turno',
          subtitle: 'Quanti turni completi finiscono con 0, 1, 2 o 3 hit.',
          infoTitle: 'Hit esatte per turno',
          infoText:
              'Conta solo i turni completi da 3 freccette reali e mostra quante volte chiudi il turno con 0, 1, 2 o 3 hit sul target $target.',
          advice: const [
            'Aumentare i turni da 2 hit è spesso più importante che cercare subito il 3/3.',
            'Molti turni da 0 hit indicano perdita di riferimento o routine instabile.',
            'Usa questo blocco per capire la solidità reale del turno completo.',
          ],
          child: _MetricBars(
            rows: [
              _MetricBarData('0 hit', turnPercent(0), turnText(0)),
              _MetricBarData('1 hit', turnPercent(1), turnText(1)),
              _MetricBarData('2 hit', turnPercent(2), turnText(2)),
              _MetricBarData('3 hit', turnPercent(3), turnText(3)),
            ],
          ),
        ),
      ],
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget hitTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final dartSet = orderedThrows.map((t) => t.dartInTurn).toSet();

    final bool singleDart = dartSet.length == 1;
    final int? selectedDart = singleDart ? dartSet.first : null;

    final turns = _buildTurns(orderedThrows);
    if (turns.isEmpty) return _empty();

    final points = <UnifiedStatsPoint>[];

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];

      final hits = singleDart
          ? (turn.first.sector == target ? 1 : 0)
          : turn.where((t) => t.sector == target).length;

      final avgMm =
          turn.map((e) => e.distanceMm).reduce((a, b) => a + b) / turn.length;

      points.add(
        UnifiedStatsPoint(
          x: i + 1.0,
          y: hits.toDouble(),
          label: singleDart
              ? 'D$selectedDart - tiro ${i + 1}'
              : 'Turno ${i + 1}',
          detail: singleDart
              ? 'Hit: $hits/1 • Distanza media ${avgMm.toStringAsFixed(1)} mm'
              : 'Hit: $hits/3 • Distanza media ${avgMm.toStringAsFixed(1)} mm',
        ),
      );
    }

    return UnifiedStatsChart(
      title: singleDart
          ? 'Hit nel tempo (D$selectedDart)'
          : 'Trend hit per turno',
      subtitle: singleDart
          ? 'Mostra se la freccia selezionata colpisce il target nel tempo.'
          : 'Mostra quante volte hai preso il target nel turno.',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: singleDart ? 'tiro' : 'turno',
      yAxisLabel: 'hit',
      minYValue: 0,
      maxYValue: singleDart ? 2 : 4,
      infoTitle: singleDart ? 'Hit nel tempo' : 'Trend hit per turno',
      infoText: singleDart
          ? 'Ogni punto vale 0 o 1: 1 significa target colpito, 0 significa target mancato.'
          : 'Ogni punto rappresenta un turno. Il valore indica quante freccette hanno colpito il target.',
      advice: const [
        'Hit frequenti indicano buona qualità del tiro e routine stabile.',
        'Hit molto distanti o assenti indicano problemi di precisione. Lavora sulla tecnica, calma e concentrazione.',
        'Usa il dettaglio del punto per leggere hit e distanza media.',
      ],
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget mmTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = _buildTurns(orderedThrows);

    if (turns.isEmpty) return _empty();

    // Calcola distanza media per turno
    final mmPerTurn = turns.map((turn) {
      return turn.map((e) => e.distanceMm).reduce((a, b) => a + b) /
          turn.length;
    }).toList();

    // Trova max per normalizzazione
    // Trova max per normalizzazione - CORRETTO
    final maxMm = mmPerTurn.isEmpty
        ? 100.0
        : mmPerTurn.cast<double>().reduce((a, b) => a > b ? a : b);
    final minMm = mmPerTurn.isEmpty
        ? 0.0
        : mmPerTurn.cast<double>().reduce((a, b) => a < b ? a : b);

    // INVERTE: distanza piccola = valore alto nel grafico
    // formula: valore_invertito = maxMm - distanza_reale
    // così 0mm diventa maxMm (in alto), 100mm diventa 0 (in basso)
    final points = <ChartDataPoint>[];
    for (int i = 0; i < mmPerTurn.length; i++) {
      final invertedValue = maxMm - mmPerTurn[i];
      points.add(ChartDataPoint(x: i.toDouble(), y: invertedValue));
    }

    final series = ChartSeries(
      name: 'Precisione',
      points: points,
      color: Colors.green,
    );

    final hitByTurn = turns
        .map((t) => t.where((e) => e.sector == target).length)
        .toList();

    return BaseChartWidget(
      title: 'Precisione nel tempo',
      series: [series],
      description: 'Distanza media dal target in ogni turno.',
      insight:
          '📈 Linea che sale = migliori (distanza ridotta)\n📉 Linea che scende = peggiori (distanza aumentata)',
      tip:
          'Riduci forza e cerca un rilascio più morbido per far salire la linea.',
      config: ChartConfig(
        minY: 0,
        maxY: maxMm, // Mostra scala 0-maxMm
        yInterval: (maxMm / 4).clamp(5, 50).toDouble(),
        xInterval: 1,
        // Custom label builder per mostrare la distanza reale
        yLabelBuilder: (invertedValue) {
          // Reconverte: distanza_reale = maxMm - invertedValue
          final realMm = maxMm - invertedValue;
          return '${realMm.toStringAsFixed(0)}';
        },
      ),
      tooltipBuilder: (index) {
        if (index < 0 || index >= mmPerTurn.length) return '';
        return 'Turno ${index + 1}\n'
            'Hit: ${hitByTurn[index]}\n'
            'Distanza: ${mmPerTurn[index].toStringAsFixed(1)} mm';
      },
      legendText:
          '⬆️ PUNTO PIÙ ALTO = migliore precisione (meno mm) | ⬇️ PUNTO PIÙ BASSO = peggiore precisione (più mm)',
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
      subtitle: 'Le 5 sessioni migliori del periodo filtrato.',
      sessions: top,
      icon: Icons.trending_up_rounded,
      moodTitle: 'Media stati d’animo TOP 5',
      analysisTitle: 'Analisi TOP 5',
      positive: true,
    );
  }

  static Widget worstSessions(List<SessionPerformancePoint> sessions) {
    if (sessions.isEmpty) return _empty();

    final selected = [...sessions]
      ..sort((a, b) => a.performance.compareTo(b.performance));

    final worst = _sortSessionsChronologically(selected.take(5).toList());

    return _sessionScatterChart(
      title: 'Worst 5 sessioni',
      subtitle: 'Le 5 sessioni più deboli del periodo filtrato.',
      sessions: worst,
      icon: Icons.trending_down_rounded,
      moodTitle: 'Media stati d’animo WORST 5',
      analysisTitle: 'Analisi WORST 5',
      positive: false,
    );
  }

  static Widget _sessionScatterChart({
    required String title,
    required String subtitle,
    required List<SessionPerformancePoint> sessions,
    required IconData icon,
    required String moodTitle,
    required String analysisTitle,
    required bool positive,
  }) {
    if (sessions.isEmpty) return _empty();

    final points = <UnifiedStatsPoint>[
      for (int i = 0; i < sessions.length; i++)
        UnifiedStatsPoint(
          x: i + 1.0,
          y: sessions[i].performance,
          label: 'Sessione ${i + 1}',
          detail: _buildSessionDetail(sessions[i]), // ← USA LA NUOVA FUNZIONE
        ),
    ];

    double? avgOf(int? Function(SessionPerformancePoint s) selector) {
      final values = sessions
          .map(selector)
          .whereType<int>()
          .map((e) => e.toDouble())
          .toList();

      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final avgPerformance =
        sessions.map((e) => e.performance).reduce((a, b) => a + b) /
        sessions.length;

    final avgFocus = avgOf((s) => s.focus);
    final avgStress = avgOf((s) => s.stress);
    final avgEnergia = avgOf((s) => s.energia);
    final avgFiducia = avgOf((s) => s.fiducia);
    final avgDistrazioni = avgOf((s) => s.distrazioni);

    String level(double? value) {
      if (value == null) return 'n/d';
      if (value >= 7) return 'alto';
      if (value >= 4) return 'medio';
      return 'basso';
    }

    String analysisText() {
      if (positive) {
        return 'Le migliori sessioni hanno una media performance di ${avgPerformance.toStringAsFixed(0)}%. '
            'Controlla se coincidono con focus ${level(avgFocus)}, energia ${level(avgEnergia)}, fiducia ${level(avgFiducia)} '
            'e stress ${level(avgStress)}.';
      }

      return 'Le sessioni peggiori hanno una media performance di ${avgPerformance.toStringAsFixed(0)}%. '
          'Se stress o distrazioni sono più alti rispetto alle TOP 5, il calo può essere più mentale che tecnico.';
    }

    return Column(
      children: [
        UnifiedStatsChart(
          title: title,
          subtitle: subtitle,
          points: points,
          mode: UnifiedStatsChartMode.lineAndPoints,
          xAxisLabel: 'sessione',
          yAxisLabel: 'performance %',
          minYValue: 0,
          maxYValue: 105,
          infoTitle: title,
          infoText:
              'Ogni punto rappresenta una sessione selezionata. Il grafico serve a confrontare il rendimento con gli stati d’animo registrati.',
          advice: const [
            'Confronta TOP e WORST per capire quali stati mentali ricorrono.',
            'Focus alto e distrazioni basse spesso indicano sessioni più solide.',
            'Stress alto con performance bassa può indicare perdita di routine.',
            'Energia alta ma performance bassa può indicare troppa spinta o poca precisione.',
          ],
        ),
        _UnifiedTrainingMetricCard(
          icon: icon,
          title: moodTitle,
          subtitle:
              'Media performance e stati d’animo delle sessioni selezionate.',
          infoTitle: moodTitle,
          infoText:
              'Mostra la media degli stati d’animo associati a questo gruppo di sessioni. Serve per capire in quale condizione mentale/fisica giochi meglio o peggio.',
          advice: const [
            'Confronta questi valori con l’altro gruppo TOP/WORST.',
            'Non guardare un solo dato: cerca pattern ricorrenti.',
            'Se manca uno stato d’animo, viene ignorato dalla media.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricBars(
                maxReference: 10,
                rows: [
                  _MetricBarData(
                    'Performance',
                    avgPerformance / 10,
                    '${avgPerformance.toStringAsFixed(0)}%',
                  ),
                  if (avgFocus != null)
                    _MetricBarData(
                      'Focus',
                      avgFocus,
                      '${avgFocus.toStringAsFixed(1)}/10 · ${level(avgFocus)}',
                    ),
                  if (avgStress != null)
                    _MetricBarData(
                      'Stress',
                      avgStress,
                      '${avgStress.toStringAsFixed(1)}/10 · ${level(avgStress)}',
                    ),
                  if (avgEnergia != null)
                    _MetricBarData(
                      'Energia',
                      avgEnergia,
                      '${avgEnergia.toStringAsFixed(1)}/10 · ${level(avgEnergia)}',
                    ),
                  if (avgFiducia != null)
                    _MetricBarData(
                      'Fiducia',
                      avgFiducia,
                      '${avgFiducia.toStringAsFixed(1)}/10 · ${level(avgFiducia)}',
                    ),
                  if (avgDistrazioni != null)
                    _MetricBarData(
                      'Distrazioni',
                      avgDistrazioni,
                      '${avgDistrazioni.toStringAsFixed(1)}/10 · ${level(avgDistrazioni)}',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(
                    '$analysisTitle: ${analysisText()}',
                    style: tt.titleSmall,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _buildSessionDetail(SessionPerformancePoint session) {
    final buffer = StringBuffer();

    // Formatta la data
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(session.sessionDate);

    buffer.write('📅 $formattedDate\n');
    buffer.write('📊 Performance: ${session.performance.toStringAsFixed(0)}%');

    final metrics = <String>[];
    if (session.focus != null) metrics.add('🎯 Focus: ${session.focus}/10');
    if (session.stress != null) metrics.add('😰 Stress: ${session.stress}/10');
    if (session.energia != null)
      metrics.add('⚡ Energia: ${session.energia}/10');
    if (session.fiducia != null)
      metrics.add('💪 Fiducia: ${session.fiducia}/10');
    if (session.distrazioni != null)
      metrics.add('📱 Distrazioni: ${session.distrazioni}/10');

    if (metrics.isNotEmpty) {
      buffer.write('\n${metrics.join(' • ')}');
    }

    // AGGIUNGI IL COMMENTO SE PRESENTE
    if (session.commento != null && session.commento!.trim().isNotEmpty) {
      buffer.write('\n\n📝 "${session.commento}"');
    }

    return buffer.toString();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  /// Analisi direzionale relativa al target selezionato, non al bull.
  static Widget directionalBias(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final valid = throws.where((t) => !t.isPass).toList();
    if (valid.isEmpty) return _empty();

    final targetCenter = _targetCenterFor(target);

    final meanX =
        valid.map((t) => t.position.dx).reduce((a, b) => a + b) / valid.length;
    final meanY =
        valid.map((t) => t.position.dy).reduce((a, b) => a + b) / valid.length;

    double varX = 0;
    double varY = 0;

    for (final t in valid) {
      varX += pow(t.position.dx - meanX, 2);
      varY += pow(t.position.dy - meanY, 2);
    }

    final stdX = sqrt(varX / valid.length);
    final stdY = sqrt(varY / valid.length);

    const boardMm = 451.0;

    final meanXmm = (meanX - targetCenter.dx) * boardMm;
    final meanYmm = (meanY - targetCenter.dy) * boardMm;
    final stdXmm = stdX * boardMm;
    final stdYmm = stdY * boardMm;

    final xDir = meanXmm >= 0 ? 'destra' : 'sinistra';
    final yDir = meanYmm >= 0 ? 'basso' : 'alto';

    return _UnifiedTrainingMetricCard(
      icon: Icons.open_with_rounded,
      title: 'Bias direzionale',
      subtitle:
          'Deriva media rispetto al target $target e dispersione del gruppo frecce.',
      infoTitle: 'Bias direzionale',
      infoText:
          'Mostra dove tende a spostarsi il gruppo frecce rispetto al target selezionato, non rispetto al bull. '
          'Lo spostamento indica la direzione media dell’errore; la dispersione indica quanto il gruppo è largo.',
      advice: const [
        'Bias alto ma dispersione bassa = gesto ripetibile, ma fuori asse rispetto al target.',
        'Bias basso ma dispersione alta = mira centrata mediamente, ma gesto poco stabile.',
        'Correggi in modo leggero nella direzione opposta al bias, senza stravolgere il gesto.',
      ],
      child: _MetricBars(
        rows: [
          _MetricBarData(
            'Orizzontale',
            meanXmm.abs(),
            '${meanXmm >= 0 ? '+' : ''}${meanXmm.toStringAsFixed(0)} mm ($xDir)',
          ),
          _MetricBarData(
            'Verticale',
            meanYmm.abs(),
            '${meanYmm >= 0 ? '+' : ''}${meanYmm.toStringAsFixed(0)} mm ($yDir)',
          ),
          _MetricBarData(
            'Dispersione X',
            stdXmm,
            '${stdXmm.toStringAsFixed(0)} mm',
          ),
          _MetricBarData(
            'Dispersione Y',
            stdYmm,
            '${stdYmm.toStringAsFixed(0)} mm',
          ),
        ],
      ),
    );
  }

  static Offset _targetCenterFor(String target) {
    final normalized = target.trim().toUpperCase();

    if (normalized == 'BULL' ||
        normalized == '25' ||
        normalized.endsWith('25')) {
      return const Offset(0.5, 0.5);
    }

    const sectors = [
      20,
      1,
      18,
      4,
      13,
      6,
      10,
      15,
      2,
      17,
      3,
      19,
      7,
      16,
      8,
      11,
      14,
      9,
      12,
      5,
    ];

    const sectorAngle = 2 * pi / 20;
    const startOffset = -pi / 2 - sectorAngle / 2;

    final ring = normalized[0];
    final value = int.tryParse(normalized.substring(1));
    if (value == null) return const Offset(0.5, 0.5);

    final index = sectors.indexOf(value);
    if (index == -1) return const Offset(0.5, 0.5);

    final angle = startOffset + index * sectorAngle + sectorAngle / 2;

    const boardDiameterMm = 451.0;

    const bullOuter = 15.9 / boardDiameterMm;
    const tripleInner = 99 / boardDiameterMm;
    const tripleOuter = 107 / boardDiameterMm;
    const doubleInner = 162 / boardDiameterMm;
    const doubleOuter = 170 / boardDiameterMm;

    final radius = switch (ring) {
      'T' => (tripleInner + tripleOuter) / 2,
      'D' => (doubleInner + doubleOuter) / 2,
      _ =>
        (tripleOuter + doubleInner) /
            2, // SINGOLO: zona esterna tra triplo e doppio
    };

    // NOTA: radius è già in coordinate centro→bordo (0-0.5), non moltiplicare per 0.5
    return Offset(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget streak(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    int currentDartStreak = 0;
    int bestDartStreak = 0;

    for (final t in orderedThrows) {
      if (t.sector == target) {
        currentDartStreak++;
        if (currentDartStreak > bestDartStreak) {
          bestDartStreak = currentDartStreak;
        }
      } else {
        currentDartStreak = 0;
      }
    }

    final turns = _buildTurns(orderedThrows).where((turn) {
      if (turn.length != 3) return false;

      final dartIndexes = turn.map((t) => t.dartInTurn).toSet();
      return dartIndexes.contains(1) &&
          dartIndexes.contains(2) &&
          dartIndexes.contains(3);
    }).toList();

    int best0 = 0;
    int best1 = 0;
    int best2 = 0;
    int best3 = 0;

    int curr0 = 0;
    int curr1 = 0;
    int curr2 = 0;
    int curr3 = 0;

    for (final turn in turns) {
      final hits = turn.where((t) => t.sector == target).length;

      if (hits == 0) {
        curr0++;
        if (curr0 > best0) best0 = curr0;
      } else {
        curr0 = 0;
      }

      if (hits == 1) {
        curr1++;
        if (curr1 > best1) best1 = curr1;
      } else {
        curr1 = 0;
      }

      if (hits == 2) {
        curr2++;
        if (curr2 > best2) best2 = curr2;
      } else {
        curr2 = 0;
      }

      if (hits == 3) {
        curr3++;
        if (curr3 > best3) best3 = curr3;
      } else {
        curr3 = 0;
      }
    }

    String turnText(int value) {
      if (turns.isEmpty) return 'nessun turno completo';
      if (value == 0) return 'mai';
      return '$value turni consecutivi';
    }

    return _UnifiedTrainingMetricCard(
      icon: Icons.local_fire_department_rounded,
      title: 'Serie consecutive',
      subtitle: 'Migliori sequenze consecutive su freccette e turni completi.',
      infoTitle: 'Serie consecutive',
      infoText:
          'Misura la miglior serie consecutiva di freccette sul target $target e la miglior serie di turni completi chiusi con esattamente 0, 1, 2 o 3 hit.',
      advice: const [
        'Serie corte ma frequenti indicano controllo reale.',
        'Prima stabilizza i turni da 1 e 2 hit, poi cerca il 3/3.',
        'Se le serie si interrompono spesso, lavora su routine e reset tra le frecce.',
      ],
      child: _MetricBars(
        maxReference: turns.isEmpty ? 1 : turns.length.toDouble(),
        rows: [
          _MetricBarData(
            'Freccette hit',
            bestDartStreak.toDouble(),
            bestDartStreak == 0 ? 'mai' : '$bestDartStreak consecutive',
          ),
          _MetricBarData('Turni 0 hit', best0.toDouble(), turnText(best0)),
          _MetricBarData('Turni 1 hit', best1.toDouble(), turnText(best1)),
          _MetricBarData('Turni 2 hit', best2.toDouble(), turnText(best2)),
          _MetricBarData('Turni 3 hit', best3.toDouble(), turnText(best3)),
        ],
      ),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget performanceScore(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    final turns = _buildTurns(orderedThrows).where((turn) {
      if (turn.length != 3) return false;

      final dartIndexes = turn.map((t) => t.dartInTurn).toSet();
      return dartIndexes.contains(1) &&
          dartIndexes.contains(2) &&
          dartIndexes.contains(3);
    }).toList();

    if (turns.isEmpty) return _empty();

    final metrics = TurnMetricsBuilder.build(
      turns: turns,
      target: target,
      showSessionTime: false,
    );

    if (metrics.isEmpty) return _empty();

    final avgIndex =
        metrics.map((e) => e.score).reduce((a, b) => a + b) / metrics.length;

    final avgHitRate =
        metrics.map((e) => e.hitRate).reduce((a, b) => a + b) / metrics.length;

    final avgPrecision =
        metrics.map((e) => e.precisionForChart).reduce((a, b) => a + b) /
        metrics.length;

    final avgControl =
        metrics.map((e) => e.consistencyNorm).reduce((a, b) => a + b) /
        metrics.length;

    String level(double value) {
      if (value >= 75) return 'alta';
      if (value >= 50) return 'media';
      return 'bassa';
    }

    String weakestMetric() {
      final values = <String, double>{
        'hit': avgHitRate,
        'precisione': avgPrecision,
        'controllo': avgControl,
      };

      final weakest = values.entries.reduce(
        (a, b) => a.value <= b.value ? a : b,
      );

      switch (weakest.key) {
        case 'hit':
          return 'La metrica più fragile è la capacità di colpire il target.';
        case 'precisione':
          return 'La metrica più fragile è la distanza media dal target.';
        case 'controllo':
          return 'La metrica più fragile è la stabilità tra le 3 frecce.';
      }

      return 'La metrica più fragile indica la priorità tecnica.';
    }

    return _UnifiedTrainingMetricCard(
      icon: Icons.speed_rounded,
      title: 'Indice performance',
      subtitle:
          'Sintesi unica di hit, precisione e controllo sui turni completi.',
      infoTitle: 'Indice performance',
      infoText:
          'L’indice performance combina hit, precisione e controllo. Non rappresenta i punti segnati sul tabellone: è una misura tecnica da 0 a 100 della qualità dei turni completi.',
      advice: const [
        'Indice alto = buon equilibrio tra hit, distanza e controllo.',
        'Hit alta ma controllo basso = risultato buono ma fragile.',
        'Precisione bassa = sei lontano dal target anche se il gesto può essere stabile.',
        'Controllo basso = le 3 frecce non sono abbastanza compatte.',
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricBars(
            rows: [
              _MetricBarData(
                'Indice medio',
                avgIndex,
                '${avgIndex.toStringAsFixed(0)} · qualità ${level(avgIndex)}',
              ),
              _MetricBarData(
                'Hit',
                avgHitRate,
                _formatHitFrequencyFromHitRate(avgHitRate),
              ),
              _MetricBarData(
                'Precisione',
                avgPrecision,
                '${avgPrecision.round()}%',
              ),
              _MetricBarData('Controllo', avgControl, '${avgControl.round()}%'),
            ],
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final tt = Theme.of(context).textTheme;
              return Text(weakestMetric(), style: tt.titleSmall);
            },
          ),
        ],
      ),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget relationalPerformance(
    List<DartThrow> throws,
    String target, {
    bool showSessionTime = false,
  }) {
    if (throws.length < 3) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    final turns = _buildTurns(orderedThrows).where((turn) {
      if (turn.length != 3) return false;

      final dartIndexes = turn.map((t) => t.dartInTurn).toSet();
      return dartIndexes.contains(1) &&
          dartIndexes.contains(2) &&
          dartIndexes.contains(3);
    }).toList();

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

    final avgScore =
        metrics.map((e) => e.score).reduce((a, b) => a + b) / metrics.length;

    final avgHits =
        metrics.map((e) => e.hits).reduce((a, b) => a + b) / metrics.length;

    final avgMm =
        metrics.map((e) => e.avgMm).reduce((a, b) => a + b) / metrics.length;

    final avgControl =
        metrics.map((e) => e.consistencyNorm).reduce((a, b) => a + b) /
        metrics.length;

    String level(double value) {
      if (value >= 75) return 'alta';
      if (value >= 50) return 'media';
      return 'bassa';
    }

    String bestReason(_TurnMetric m) {
      final parts = <String>[];

      if (m.hits >= avgHits) {
        parts.add('più hit');
      }

      if (m.avgMm <= avgMm) {
        parts.add('più precisione');
      }

      if (m.consistencyNorm >= avgControl) {
        parts.add('più controllo');
      }

      if (parts.isEmpty) return 'miglior score complessivo';
      return parts.join(' + ');
    }

    String worstReason(_TurnMetric m) {
      final parts = <String>[];

      if (m.hits < avgHits) {
        parts.add('meno hit');
      }

      if (m.avgMm > avgMm) {
        parts.add('meno precisione');
      }

      if (m.consistencyNorm < avgControl) {
        parts.add('meno controllo');
      }

      if (parts.isEmpty) return 'peggior score complessivo';
      return parts.join(' + ');
    }

    String relationText() {
      final bestControlHigh = best.consistencyNorm >= avgControl;
      final bestPrecisionHigh = best.avgMm <= avgMm;
      final bestHitsHigh = best.hits >= avgHits;

      final worstControlLow = worst.consistencyNorm < avgControl;
      final worstPrecisionLow = worst.avgMm > avgMm;
      final worstHitsLow = worst.hits < avgHits;

      if (bestHitsHigh && bestPrecisionHigh && bestControlHigh) {
        return 'Il picco migliore nasce quando hit, precisione e controllo salgono insieme.';
      }

      if (bestControlHigh && !bestHitsHigh) {
        return 'Il gesto è stabile, ma il gruppo è probabilmente decentrato rispetto al target.';
      }

      if (bestHitsHigh && !bestControlHigh) {
        return 'Il risultato migliore arriva da hit buone, ma non ancora da stabilità piena.';
      }

      if (worstHitsLow && worstPrecisionLow && worstControlLow) {
        return 'Il calo peggiore è completo: meno hit, più distanza e meno controllo.';
      }

      if (worstControlLow) {
        return 'Il calo sembra legato soprattutto alla perdita di controllo tra le 3 frecce.';
      }

      if (worstPrecisionLow) {
        return 'Il calo sembra legato soprattutto alla distanza dal target.';
      }

      return 'Il confronto mostra come cambiano hit, precisione e controllo tra picco e calo.';
    }

    final points = <UnifiedStatsPoint>[
      for (int i = 0; i < metrics.length; i++)
        UnifiedStatsPoint(
          x: i + 1.0,
          y: metrics[i].score,
          label: 'Turno ${metrics[i].turnNumber}',
          detail:
              'Turno ${metrics[i].turnNumber} • Score ${metrics[i].score.toStringAsFixed(0)} • Hit ${metrics[i].hits}/3 • Distanza ${metrics[i].avgMm.toStringAsFixed(1)} mm • Controllo ${metrics[i].consistencyNorm.toStringAsFixed(0)}%',
        ),
    ];

    Widget comparisonRow({
      required String label,
      required String bestValue,
      required String worstValue,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Expanded(flex: 34, child: Text(label)),
            Expanded(
              flex: 33,
              child: Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(
                    bestValue,
                    textAlign: TextAlign.center,
                    style: tt.titleSmall,
                  );
                },
              ),
            ),
            Expanded(
              flex: 33,
              child: Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(
                    worstValue,
                    textAlign: TextAlign.right,
                    style: tt.titleSmall,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        UnifiedStatsChart(
          title: 'Confronto performance',
          subtitle:
              'Indice di performace turno per turno: mostra picchi, cali e stabilità reale.',
          points: points,
          mode: UnifiedStatsChartMode.lineAndPoints,
          xAxisLabel: 'turno',
          yAxisLabel: 'indice',
          minYValue: 0,
          maxYValue: 105,
          infoTitle: 'Confronto performance',
          infoText:
              'L\'indice combina hit, precisione e controllo. Serve a capire in quali turni il risultato è stato migliore o peggiore e quale metrica ha inciso di più.',
          advice: const [
            'Indice alto con controllo alto = turno realmente solido.',
            'Indice alto con controllo basso = picco buono ma fragile.',
            'Indice basso con distanza alta = problema di precisione.',
            'Indice basso con controllo basso = perdita di gesto tra le 3 frecce.',
          ],
        ),
        _UnifiedTrainingMetricCard(
          icon: Icons.compare_arrows_rounded,
          title: 'Migliore vs peggiore',
          subtitle:
              'Confronto diretto tra il turno più forte e quello più fragile.',
          infoTitle: 'Migliore vs peggiore',
          infoText:
              'Confronta il miglior turno e il peggior turno usando indice, hit, distanza media e controllo. Non legge solo il risultato finale, ma anche perché quel turno è stato forte o debole.',
          advice: const [
            'Replica la condizione tecnica del turno migliore.',
            'Se il peggiore ha controllo basso, lavora sulla routine tra le frecce.',
            'Se il peggiore ha distanza alta, lavora su allineamento e mira.',
            'Se il migliore ha poche hit ma alto controllo, sei stabile ma fuori asse.',
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(flex: 34, child: Text('')),
                  Expanded(
                    flex: 33,
                    child: Builder(
                      builder: (context) {
                        final tt = Theme.of(context).textTheme;
                        return Text(
                          'BEST',
                          textAlign: TextAlign.center,
                          style: tt.titleSmall,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 33,
                    child: Builder(
                      builder: (context) {
                        final tt = Theme.of(context).textTheme;
                        return Text(
                          'WORST',
                          textAlign: TextAlign.right,
                          style: tt.titleSmall,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              comparisonRow(
                label: 'Turno',
                bestValue: '#${best.turnNumber}',
                worstValue: '#${worst.turnNumber}',
              ),
              comparisonRow(
                label: 'Indice',
                bestValue: best.score.toStringAsFixed(0),
                worstValue: worst.score.toStringAsFixed(0),
              ),
              comparisonRow(
                label: 'Hit',
                bestValue: '${best.hits}/3',
                worstValue: '${worst.hits}/3',
              ),
              comparisonRow(
                label: 'Distanza',
                bestValue: '${best.avgMm.toStringAsFixed(1)} mm',
                worstValue: '${worst.avgMm.toStringAsFixed(1)} mm',
              ),
              comparisonRow(
                label: 'Controllo',
                bestValue: '${best.consistencyNorm.toStringAsFixed(0)}%',
                worstValue: '${worst.consistencyNorm.toStringAsFixed(0)}%',
              ),
              const Divider(height: 22),
              Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(
                    'Migliore: ${bestReason(best)}.',
                    style: tt.titleSmall,
                  );
                },
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(
                    'Peggiore: ${worstReason(worst)}.',
                    style: tt.titleSmall,
                  );
                },
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final tt = Theme.of(context).textTheme;
                  return Text(relationText(), style: tt.titleSmall);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatHitFrequencyFromHitRate(double hitRatePercent) {
    final percent = hitRatePercent.round();

    if (percent <= 0) {
      return '0% · nessuna hit';
    }

    final dartsPerHit = (100.0 / hitRatePercent).round().clamp(1, 999);

    return '$percent% · 1 hit ogni $dartsPerHit freccette';
  }

  static String _formatHitFrequencyFromAverage(double avgHitsPerTurn) {
    final hitPercent = ((avgHitsPerTurn / 3.0) * 100.0).round();

    if (hitPercent <= 0) {
      return '0% · nessuna hit';
    }

    final dartsPerHit = (3.0 / avgHitsPerTurn).round().clamp(1, 999);

    return '$hitPercent% · 1 hit ogni $dartsPerHit freccette';
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget consistencyTrend(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final orderedThrows = _sortThrowsChronologically(throws);

    final turns = _buildTurns(orderedThrows).where((turn) {
      if (turn.length != 3) return false;

      final dartIndexes = turn.map((t) => t.dartInTurn).toSet();
      return dartIndexes.contains(1) &&
          dartIndexes.contains(2) &&
          dartIndexes.contains(3);
    }).toList();

    if (turns.isEmpty) return _empty();

    final points = <UnifiedStatsPoint>[];

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      final hits = turn.where((e) => e.sector == target).length;
      final avgMm =
          turn.map((e) => e.distanceMm).reduce((a, b) => a + b) / turn.length;

      final variance =
          turn
              .map((e) => pow(e.distanceMm - avgMm, 2).toDouble())
              .reduce((a, b) => a + b) /
          turn.length;
      final stdDevMm = sqrt(variance);

      final maxAcceptableMm = _maxDispersionForTarget(
        target,
      ); // ← nome cambiato
      double consistency =
          (1 - (stdDevMm / maxAcceptableMm)).clamp(0.0, 1.0) * 100.0;
      consistency = consistency.roundToDouble();

      points.add(
        UnifiedStatsPoint(
          x: i + 1.0,
          y: consistency,
          label: 'Turno ${i + 1}',
          detail:
              'Turno ${i + 1} • Hit $hits/3 • Distanza media ${avgMm.toStringAsFixed(1)} mm • Dispersione ${stdDevMm.toStringAsFixed(1)} mm • Controllo ${consistency.toStringAsFixed(0)}%',
        ),
      );
    }

    return UnifiedStatsChart(
      title: 'Controllo nel tempo',
      subtitle:
          'Compattezza del gruppo (dispersione in mm) - più alto è meglio',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: 'turno',
      yAxisLabel: 'controllo %',
      minYValue: 0,
      maxYValue: 105,
      infoTitle: 'Controllo nel tempo',
      infoText:
          'Misura quanto le 3 frecce sono raggruppate tra loro. '
          'Più il valore è alto, più il gruppo è compatto. '
          'Una dispersione < 10mm è eccellente, 10-20mm è buono, > 20mm indica instabilità.',
      advice: const [
        '🎯 Dispersione < 10mm = controllo eccellente (livello professionista)',
        '📊 Dispersione 10-20mm = buon controllo, lavora sulla ripetibilità',
        '⚠️ Dispersione > 20mm = priorità: stabilizzare il gesto',
        '💡 Se il controllo cala, verifica postura e rilascio',
      ],
    );
  }

  /// Restituisce la dispersione massima accettabile (in mm) per il target
  static double _maxDispersionForTarget(String target) {
    if (target == 'BULL' || target == '25') {
      return 10.0; // 10mm di dispersione = 100% scarso se supera
    }
    if (target.startsWith('T')) {
      return 15.0; // 15mm di dispersione massima accettabile
    }
    if (target.startsWith('D')) {
      return 25.0;
    }
    return 30.0; // Singoli
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static List<List<DartThrow>> _buildTurns(List<DartThrow> throws) {
    final orderedThrows = _sortThrowsChronologically(throws);
    final turns = <List<DartThrow>>[];

    // Controlla se stiamo analizzando una singola freccetta (tutti i dartInTurn uguali)
    final Set<int> dartValues = orderedThrows.map((t) => t.dartInTurn).toSet();
    final bool isSingleDart = dartValues.length == 1;

    if (isSingleDart) {
      // Modalità singola freccetta: ogni tiro è un turno
      for (int i = 0; i < orderedThrows.length; i++) {
        turns.add([orderedThrows[i]]);
      }
    } else {
      // Modalità normale: gruppi da 3
      for (int i = 0; i < orderedThrows.length; i += 3) {
        final turn = orderedThrows.skip(i).take(3).toList();
        if (turn.length == 3) turns.add(turn);
      }
    }

    return turns;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static List<_TurnMetric> _buildTurnMetrics({
    required List<List<DartThrow>> turns,
    required String target,
    required bool showSessionTime,
  }) {
    if (turns.isEmpty) return [];

    final raw = <_TurnMetricRaw>[];
    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];
      final hits = turn.where((t) => t.sector == target).length;
      final avgMm =
          turn.map((t) => t.distanceMm).reduce((a, b) => a + b) / turn.length;
      final variance =
          turn
              .map((t) => pow(t.distanceMm - avgMm, 2).toDouble())
              .reduce((a, b) => a + b) /
          turn.length;
      final stdDevMm = sqrt(variance); // ← Calcola la deviazione standard in mm

      raw.add(
        _TurnMetricRaw(
          turnNumber: i + 1,
          hits: hits,
          hitRate: (hits / 3) * 100,
          avgMm: avgMm,
          variance: variance,
          stdDevMm: stdDevMm, // ← Aggiungi questo campo
        ),
      );
    }

    // 🔧 CALCOLO PRECISIONE: usa scala assoluta (mm)
    // La precisione è inversamente proporzionale alla distanza dal target
    // 0mm = 100%, 50mm = 0% (oltre 50mm è completamente fuori bersaglio)
    const maxAcceptableDistance = 50.0; // mm

    // 🔧 CALCOLO CONTROLLO: usa dispersione assoluta (mm)
    // Usa la stessa logica di consistencyTrend ma normalizzata
    final sessionDurations = showSessionTime
        ? _buildSessionDurations(turns)
        : <int, Duration>{};

    return raw.map((r) {
      // 1. HIT RATE: già in percentuale 0-100 (OK)
      final hitRate = r.hitRate;

      // 2. PRECISIONE: basata sulla distanza media dal target
      final precisionScore =
          (1 - (r.avgMm / maxAcceptableDistance)).clamp(0.0, 1.0) * 100;

      // 3. CONTROLLO (CONSISTENZA): basato sulla dispersione (stdDev)
      final maxAcceptableDispersion = _maxDispersionForTarget(target);
      final consistencyScore =
          (1 - (r.stdDevMm / maxAcceptableDispersion)).clamp(0.0, 1.0) * 100;

      // 4. SCORE TURNO: pesi rivisti (hit 40%, precisione 35%, controllo 25%)
      // Meno peso al controllo perché è più difficile da ottenere
      final score =
          (hitRate * 0.4) + (precisionScore * 0.35) + (consistencyScore * 0.25);

      return _TurnMetric(
        turnNumber: r.turnNumber,
        hits: r.hits,
        hitRate: hitRate,
        avgMm: r.avgMm,
        variance: r.variance,
        consistencyNorm: consistencyScore, // ← Ora è in scala assoluta!
        precisionForChart: precisionScore,
        score: score,
        sessionDuration: sessionDurations[r.turnNumber],
      );
    }).toList();
  }

  static Map<int, Duration> _buildSessionDurations(
    List<List<DartThrow>> turns,
  ) {
    final out = <int, Duration>{};
    int sessionStart = 0;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    void flush(int endExclusive) {
      if (sessionStart >= endExclusive) return;
      final block = turns
          .sublist(sessionStart, endExclusive)
          .expand((e) => e)
          .toList();
      if (block.isEmpty) return;
      final start = block
          .map((e) => e.timestamp)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final end = block
          .map((e) => e.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final duration = end.isAfter(start)
          ? end.difference(start)
          : Duration.zero;
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static String _formatDurationHHmm(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget _perfRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text('${value.toStringAsFixed(0)}%')],
      ),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget distanceAnalysis(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final totalAvg =
        throws.map((e) => e.distanceMm).reduce((a, b) => a + b) / throws.length;

    final dartMap = <int, List<DartThrow>>{1: [], 2: [], 3: []};

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

    return _UnifiedTrainingMetricCard(
      icon: Icons.straighten_rounded,
      title: 'Analisi distanza dal target',
      subtitle: 'Distanza media totale, e per freccia, verso il $target.',
      infoTitle: 'Analisi distanza dal target',
      infoText:
          'Mostra la distanza media dal target $target. Valori più bassi sono migliori: più possibilità di hit.',
      advice: const [
        'Una distanza media più bassa indica una mira più efficiente e ripetibile nel tempo.',
        'Una barra più lunga rappresenta maggiore errore dal target, non una prestazione migliore.',
        'Se la Dart 1 è la più distante, il problema è spesso setup iniziale: stance, allineamento visivo o ingresso nel ritmo.',
        'Se la Dart 2 peggiora, il rilascio della prima sta alterando equilibrio, timing o posizione del braccio.',
        'Se la Dart 3 è la meno precisa, il calo è spesso mentale o posturale: perdita di focus, accelerazione o chiusura anticipata del movimento.',
        'Una differenza minima tra Dart 1, 2 e 3 indica buona stabilità tecnica e controllo del ritmo.',
        'Inserire un micro-reset respiratorio tra le freccette aiuta a mantenere consistenza nelle serie lunghe.',
        'Se sulla Dart 3 ti blocchi perché la senti come “ultima freccia”, cambia conteggio mentale: usa 0-1-2 invece di 1-2-3. Riduci il peso psicologico dell’ultimo tiro e mantieni lo stesso ritmo delle prime due.',
      ],
      child: _MetricBars(
        rows: [
          _MetricBarData(
            'Media totale',
            totalAvg,
            '${totalAvg.toStringAsFixed(0)} mm',
          ),
          _MetricBarData(
            'Dart 1',
            avg(dartMap[1]!),
            '${avg(dartMap[1]!).toStringAsFixed(0)} mm',
          ),
          _MetricBarData(
            'Dart 2',
            avg(dartMap[2]!),
            '${avg(dartMap[2]!).toStringAsFixed(0)} mm',
          ),
          _MetricBarData(
            'Dart 3',
            avg(dartMap[3]!),
            '${avg(dartMap[3]!).toStringAsFixed(0)} mm',
          ),
        ],
      ),
    );
  }
  static Widget quadrantDistance(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final valid = throws.where((t) => !t.isPass).toList();
    if (valid.isEmpty) return _empty();

    final normalizedTarget = target.trim().toUpperCase();
    final hits = valid
        .where((t) => t.sector.trim().toUpperCase() == normalizedTarget)
        .length;

    final misses = valid
        .where((t) => t.sector.trim().toUpperCase() != normalizedTarget)
        .toList();

    final quadrants = <String, int>{
      'tl': 0,
      'tr': 0,
      'bl': 0,
      'br': 0,
    };

    final targetCenter = _targetCenterFor(target);

    for (final dart in misses) {
      final quadrant = _resolveTargetQuadrant(dart, targetCenter);
      quadrants[quadrant] = (quadrants[quadrant] ?? 0) + 1;
    }

    final avgDistance =
        valid.map((t) => t.distanceMm).reduce((a, b) => a + b) / valid.length;

    final hitPercent = (hits / valid.length) * 100.0;

    return _UnifiedTrainingMetricCard(
      icon: Icons.grid_view_rounded,
      title: 'Quadranti errore',
      subtitle: 'Dove finiscono gli errori rispetto al target $target.',
      infoTitle: 'Quadranti errore',
      infoText:
      'Mostra in quale quadrante finiscono i miss rispetto al target selezionato. '
          'Il centro verde indica la percentuale di hit, mentre i quadranti indicano la direzione prevalente degli errori.',
      advice: const [
        'Un quadrante dominante indica una deriva tecnica ricorrente.',
        'Errori distribuiti su più quadranti indicano instabilità generale del gesto.',
        'Usalo insieme al bias direzionale per capire se correggere mira o routine.',
      ],
      child: SizedBox(
        height: 300,
        child: TrainingQuadrantDistance(
          quadrants: quadrants,
          totalMiss: misses.length,
          distanceMm: avgDistance,
          hitPercent: hitPercent,
        ),
      ),
    );
  }

  static String _resolveTargetQuadrant(DartThrow dart, Offset targetCenter) {
    final stored = dart.targetQuadrant?.trim().toLowerCase();

    if (stored == 'tl' ||
        stored == 'top-left' ||
        stored == 'topLeft' ||
        stored == 'alto-sinistra') {
      return 'tl';
    }

    if (stored == 'tr' ||
        stored == 'top-right' ||
        stored == 'topRight' ||
        stored == 'alto-destra') {
      return 'tr';
    }

    if (stored == 'bl' ||
        stored == 'bottom-left' ||
        stored == 'bottomLeft' ||
        stored == 'basso-sinistra') {
      return 'bl';
    }

    if (stored == 'br' ||
        stored == 'bottom-right' ||
        stored == 'bottomRight' ||
        stored == 'basso-destra') {
      return 'br';
    }

    final isLeft = dart.position.dx < targetCenter.dx;
    final isTop = dart.position.dy < targetCenter.dy;

    if (isTop && isLeft) return 'tl';
    if (isTop && !isLeft) return 'tr';
    if (!isTop && isLeft) return 'bl';
    return 'br';
  }
  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget ringDistribution(List<DartThrow> throws, String target) {
    if (throws.isEmpty) return _empty();

    final stats = _buildSectorStats(throws);

    return _UnifiedTrainingMetricCard(
      icon: Icons.pie_chart_rounded,
      title: 'Distribuzione colpi',
      subtitle:
          'Dove finiscono i lanci tra settori, singoli, doppi, tripli e miss.',
      infoTitle: 'Distribuzione colpi',
      infoText:
          'Mostra la distribuzione reale dei colpi sul bersaglio. Serve a capire se gli errori sono casuali oppure se tendono a concentrarsi sempre negli stessi settori.',
      advice: const [
        'Settori fuori target molto frequenti indicano una deriva ricorrente.',
        'Molti miss indicano perdita di riferimento o distanza tecnica eccessiva.',
        'Se sbagli sempre vicino al target, lavora su micro-correzione e non su cambio gesto.',
        'Usa questa vista insieme a precisione e bias direzionale.',
      ],
      child: SizedBox(
        height: 320,
        child: TrainingSectorHits(
          stats: stats,
          target: target,
          totalThrows: throws.length,
        ),
      ),
    );
  }

  static Map<String, Map<String, int>> _buildSectorStats(
    List<DartThrow> throws,
  ) {
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return _box(
      title,

      /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final tt = Theme.of(context).textTheme;
              return Text(title, style: tt.titleMedium);
            },
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final t = AppTokens.of(context);
                final tt = Theme.of(context).textTheme;
                return Text(
                  description,
                  style: tt.bodySmall?.copyWith(color: t.textSecondary),
                );
              },
            ),
          ],
          if (insight != null) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final tt = Theme.of(context).textTheme;
                return Text('Cosa guardare: $insight', style: tt.bodyMedium);
              },
            ),
          ],
          if (tip != null) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final tt = Theme.of(context).textTheme;
                return Text(
                  'Cosa fare: $tip',
                  style: tt.titleSmall?.copyWith(color: Colors.blue),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  static Widget _empty({
    String title = 'Nessun dato',
    String subtitle = 'Non ci sono dati per il filtro selezionato.',
    String infoTitle = 'Nessun dato disponibile',
    String infoText =
        'Questa sezione non può essere calcolata perché il filtro corrente non contiene dati sufficienti.',
    List<String> advice = const [
      'Cambia periodo, sessione o target.',
      'Rimuovi eventuali filtri sulle singole freccette.',
      'Registra nuovi tiri per popolare questa statistica.',
    ],
  }) {
    return UnifiedStatsCard(
      title: title,
      subtitle: subtitle,
      info: UnifiedStatsInfoData(
        title: infoTitle,
        text: infoText,
        advice: advice,
      ),
      child: Builder(
        builder: (context) {
          final t = AppTokens.of(context);
          final tt = Theme.of(context).textTheme;

          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Text(
              'Nessun dato disponibile.',
              style: tt.bodySmall?.copyWith(color: t.textMuted),
            ),
          );
        },
      ),
    );
  }
}

class ChartDataPoint {
  final double x;
  final double y;

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  final String Function(double)? yLabelBuilder; // già presente!

  const ChartConfig({
    required this.minY,
    required this.maxY,
    required this.yInterval,
    required this.xInterval,
    this.yLabelBuilder,
  });
}

class ChartDataSource {
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
          ? ((turn
                        .firstWhere(
                          (t) => t.dartInTurn == selectedDart,
                          orElse: () => turn.first,
                        )
                        .sector ==
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static ChartSeries mmTrendSeries({required List<List<DartThrow>> turns}) {
    final points = <ChartDataPoint>[];
    for (int i = 0; i < turns.length; i++) {
      final avgMm =
          turns[i].map((e) => e.distanceMm).reduce((a, b) => a + b) / 3;
      points.add(ChartDataPoint(x: i.toDouble(), y: avgMm));
    }
    return ChartSeries(name: 'Distanza', points: points, color: Colors.orange);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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
      ChartSeries(
        name: 'Consistenza',
        color: Colors.purple,
        points: consistency,
      ),
    ];
  }
}

class TurnMetricsBuilder {
  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static Widget _defaultRenderer(_BaseChartContext ctx) {
    return LineChartRenderer(ctx: ctx);
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void initState() {
    super.initState();
    _resetView();
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void didUpdateWidget(covariant BaseChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) {
      _resetView();
    }
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void _resetView() {
    final maxIndex = max(0, _totalTurns - 1).toDouble();
    _viewStart = 0;
    _viewEnd = maxIndex;
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void dispose() {
    _keyboardFocusNode.dispose();
    _widgetFocusNode.dispose();
    super.dispose();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  void _onHoverIndex(int? index) {
    if (widget.tooltipBuilder == null) return;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _tooltipText = index == null ? null : widget.tooltipBuilder!(index);
    });
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _viewStart = newStart.clamp(minIndex, maxIndex);
      _viewEnd = newEnd.clamp(minIndex, maxIndex);
    });
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _viewStart = newStart.clamp(minIndex, maxIndex);
      _viewEnd = newEnd.clamp(minIndex, maxIndex);
    });
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool _isCtrlPressed() {
    return RawKeyboard.instance.keysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        RawKeyboard.instance.keysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    if (_totalTurns == 0) return TrainingCharts._empty();
    final tt = Theme.of(context).textTheme;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth <= 0 ? 320.0 : constraints.maxWidth;
        final span = max(1.0, _viewEnd - _viewStart);
        final sampledSeries = widget.series.map((s) {
          final start = _viewStart.floor().clamp(0, s.points.length - 1);
          final end = _viewEnd.ceil().clamp(0, s.points.length - 1);
          final slice = s.points.sublist(start, end + 1);
          final maxPoints = max(40, (width / 4).round());
          if (slice.length <= maxPoints)
            return ChartSeries(name: s.name, points: slice, color: s.color);
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

          /// Funzione: descrive in modo semplice questo blocco di logica.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Funzione: descrive in modo semplice questo blocco di logica.
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
                      onTap: () => _widgetFocusNode.requestFocus(),
                      onScaleStart: (_) => _lastScale = 1,
                      onScaleUpdate: (details) {
                        if (details.pointerCount != 2) return;
                        if ((details.scale - _lastScale).abs() > 0.02) {
                          final centerX =
                              _viewStart +
                              ((details.localFocalPoint.dx / width) * span);
                          final factor = details.scale / _lastScale;
                          _zoomAround(factor, centerX);
                          _lastScale = details.scale;
                        } else {
                          final deltaTurns =
                              (details.focalPointDelta.dx / width) * span;
                          _pan(deltaTurns);
                        }
                      },
                      child: RepaintBoundary(
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: widget.rendererBuilder(ctx),
                        ),
                      ),
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
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _tooltipText ??
                          'Tocca un punto del grafico per vedere i dettagli',
                      style: tt.bodySmall,
                    ),
                  ),
                ),
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  const LineChartRenderer({
    required this.ctx,
    this.showDots = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final s = ctx.series.first;

    // Usa i punti così come sono (sono già invertiti matematicamente in mmTrend)
    final spots = s.points.map((p) => FlSpot(p.x, p.y)).toList();

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
            spots: spots,
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MultiLineChartRenderer({required this.ctx, super.key});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return LineChart(
      /// Funzione: descrive in modo semplice questo blocco di logica.
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
              .map(
                (r) => VerticalRangeAnnotation(
                  x1: r.start - 0.5,
                  x2: r.end + 0.5,
                  color: r.color,
                ),
              )
              .toList(),
        ),
        lineBarsData: ctx.series
            .map(
              (s) => LineChartBarData(
                spots: s.points.map((p) => FlSpot(p.x, p.y)).toList(),
                isCurved: false,
                barWidth: 2,
                color: s.color,
                dotData: const FlDotData(show: false),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Funzione: descrive in modo semplice questo blocco di logica.
FlTitlesData _titles(ChartConfig config) {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: config.yInterval,
        reservedSize: 36,
        getTitlesWidget: (v, _) {
          final text = config.yLabelBuilder?.call(v) ?? v.toStringAsFixed(0);
          if (text.isEmpty) return const SizedBox.shrink();
          return Builder(
            builder: (context) {
              final tt = Theme.of(context).textTheme;
              return Text(text, style: tt.labelSmall);
            },
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: config.xInterval,
        reservedSize: 28,
        getTitlesWidget: (v, _) {
          final isInt = (v - v.roundToDouble()).abs() < 0.001;
          if (!isInt) return const SizedBox.shrink();
          return Builder(
            builder: (context) {
              final tt = Theme.of(context).textTheme;
              return Text('${v.toInt() + 1}', style: tt.labelSmall);
            },
          );
        },
      ),
    ),
  );
}

/// Funzione: descrive in modo semplice questo blocco di logica.
LineTouchData _touch(void Function(int? index) onHoverIndex) {
  /// Funzione: descrive in modo semplice questo blocco di logica.
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
    touchTooltipData: LineTouchTooltipData(getTooltipItems: (_) => []),
  );
}

class _SimpleLegend extends StatelessWidget {
  final List<ChartSeries> series;
  final String text;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const _SimpleLegend({required this.series, required this.text});

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Funzione: descrive in modo semplice questo blocco di logica.
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
                    Text(s.name, style: tt.labelSmall),
                  ],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(text, style: tt.bodySmall?.copyWith(color: t.textSecondary)),
      ],
    );
  }
}

// Aggiorna anche _TurnMetricRaw per includere stdDevMm
class _TurnMetricRaw {
  final int turnNumber;
  final int hits;
  final double hitRate;
  final double avgMm;
  final double variance;
  final double stdDevMm; // ← NUOVO

  const _TurnMetricRaw({
    required this.turnNumber,
    required this.hits,
    required this.hitRate,
    required this.avgMm,
    required this.variance,
    required this.stdDevMm,
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

  /// Funzione: descrive in modo semplice questo blocco di logica.
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

class _UnifiedTrainingMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String infoTitle;
  final String infoText;
  final List<String> advice;
  final Widget child;

  const _UnifiedTrainingMetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.infoTitle,
    required this.infoText,
    required this.advice,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedStatsCard(
      title: title,
      subtitle: subtitle,
      info: UnifiedStatsInfoData(
        title: infoTitle,
        text: infoText,
        advice: advice,
      ),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: child,
    );
  }
}

class _MetricBarData {
  final String label;
  final double value;
  final String text;

  const _MetricBarData(this.label, this.value, this.text);
}

class _MetricBars extends StatelessWidget {
  final List<_MetricBarData> rows;
  final double maxReference;

  const _MetricBars({required this.rows, this.maxReference = 100});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          _MetricValueRow(
            label: row.label,
            value: row.value,
            valueText: row.text,
            maxReference: maxReference,
          ),
      ],
    );
  }
}

class _MetricValueRow extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;
  final double maxReference;

  const _MetricValueRow({
    required this.label,
    required this.value,
    required this.valueText,
    required this.maxReference,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final ratio = maxReference <= 0
        ? 0.0
        : (value / maxReference).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tt.titleMedium?.copyWith(color: t.textPrimary),
                ),
              ),
              Text(valueText, style: tt.titleMedium?.copyWith(color: t.accent)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: AppTokens.r8,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: t.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                t.accent.withOpacity(0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
