// match_history_table.dart
import 'package:flutter/material.dart';
import '../../../../app_theme.dart';
import '../../../room_v4/domain/models/player_turn.dart';

/// Widget pubblico per la tabella cronologica dei turni (X01)
class MatchHistoryTable extends StatelessWidget {
  final int startScore;
  final List<HistoryRowData> rows;
  final bool showHeader;

  const MatchHistoryTable({
    super.key,
    required this.startScore,
    required this.rows,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  'SCORE',
                  style: tt.labelSmall?.copyWith(color: t.textMuted),
                ),
              ),
              Text('$startScore', style: tt.titleSmall?.copyWith(color: t.textSecondary)),
              const SizedBox(width: 24),
              Text('R', style: tt.labelSmall?.copyWith(color: t.textMuted)),
            ]),
          ),
          Container(height: 1, color: t.divider),
        ],
        if (rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun turno ancora',
                style: tt.bodySmall?.copyWith(color: t.textMuted),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (_, i) => _HistoryRow(row: rows[i], t: t),
          ),
      ],
    );
  }
}

/// Dati per una riga della cronologia
class HistoryRowData {
  final String turnTotal;
  final String dartsLabel;
  final String scoreAfterTurn;
  final String roundNumber;
  final bool isBust;
  final bool isCheckout;

  const HistoryRowData({
    required this.turnTotal,
    required this.dartsLabel,
    required this.scoreAfterTurn,
    required this.roundNumber,
    required this.isBust,
    required this.isCheckout,
  });

  factory HistoryRowData.fromTurn(PlayerTurn turn) {
    return HistoryRowData(
      turnTotal: turn.isBust ? '0' : '${turn.total}',
      dartsLabel: turn.throws.isEmpty ? '-' : turn.throws.map((d) => d.label).join(' · '),
      scoreAfterTurn: '${turn.score}',
      roundNumber: '${turn.roundNumber}',
      isBust: turn.isBust,
      isCheckout: turn.isCheckout,
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryRowData row;
  final AppTokens t;

  const _HistoryRow({required this.row, required this.t});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scoreColor = row.isCheckout ? t.green : row.isBust ? t.red : t.textPrimary;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Text(row.turnTotal, style: tt.titleSmall?.copyWith(color: scoreColor)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                row.dartsLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: t.textMuted),
              ),
            ),
          ]),
        ),
        SizedBox(
          width: 44,
          child: Text(row.scoreAfterTurn, textAlign: TextAlign.right,
              style: tt.titleSmall?.copyWith(
                color: row.isCheckout ? t.green : t.textSecondary,
              )),
        ),
        SizedBox(
          width: 24,
          child: Text(row.roundNumber, textAlign: TextAlign.right,
              style: tt.labelSmall?.copyWith(color: t.textMuted)),
        ),
      ]),
    );
  }
}
