import 'package:flutter/material.dart';

class TrainingHitStats extends StatelessWidget {
  final int hit;
  final int miss;
  final int streak;
  final int best;

  const TrainingHitStats({
    super.key,
    required this.hit,
    required this.miss,
    required this.streak,
    required this.best,
  });

  Widget _item(
      BuildContext context,
      IconData icon,
      int value,
      Color color,
      ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        Icon(icon, size: 16, color: color),

        const SizedBox(width: 4),

        Text(
          "$value",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),

      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [

          _item(context, Icons.check, hit, Colors.green),
          _item(context, Icons.close, miss, Colors.red),
          _item(context, Icons.local_fire_department, streak, Colors.orange),
          _item(context, Icons.emoji_events, best, Colors.blue),

        ],
      ),
    );
  }
}