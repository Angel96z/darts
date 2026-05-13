// lib/features/game/presentation/widgets/player_score_card.dart

import 'package:flutter/material.dart';
import '../../domain/models/game_state.dart';
import '../../../../app_theme.dart';

class PlayerScoreCard extends StatelessWidget {
  final String playerId;
  final GameState gameState;
  final bool isTeamMode;
  final int position;

  const PlayerScoreCard({
    super.key,
    required this.playerId,
    required this.gameState,
    this.isTeamMode = false,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    if (gameState.players.length <= 1) return const SizedBox.shrink();

    final t = AppTokens.of(context);
    final player = gameState.getPlayer(playerId);
    final isCurrent = gameState.currentPlayerId == playerId;
    final isCricket = gameState.isCricket;

    final fgColor = isCurrent ? t.green : t.textPrimary;

    // ========== TEAM MODE (X01 o Cricket) ==========
// In player_score_card.dart, sostituisci la sezione TEAM MODE (righe 46-113 circa) con:

// ========== TEAM MODE ==========
// In player_score_card.dart, sostituisci la sezione TEAM MODE - CRICKET (righe 46-80 circa) con:

// In player_score_card.dart, sostituisci la sezione TEAM MODE - CRICKET con:

    // ========== TEAM MODE ==========
    if (isTeamMode) {
      final teamId = gameState.getPlayerTeam(playerId);

      if (isCricket) {
        final cricketNumbers = [20, 19, 18, 17, 16, 15, 25];
        final marks = gameState.cricketMarks[playerId] ?? {};
        final individualPoints = gameState.getCricketPoints(playerId);

        final bgColor = isCurrent ? t.green.withOpacity(0.12) : Colors.transparent;
        final fgColor = isCurrent ? t.green : t.textPrimary;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      player.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fgColor),
                    ),
                  ),
                  Text(
                    '$individualPoints',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fgColor),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 1,
                children: cricketNumbers.map((number) {
                  final markCount = marks[number] ?? 0;
                  final isClosed = markCount >= 3;
                  final isClosedGlobally = gameState.isCricketNumberClosedGlobally(number);
                  final color = isClosedGlobally
                      ? t.textMuted.withOpacity(0.4)
                      : (isClosed ? t.accent : t.textSecondary);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        number == 25 ? 'B' : number.toString(),
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color),
                      ),
                      const SizedBox(width: 1),
                      Row(
                        children: List.generate(3, (i) {
                          final hasMark = i < markCount;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasMark ? color : Colors.transparent,
                              border: Border.all(color: color.withOpacity(hasMark ? 1 : 0.3), width: 0.3),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      } else {
        // TEAM MODE - X01
        final displayValue = gameState.getPlayerLiveScore(playerId).toString();
        final bgColor = isCurrent ? t.green.withOpacity(0.12) : Colors.transparent;
        final fgColor = isCurrent ? t.green : t.textPrimary;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fgColor),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fgColor),
              ),
            ],
          ),
        );
      }
    }
    // ========== SINGLE MODE ==========
    if (isCricket) {
      // SINGLE MODE - CRICKET (con pallini)
      final cricketPoints = gameState.getCricketPoints(playerId);
      final legsWon = gameState.getLegsWonByPlayer(playerId);
      final setsWon = gameState.getSetsWonByPlayer(playerId);
      final marks = gameState.cricketMarks[playerId] ?? {};
      final cricketNumbers = [20, 19, 18, 17, 16, 15, 25];

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isCurrent ? t.green.withOpacity(0.08) : t.surface,
          borderRadius: AppTokens.r8,
          border: Border.all(
            color: isCurrent ? t.green.withOpacity(0.5) : t.border,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Riga 1: Nome + Set/Leg
            Row(
              children: [
                Expanded(
                  child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ),
                Text(
                  'Set $setsWon Leg $legsWon',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Riga 2: Punteggio + markers
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$cricketPoints',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fgColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: cricketNumbers.map((number) {
                      final markCount = marks[number] ?? 0;
                      final isClosed = markCount >= 3;
                      final isClosedGlobally = gameState.isCricketNumberClosedGlobally(number);
                      final color = isClosedGlobally
                          ? t.textMuted.withOpacity(0.4)
                          : (isClosed ? t.accent : t.textPrimary);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: !isClosedGlobally && isClosed ? t.accent.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              number == 25 ? 'B' : number.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Row(
                              children: List.generate(3, (i) {
                                final hasMark = i < markCount;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasMark ? color : Colors.transparent,
                                    border: Border.all(
                                      color: color.withOpacity(hasMark ? 1 : 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ========== SINGLE MODE - X01 ==========
    final legsWon = gameState.getLegsWonByPlayer(playerId);
    final setsWon = gameState.getSetsWonByPlayer(playerId);
    final displayScore = gameState.getPlayerLiveScore(playerId).toString();
    final winLabel = displayScore == '0' ? 'WIN' : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrent ? t.green.withOpacity(0.08) : t.surface,
        borderRadius: AppTokens.r10,
        border: Border.all(
          color: isCurrent ? t.green.withOpacity(0.5) : t.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  winLabel ?? displayScore,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: winLabel != null ? t.accent : fgColor,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Set $setsWon',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: t.textMuted,
                    ),
                  ),
                  Text(
                    'Leg $legsWon',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}