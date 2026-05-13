/// File: match_picker_sheet.dart
/// TARGET: Foglio di selezione match riutilizzabile
/// LOGIC GOAL: Mostrare lista match con ordinamento e selezione
/// REACTION: Callback onSelect restituisce match selezionato

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app_theme.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';

class MatchPickerSheet extends StatelessWidget {
  final List<LocalMatchRecord> matches;
  final ValueChanged<LocalMatchRecord> onSelect;
  final String? highlightedMatchId;

  const MatchPickerSheet({
    super.key,
    required this.matches,
    required this.onSelect,
    this.highlightedMatchId,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: t.divider,
              borderRadius: BorderRadius.circular(4), // ← r2 non esiste, uso 4
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Seleziona partita',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: t.divider),
          Expanded(
            child: matches.isEmpty
                ? Center(
              child: Text(
                'Nessuna partita trovata',
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            )
                : ListView.builder(
              itemCount: matches.length,
              itemBuilder: (ctx, i) {
                final m = matches[i];
                final isHighlighted = highlightedMatchId == m.localId || highlightedMatchId == m.remoteId;
                final gameConfig = m.gameConfig;
                final startingScore = gameConfig['startingScore'] ?? 501;
                final setsCount = m.matchSets.length;

                return Container(
                  color: isHighlighted
                      ? t.accent.withOpacity(0.08)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      Icons.sports_score,
                      color: isHighlighted ? t.accent : t.textSecondary,
                    ),
                    title: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(m.startTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isHighlighted ? t.accent : t.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$startingScore pts · $setsCount set · ${m.winnerName}',
                      style: TextStyle(fontSize: 11, color: t.textSecondary),
                    ),
                    trailing: isHighlighted
                        ? Icon(Icons.check_circle, color: t.accent, size: 18)
                        : null,
                    onTap: () => onSelect(m),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}