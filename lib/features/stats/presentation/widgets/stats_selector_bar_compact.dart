/// File: stats_selector_bar_compact.dart
/// TARGET: Barra di selezione compatta (Periodo/Sessione) senza controller
/// LOGIC GOAL: Gestire solo UI della selezione, callback esterni
/// REACTION: UI reagisce ai tap

import 'package:flutter/material.dart';

import '../../../../../app_theme.dart';

class StatsSelectorBarCompact extends StatelessWidget {
  final String modeLabel;
  final String rightLabel;
  final VoidCallback onModeTap;
  final VoidCallback onSelectorTap;

  const StatsSelectorBarCompact({
    super.key,
    required this.modeLabel,
    required this.rightLabel,
    required this.onModeTap,
    required this.onSelectorTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Row(
      children: [
        // Bottone modalità (Periodo / Sessione)
        GestureDetector(
          onTap: onModeTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: AppTokens.r10,
              border: Border.all(color: t.border),
              color: t.surfaceHigh,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(modeLabel, style: t.bodyBold(t.textPrimary)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: t.textSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bottone selezione (range / sessione specifica)
        Expanded(
          child: GestureDetector(
            onTap: onSelectorTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: AppTokens.r10,
                border: Border.all(color: t.border),
                color: t.surfaceHigh,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      rightLabel,
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
    );
  }
}