import 'package:flutter/material.dart';
import '../../../../app_theme.dart';
import '../../domain/models/game_state.dart';

class CricketBoard extends StatelessWidget {
  final GameState gameState;
  const CricketBoard({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final currentPlayerId = gameState.currentPlayerId;
    final marks = gameState.cricketMarks[currentPlayerId] ?? {};
    final points = gameState.getCricketPoints(currentPlayerId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Griglia numeri minimal
          LayoutBuilder(
            builder: (context, constraints) {
              final numbers = [20, 19, 18, 17, 16, 15, 25];
              final itemWidth = (constraints.maxWidth - 18) / 7;
              return Wrap(
                spacing: 3,
                runSpacing: 6,
                children: numbers.map((number) {
                  final markCount = marks[number] ?? 0;
                  final isClosed = markCount >= 3;
                  final isNumberClosedForAll = gameState
                      .isCricketNumberClosedForAll(number);
                  return SizedBox(
                    width: itemWidth,
                    child: _CricketNumberTile(
                      number: number,
                      marks: markCount,
                      isClosed: isClosed,
                      isDead: isNumberClosedForAll,
                      t: t,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CricketNumberTile extends StatelessWidget {
  final int number;
  final int marks;
  final bool isClosed;
  final bool isDead;
  final AppTokens t;

  const _CricketNumberTile({
    required this.number,
    required this.marks,
    required this.isClosed,
    required this.isDead,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final deadColor = Color.lerp(
      t.textMuted,
      Colors.redAccent,
      0.55,
    )!.withOpacity(0.38);

    final color = isDead
        ? deadColor
        : isClosed
        ? t.accent
        : t.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number == 25 ? 'B' : number.toString(),
          style: (tt.titleMedium ?? AppTokens.scoreSmallStyle).copyWith(
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: isDead ? 32 : 32,
          height: isDead ? 32 : 32,
          child: CustomPaint(
            painter: _CricketMarksPainter(
              marks: marks.clamp(0, 3),
              color: color,
              emptyColor: isDead
                  ? deadColor.withOpacity(0.10)
                  : color.withOpacity(0.12),
            ),
          ),
        ),
      ],
    );
  }
}

class _CricketMarksPainter extends CustomPainter {
  final int marks;
  final Color color;
  final Color emptyColor;

  const _CricketMarksPainter({
    required this.marks,
    required this.color,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final inactivePaint = Paint()
      ..color = emptyColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final firstSlashPaint = marks >= 1 ? activePaint : inactivePaint;
    final secondSlashPaint = marks >= 2 ? activePaint : inactivePaint;
    final circlePaint = marks >= 3 ? activePaint : inactivePaint;

    // Primo segno: /
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.78),
      Offset(size.width * 0.70, size.height * 0.22),
      firstSlashPaint,
    );

    // Secondo segno: \  -> forma X
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.22),
      Offset(size.width * 0.70, size.height * 0.78),
      secondSlashPaint,
    );

    // Terzo segno: cerchio sopra la X
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      size.width * 0.34,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CricketMarksPainter oldDelegate) {
    return oldDelegate.marks != marks ||
        oldDelegate.color != color ||
        oldDelegate.emptyColor != emptyColor;
  }
}
