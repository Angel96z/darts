/// File: training_throws_turns.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';

class TrainingThrowsTurns extends StatelessWidget {
  final int throwsCount;
  final int turns;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingThrowsTurns({
    super.key,
    required this.throwsCount,
    required this.turns,
  });

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _chip(BuildContext context, IconData icon, String value) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: t.surfaceHigh.withOpacity(0.65),
        border: Border.all(
          color: t.border.withOpacity(0.50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          Icon(
            icon,
            size: 18,
            color: t.textSecondary,
          ),

          const SizedBox(width: 6),

          Text(
            value,
            style: tt.titleSmall?.copyWith(color: t.textPrimary),
          ),

        ],
      ),
    );
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          _chip(context, Icons.gps_fixed, "$throwsCount"),

          const SizedBox(width: 10),

          _chip(context, Icons.refresh, "$turns"),

        ],
      ),
    );
  }
}
