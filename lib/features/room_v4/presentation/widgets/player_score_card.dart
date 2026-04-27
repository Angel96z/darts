// ════════ player_score_card.dart ════════
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

    // TEAM MODE (invariato)
    if (isTeamMode) {
      final displayValue = isCricket
          ? gameState.getCricketPoints(playerId).toString()
          : gameState.getPlayerLiveScore(playerId).toString();

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(player.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fgColor)),
          ),
          Text(displayValue,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fgColor)),
        ]),
      );
    }

    // SINGLE MODE - CRICKET (layout compatto verticale)
// SINGLE MODE - CRICKET (layout compatto verticale)
    if (isCricket) {
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
            // 🔥 Riga 2: Punteggio + markers sulla stessa riga
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Punteggio Cricket
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
                // Numeri Cricket con pallini (Wrap orizzontale)
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: cricketNumbers.map((number) {
                      final markCount = marks[number] ?? 0;
                      final isClosed = markCount >= 3;
                      final color = isClosed ? t.accent : t.textSecondary;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isClosed ? t.accent.withOpacity(0.1) : Colors.transparent,
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
    // SINGLE MODE - X01 (originale invariato)
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