import '../../domain/entities/match.dart';
import '../../domain/events/match_event.dart';
import '../../domain/value_objects/identifiers.dart';

class MatchReducer {
  const MatchReducer();

  Match apply(Match match, MatchEvent event) {
    if (event is TurnCommittedEvent || event is TurnBustEvent) {
      final payload = event.payload;

      final playerId = PlayerId(
        (payload['playerId'] ?? match.snapshot.scoreboard.currentTurnPlayerId.value) as String,
      );

      final previousScore =
          match.snapshot.scoreboard.playerScores[playerId] ?? match.config.startScore;

      final nextScore = (payload['nextScore'] as num?)?.toInt() ?? previousScore;
      final isBust = (payload['isBust'] as bool?) ?? false;
      final isCheckout = (payload['isCheckout'] as bool?) ?? false;
      final reason = (payload['reason'] ?? '') as String;

      final updatedScores = <PlayerId, int>{
        ...match.snapshot.scoreboard.playerScores,
        playerId: nextScore,
      };

      final roster = match.roster.players;
      PlayerId nextPlayer = playerId;

      if (roster.isNotEmpty) {
        final currentIndex = roster.indexWhere((p) => p.playerId == playerId);
        if (currentIndex == -1) {
          nextPlayer = roster.first.playerId;
        } else {
          nextPlayer = roster[(currentIndex + 1) % roster.length].playerId;
        }
      }

      final draft = _draftFromPayload(payload['draft'], playerId, match);

      final committed = TurnCommitted(
        turnId: event.eventId.value,
        draft: draft,
        resolution: TurnResolution(
          isBust: isBust,
          isCheckout: isCheckout,
          nextScore: nextScore,
          reason: reason,
        ),
        committedAt: event.createdAt,
      );

      final updatedTurns = [...match.snapshot.lastTurns, committed];

      if (isCheckout) {
        final winnerId = playerId;

        final playerScores = updatedScores;

        final rankingEntries = playerScores.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        final ranking = rankingEntries.map((e) => e.key).toList();

        final highestScore = updatedTurns.isEmpty
            ? 0
            : updatedTurns
            .map((t) => t.draft.total)
            .reduce((a, b) => a > b ? a : b);

        return Match(
          id: match.id,
          roomId: match.roomId,
          config: match.config,
          roster: match.roster,
          legs: match.legs,
          sets: match.sets,
          result: MatchResult(
            winnerPlayerId: winnerId,
            winnerTeamId: null,
            ranking: ranking,
            playerStats: const <PlayerMatchStats>[],
            teamStats: const <TeamMatchStats>[],
            mvpPlayerId: winnerId,
            highestScore: highestScore,
          ),
          createdAt: match.createdAt,
          snapshot: MatchStateSnapshot(
            matchState: MatchState.matchFinished,
            status: MatchStatus.completed,
            currentSet: match.snapshot.currentSet,
            currentLeg: match.snapshot.currentLeg,
            currentTurn: match.snapshot.currentTurn + 1,
            scoreboard: Scoreboard(
              playerScores: updatedScores,
              teamScores: match.snapshot.scoreboard.teamScores,
              currentTurnPlayerId: playerId,
            ),
            lastTurns: updatedTurns,
          ),
        );
      }

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
          currentTurn: match.snapshot.currentTurn + 1,
          scoreboard: Scoreboard(
            playerScores: updatedScores,
            teamScores: match.snapshot.scoreboard.teamScores,
            currentTurnPlayerId: nextPlayer,
          ),
          lastTurns: updatedTurns,
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

  TurnDraft _draftFromPayload(Object? rawDraft, PlayerId playerId, Match match) {
    if (rawDraft is Map) {
      final draftMap = Map<String, dynamic>.from(rawDraft);
      final inputs = List<Map<String, dynamic>>.from(
        (draftMap['inputs'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
            const [],
      ).map((it) {
        return DartInput(
          rawValue: (it['rawValue'] as num?)?.toInt() ?? 0,
          multiplier: (it['multiplier'] as num?)?.toInt() ?? 1,
        );
      }).toList();

      return TurnDraft(
        playerId: PlayerId((draftMap['playerId'] ?? playerId.value) as String),
        legNumber: (draftMap['legNumber'] as num?)?.toInt() ?? match.snapshot.currentLeg,
        turnNumber: (draftMap['turnNumber'] as num?)?.toInt() ?? match.snapshot.currentTurn,
        inputs: inputs,
        inputMode: InputMode.values.firstWhere(
              (e) => e.name == ((draftMap['inputMode'] ?? InputMode.totalTurnInput.name) as String),
          orElse: () => InputMode.totalTurnInput,
        ),
      );
    }

    return TurnDraft(
      playerId: playerId,
      legNumber: match.snapshot.currentLeg,
      turnNumber: match.snapshot.currentTurn,
      inputs: const [],
      inputMode: InputMode.totalTurnInput,
    );
  }
}