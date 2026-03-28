/// File: training_sector_hits.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';

class TrainingSectorHits extends StatelessWidget {
  final Map<String, Map<String, int>> stats;
  final String target;
  final int totalThrows;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingSectorHits({
    super.key,
    required this.stats,
    required this.target,
    required this.totalThrows,
  });

  static const _colorT = Color(0xFFE05252);
  static const _colorD = Color(0xFF4CAF82);
  static const _colorS = Color(0xFF5B8FE8);
  static const _colorMiss = Color(0xFFD9534F);
  static const _colorTarget = Color(0xFFFFF3CD);
  static const _borderTarget = Color(0xFFE8A020);

  static const List<int> boardOrder = [
    20, 1, 18, 4, 13,
    6, 10, 15, 2, 17,
    3, 19, 7, 16, 8,
    11, 14, 9, 12, 5,
  ];

  String get _targetType {
    if (target.startsWith('T')) return 'T';
    if (target.startsWith('D')) return 'D';
    return 'S';
  }

  String get _targetNumber {
    final value = int.tryParse(target.substring(1));
    if (value == null) return '';
    return value.toString();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  List<String> _orderedSectors() {
    if (_targetNumber == '25') {
      return ['25', ...boardOrder.map((e) => e.toString())];
    }

    final targetValue = int.tryParse(_targetNumber);
    if (targetValue == null) {
      return boardOrder.map((e) => e.toString()).toList();
    }

    final index = boardOrder.indexOf(targetValue);
    if (index == -1) {
      return boardOrder.map((e) => e.toString()).toList();
    }

    final result = <String>[_targetNumber];

    for (int d = 1; d < boardOrder.length; d++) {
      result.add(boardOrder[(index - d + boardOrder.length) % boardOrder.length].toString());
      result.add(boardOrder[(index + d) % boardOrder.length].toString());

      if (result.length >= boardOrder.length) break;
    }

    return result.take(boardOrder.length).toList();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _bar(double value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        color: color.withOpacity(0.12),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _line({
    required String label,
    required double value,
    required Color color,
    required int hits,
    required bool showHits,
    required bool isTargetLine,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _bar(value, color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            value > 0 ? "${(value * 100).round()}%" : "—",
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              color: value > 0 || isTargetLine ? Colors.black87 : Colors.black26,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: showHits
              ? Text(
            hits.toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _sectorCard(String number, Map<String, int> data) {
    if (number == "MISS") {
      final miss = data.values.fold(0, (a, b) => a + b);
      final pmiss = totalThrows == 0 ? 0.0 : miss / totalThrows;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _colorMiss.withOpacity(0.05),
          border: Border.all(color: _colorMiss.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              child: Text(
                "MISS",
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: _colorMiss,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    child: Text(
                      "M",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _colorMiss,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _bar(pmiss, _colorMiss),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      pmiss > 0 ? "${(pmiss * 100).round()}%" : "—",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      miss.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isTargetNumber = number == _targetNumber;

    final s = data["S"] ?? 0;
    final d = data["D"] ?? 0;
    final t = data["T"] ?? 0;

    final ps = totalThrows == 0 ? 0.0 : s / totalThrows;
    final pd = totalThrows == 0 ? 0.0 : d / totalThrows;
    final pt = totalThrows == 0 ? 0.0 : t / totalThrows;

    final isBull = number == '25';

    final showT = !isBull && (isTargetNumber ? _targetType == 'T' || t > 0 : t > 0);
    final showD = isTargetNumber ? _targetType == 'D' || d > 0 : d > 0;
    final showS = isTargetNumber ? _targetType == 'S' || s > 0 : s > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isTargetNumber ? _colorTarget : Colors.white,
        border: Border.all(
          color: isTargetNumber ? _borderTarget : Colors.black12,
          width: isTargetNumber ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              number,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isTargetNumber ? 15 : 12,
                color: isTargetNumber ? _borderTarget : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showT)
                  _line(
                    label: "T",
                    value: pt,
                    color: _colorT,
                    hits: t,
                    showHits: true,
                    isTargetLine: isTargetNumber && _targetType == 'T',
                  ),
                if (showD)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _line(
                      label: "D",
                      value: pd,
                      color: _colorD,
                      hits: d,
                      showHits: true,
                      isTargetLine: isTargetNumber && _targetType == 'D',
                    ),
                  ),
                if (showS)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _line(
                      label: "S",
                      value: ps,
                      color: _colorS,
                      hits: s,
                      showHits: true,
                      isTargetLine: isTargetNumber && _targetType == 'S',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final ordered = <String>[
      if (stats.containsKey("MISS")) "MISS",
      ..._orderedSectors().where((s) => stats.containsKey(s)),
    ];

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification) {
// quando sei già al limite → lascia propagare al parent
          return false;
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: ordered.length,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, i) {
          final number = ordered[i];
          final data = stats[number] ?? {};
          return _sectorCard(number, data);
        },
      ),
    );
  }
}
