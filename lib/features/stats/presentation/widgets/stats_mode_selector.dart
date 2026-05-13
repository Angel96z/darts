/// File: stats_mode_selector.dart
/// Widget per selezionare la modalità di gioco nelle statistiche

import 'package:flutter/material.dart';
import '../../../../../app_theme.dart';

enum StatsGameMode {
  bull,
  x01,
  cricket,
}

extension StatsGameModeExtension on StatsGameMode {
  String get label {
    switch (this) {
      case StatsGameMode.bull:
        return 'Bullseye';
      case StatsGameMode.x01:
        return 'X01';
      case StatsGameMode.cricket:
        return 'Cricket';
    }
  }

  IconData get icon {
    switch (this) {
      case StatsGameMode.bull:
        return Icons.center_focus_strong;
      case StatsGameMode.x01:
        return Icons.sports_score;
      case StatsGameMode.cricket:
        return Icons.sports_cricket;
    }
  }
}

class StatsModeSelector extends StatelessWidget {
  final StatsGameMode selectedMode;
  final ValueChanged<StatsGameMode> onModeChanged;

  const StatsModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: StatsGameMode.values.map((mode) {
          final isSelected = selectedMode == mode;

          return GestureDetector(
            onTap: () => onModeChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? t.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 18,
                    color: isSelected ? t.accentFg : t.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? t.accentFg : t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}