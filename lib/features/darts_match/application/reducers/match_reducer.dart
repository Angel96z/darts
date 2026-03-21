import '../../domain/entities/match.dart';
import '../../domain/events/match_event.dart';

class MatchReducer {
  const MatchReducer();

  Match apply(Match match, MatchEvent event) {
    if (event is TurnCommittedEvent || event is TurnBustEvent) {
      final payload = event.payload;
      final playerId = match.snapshot.scoreboard.currentTurnPlayerId;
      final previous = match.snapshot.scoreboard.playerScores[playerId] ?? match.config.startScore;
      final next = payload['nextScore'] as int? ?? previous;
      final updatedScores = {...match.snapshot.scoreboard.playerScores, playerId: next};
      final nextTurn = match.snapshot.currentTurn + 1;
      final roster = match.roster.players;
      final currentIndex = roster.indexWhere((p) => p.playerId == playerId);
      final nextPlayer = roster[(currentIndex + 1) % roster.length].playerId;
      return Match(
        id: match.id,
        roomId: match.roomId,
        config: match.config,
        roster: match.roster,
        legs: match.legs,
        sets: match.sets,
        result: match.result,
        createdAt: match.createdAt,
        snapshot: MatchStateSnapshot(
          matchState: MatchState.turnActive,
          status: match.snapshot.status,
          currentSet: match.snapshot.currentSet,
          currentLeg: match.snapshot.currentLeg,
          currentTurn: nextTurn,
          scoreboard: Scoreboard(
            playerScores: updatedScores,
            teamScores: match.snapshot.scoreboard.teamScores,
            currentTurnPlayerId: nextPlayer,
          ),
          lastTurns: match.snapshot.lastTurns,
        ),
      );
    }

    if (event is MatchWonEvent) {
      return Match(
        id: match.id,
        roomId: match.roomId,
        config: match.config,
        roster: match.roster,
        legs: match.legs,
        sets: match.sets,
        result: match.result,
        createdAt: match.createdAt,
        snapshot: MatchStateSnapshot(
          matchState: MatchState.matchFinished,
          status: MatchStatus.completed,
          currentSet: match.snapshot.currentSet,
          currentLeg: match.snapshot.currentLeg,
          currentTurn: match.snapshot.currentTurn,
          scoreboard: match.snapshot.scoreboard,
          lastTurns: match.snapshot.lastTurns,
        ),
      );
    }

    return match;
  }
}
