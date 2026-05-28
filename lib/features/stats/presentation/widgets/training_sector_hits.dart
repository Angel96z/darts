/// File: training_sector_hits.dart - VERSIONE BARRE COMPATTE (colori distinti)

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';

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
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        // SFONDO: surface normale per tutti, MAI trasparente
        color: t.surface,
        borderRadius: AppTokens.r8,
        // BORDO: accent solo per target, altrimenti border normale
        border: Border.all(
          color: isTarget ? t.accent : t.border,
          width: isTarget ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // NUMERO SETTORE
          Container(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: (isTarget ? tt.titleMedium : tt.bodyMedium)?.copyWith(
                    color: isTarget ? t.accent : t.textPrimary,
                    fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (_totalSectorHits > 0)
                  Text(
                    '${_totalSectorHits}',
                    style: tt.labelSmall?.copyWith(color: t.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // BARRE S/D/T
          Expanded(
            child: isMiss
                ? _MissBar(
              hits: _totalSectorHits,
              totalThrows: totalThrows,
            )
                : Row(
              children: [
                _TypeBar(
                  type: 'S',
                  hits: data['S'] ?? 0,
                  color: t.accent,
                  isTargetType: isTarget && targetType == 'S',
                  totalThrows: totalThrows,
                ),
                const SizedBox(width: 6),
                _TypeBar(
                  type: 'D',
                  hits: data['D'] ?? 0,
                  color: t.green,
                  isTargetType: isTarget && targetType == 'D',
                  totalThrows: totalThrows,
                ),
                const SizedBox(width: 6),
                _TypeBar(
                  type: 'T',
                  hits: data['T'] ?? 0,
                  color: t.red,
                  isTargetType: isTarget && targetType == 'T',
                  totalThrows: totalThrows,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.type,
    required this.hits,
    required this.color,
    required this.isTargetType,
    required this.totalThrows,
  });

  final String type;
  final int hits;
  final Color color;
  final bool isTargetType;
  final int totalThrows;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    final percent = totalThrows > 0 ? (hits / totalThrows).clamp(0.0, 1.0) : 0.0;
    final hasHits = hits > 0;

    return Expanded(
      child: Column(
        children: [
          // Label S/D/T
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isTargetType ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: AppTokens.r4,
            ),
            child: Text(
              type,
              style: tt.labelSmall?.copyWith(
                color: isTargetType ? color : (hasHits ? t.textSecondary : t.textMuted),
                fontWeight: isTargetType ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Barra progresso
          ClipRRect(
            borderRadius: AppTokens.r4,
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: t.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(
                hasHits ? color : t.border,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Numero colpi
          Text(
            hasHits ? '$hits' : '—',
            style: tt.labelSmall?.copyWith(
              color: hasHits ? t.textSecondary : t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissBar extends StatelessWidget {
  const _MissBar({
    required this.hits,
    required this.totalThrows,
  });

  final int hits;
  final int totalThrows;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    final percent = totalThrows > 0 ? (hits / totalThrows).clamp(0.0, 1.0) : 0.0;
    final color = t.orange;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: AppTokens.r8,
          ),
          child: Text(
            'MISS',
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: AppTokens.r4,
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: t.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$hits',
          style: tt.bodyMedium?.copyWith(color: t.textPrimary),
        ),
        Text(
          ' (${(percent * 100).round()}%)',
          style: tt.labelSmall?.copyWith(color: t.textMuted),
        ),
      ],
    );
  }
}