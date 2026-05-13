/// stats_filter_bar.dart - Widget condiviso per tutte le statistiche

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../shared/stats_filter.dart';

class StatsFilterBar extends StatelessWidget {
  final StatsFilterState state;
  final VoidCallback onModeTap;
  final VoidCallback onSelectorTap;
  final Widget? leadingChild;

  const StatsFilterBar({
    super.key,
    required this.state,
    required this.onModeTap,
    required this.onSelectorTap,
    this.leadingChild,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (leadingChild != null) ...[
            leadingChild!,
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onModeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
                color: t.surfaceHigh,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.modeLabel, style: t.bodyBold(t.textPrimary)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: t.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onSelectorTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                  color: t.surfaceHigh,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.displayLabel,
                        style: t.bodyBold(t.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: t.textSecondary, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<StatsFilterMode?> showStatsModeDialog(BuildContext context) async {
  final t = AppTokens.of(context);

  return showDialog<StatsFilterMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: t.surface,
      title: Text('Seleziona modalità', style: t.bodyBold(t.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.calendar_today, color: t.accent),
            title: Text('Periodo', style: t.bodyBold(t.textPrimary)),
            subtitle: Text('Seleziona un intervallo di date', style: t.bodySmall(t.textSecondary)),
            onTap: () => Navigator.pop(ctx, StatsFilterMode.period),
          ),
          Divider(color: t.divider),
          ListTile(
            leading: Icon(Icons.sports_score, color: t.accent),
            title: Text('Sessione', style: t.bodyBold(t.textPrimary)),
            subtitle: Text('Seleziona una singola sessione', style: t.bodySmall(t.textSecondary)),
            onTap: () => Navigator.pop(ctx, StatsFilterMode.session),
          ),
        ],
      ),
    ),
  );
}

Future<DateTimeRange?> showPeriodPickerDialog(
    BuildContext context, {
      DateTimeRange? initialRange,
    }) async {
  final now = DateTime.now();

  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: now,
    initialDateRange: initialRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 30),
          end: now,
        ),
  );
}