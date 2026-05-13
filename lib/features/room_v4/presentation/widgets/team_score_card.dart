import 'package:flutter/material.dart';
import '../../../../app_theme.dart';
import '../../domain/models/game_state.dart';
import 'player_score_card.dart';

class TeamScoreCard extends StatelessWidget {
  final String teamId;
  final List<String> playerIds;
  final GameState gameState;

  const TeamScoreCard({
    super.key,
    required this.teamId,
    required this.playerIds,
    required this.gameState,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isCricket = gameState.isCricket;

    final isCurrentTeam = playerIds.contains(gameState.currentPlayerId);

    final score = isCricket
        ? gameState.getTeamCricketPoints(teamId)
        : gameState.getTeamScore(teamId);

    final legs = gameState.getTeamLegsWon(teamId);
    final sets = gameState.getTeamSetsWon(teamId);

    final orderedIds = gameState.orderedPlayerIds
        .where((id) => playerIds.contains(id))
        .toList();

    final fg = isCurrentTeam ? t.green : t.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r8,
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(teamId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Set $sets  Leg $legs',
                  style: TextStyle(fontSize: 10, color: t.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
            ],
          ),
          const SizedBox(height: 2),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: orderedIds.map<Widget>((id) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: PlayerScoreCard(
                  playerId: id,
                  gameState: gameState,
                  position: gameState.getPlayerPosition(id),
                  isTeamMode: true,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}