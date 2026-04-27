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
        ? _getTeamCricketPoints()
        : gameState.getTeamScore(teamId);
    final legs = gameState.getTeamLegsWon(teamId);
    final sets = gameState.getTeamSetsWon(teamId);

    final orderedIds = gameState.orderedPlayerIds
        .where((id) => playerIds.contains(id))
        .toList();

    final fg = isCurrentTeam ? t.green : t.textPrimary;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentTeam ? t.green.withOpacity(0.08) : t.surface,
        borderRadius: AppTokens.r10,
        border: Border.all(
          color: isCurrentTeam ? t.green.withOpacity(0.5) : t.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              /// TEAM NAME
              Text(
                teamId,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              /// SET / LEG
              Expanded(
                child: Text(
                  'Set $sets  Leg $legs',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              /// SCORE
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          /// PLAYERS
          Column(
            mainAxisSize: MainAxisSize.min,
            children: orderedIds.map<Widget>((id) {
              return PlayerScoreCard(
                playerId: id,
                gameState: gameState,
                position: gameState.getPlayerPosition(id),
                isTeamMode: true,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _getTeamCricketPoints() {
    int total = 0;
    for (final playerId in playerIds) {
      total = total + gameState.getCricketPoints(playerId);
    }
    return total;
  }
}