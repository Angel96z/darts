import 'package:flutter/material.dart';

class TrainingThrowsTurns extends StatelessWidget {
  final int throwsCount;
  final int turns;

  const TrainingThrowsTurns({
    super.key,
    required this.throwsCount,
    required this.turns,
  });

  Widget _chip(BuildContext context, IconData icon, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceVariant.withOpacity(0.65),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          Icon(
            icon,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),

          const SizedBox(width: 6),

          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),

        ],
      ),
    );
  }

  @override
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