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

    const maxTurns = 30;
    final visibleTurns = turns.length > maxTurns
        ? turns.sublist(turns.length - maxTurns)
        : turns;

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

    return _box(
      singleDart
          ? 'Trend D$selectedDart'
          : 'Trend turni (3 freccette)',
      SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: singleDart ? 100 : 33,
                  getTitlesWidget: (v, _) {
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
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
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
                dotData: FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
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

    // ultimi 30 turni
    const maxTurns = 30;
    final visibleTurns = turns.length > maxTurns
        ? turns.sublist(turns.length - maxTurns)
        : turns;

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

    return _box(
      'Trend distanza (mm)',
      SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY == 0 ? 100 : maxY * 1.2,
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (maxY / 4).clamp(5, 50),
                  getTitlesWidget: (v, _) =>
                      Text('${v.toInt()}'),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  getTitlesWidget: (v, _) =>
                      Text('${v.toInt() + 1}'),
                ),
              ),
            ),
            borderData: FlBorderData(show: true),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 2,
                dotData: FlDotData(show: false),
              ),
            ],
          ),
        ),
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
