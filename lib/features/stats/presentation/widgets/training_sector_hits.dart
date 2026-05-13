/// File: training_sector_hits.dart. Logica di presentazione per il riepilogo settori training.

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------

class TrainingSectorHits extends StatelessWidget {
  const TrainingSectorHits({
    super.key,
    required this.stats,
    required this.target,
    required this.totalThrows,
    this.maxHeight = 220,
  });

  final Map<String, Map<String, int>> stats;
  final String target;
  final int totalThrows;
  final double maxHeight;

  static const List<int> boardOrder = [
    20, 1, 18, 4, 13,
    6, 10, 15, 2, 17,
    3, 19, 7, 16, 8,
    11, 14, 9, 12, 5,
  ];

  String get _targetNumber => int.tryParse(target.substring(1))?.toString() ?? '';

  String get _targetType {
    if (target.startsWith('T')) return 'T';
    if (target.startsWith('D')) return 'D';
    return 'S';
  }

  List<String> _orderedSectors() {
    final targetValue = int.tryParse(_targetNumber);

    if (_targetNumber == '25' || targetValue == null) {
      return [
        if (_targetNumber == '25') '25',
        ...boardOrder.map((n) => n.toString()),
      ];
    }

    final index = boardOrder.indexOf(targetValue);
    if (index == -1) return boardOrder.map((n) => n.toString()).toList();

    final result = [_targetNumber];
    for (int d = 1; d < boardOrder.length; d++) {
      result
        ..add(boardOrder[(index - d + boardOrder.length) % boardOrder.length].toString())
        ..add(boardOrder[(index + d) % boardOrder.length].toString());
      if (result.length >= boardOrder.length) break;
    }
    return result.take(boardOrder.length).toList();
  }

  List<String> _buildOrdered() => [
    if (stats.containsKey('MISS')) 'MISS',
    ..._orderedSectors().where((s) => s == _targetNumber || stats.containsKey(s)),
    if (_targetNumber != '25' && stats.containsKey('25')) '25',
  ];

  @override
  Widget build(BuildContext context) {
    final ordered = _buildOrdered();
    return SizedBox(
      height: maxHeight,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: ordered.length,
        itemBuilder: (context, index) {
          final number = ordered[index];
          return _SectorRow(
            number: number,
            data: stats[number] ?? {},
            isTarget: number == _targetNumber,
            isMiss: number == 'MISS',
            targetType: _targetType,
            totalThrows: totalThrows,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row: settore con barre lineari S / D / T
// ---------------------------------------------------------------------------

class _SectorRow extends StatelessWidget {
  const _SectorRow({
    required this.number,
    required this.data,
    required this.isTarget,
    required this.isMiss,
    required this.targetType,
    required this.totalThrows,
  });

  final String number;
  final Map<String, int> data;
  final bool isTarget;
  final bool isMiss;
  final String targetType;
  final int totalThrows;

  int get _totalSectorHits => data.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final total = _totalSectorHits;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isTarget
            ? t.accent.withOpacity(0.08)
            : t.surfaceHigh.withOpacity(0.72),
        borderRadius: AppTokens.r16,
        border: Border.all(
          color: isTarget ? t.accent.withOpacity(0.60) : t.border,
          width: isTarget ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppTokens.r16,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent strip verticale — solo sul target
              if (isTarget)
                Container(width: 3, color: t.accent),

              // Numero settore + totale colpi
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTarget ? 10 : 12,
                  10,
                  8,
                  10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: isTarget ? 20 : 15,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: isTarget
                            ? t.accent
                            : isMiss
                            ? t.orange
                            : t.textPrimary,
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Separatore verticale
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: t.border.withOpacity(0.5),
              ),

              // Barre per ogni tipo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: isMiss
                      ? Center(
                    child: _TypeBar(
                      type: 'M',
                      hits: total,
                      isTargetType: false,
                      totalThrows: totalThrows,
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final type in ['S', 'D', 'T']) ...[
                        _TypeBar(
                          type: type,
                          hits: data[type] ?? 0,
                          isTargetType: isTarget && targetType == type,
                          totalThrows: totalThrows,
                        ),
                        if (type != 'T') const SizedBox(height: 5),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra lineare per un singolo tipo (S / D / T / M)
// ---------------------------------------------------------------------------

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.type,
    required this.hits,
    required this.isTargetType,
    required this.totalThrows,
  });

  final String type;
  final int hits;
  final bool isTargetType;
  final int totalThrows;

  double get _ratio =>
      totalThrows > 0 && hits > 0 ? (hits / totalThrows).clamp(0.0, 1.0) : 0.0;

  static Color _colorFor(AppTokens t, String type) => switch (type) {
    'T' => t.red,
    'D' => t.green,
    'S' => t.accent,
    _ => t.orange, // M / fallback
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = _colorFor(t, type);
    final ratio = _ratio;
    final percent = (ratio * 100).round();
    final hasHits = hits > 0;

    return Row(
      children: [
        // Label tipo
        SizedBox(
          width: 14,
          child: Text(
            type,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w900,
              color: hasHits || isTargetType ? color : t.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 7),

        // Barra di progresso
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: isTargetType ? 7 : 5,
              backgroundColor: t.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                hasHits ? color.withOpacity(isTargetType ? 1.0 : 0.75) : t.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Conteggio colpi
        SizedBox(
          width: 22,
          child: Text(
            hasHits ? '$hits' : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: hasHits ? t.textPrimary : t.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Percentuale
        SizedBox(
          width: 30,
          child: Text(
            hasHits ? '$percent%' : '',
            style: TextStyle(
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w600,
              color: t.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}