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
                  final isNumberClosedForAll = gameState.isCricketNumberClosedForAll(number);
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
    final color = isDead
        ? t.textMuted.withOpacity(0.3)
        : isClosed
        ? t.accent
        : t.textPrimary;

    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: color,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number == 25 ? 'B' : number.toString(),
          style: textStyle,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final hasMark = i < marks;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasMark ? color : Colors.transparent,
                border: Border.all(
                  color: color.withOpacity(hasMark ? 1 : 0.3),
                  width: 1,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}