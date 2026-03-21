import '../../domain/entities/match.dart';
import '../../domain/value_objects/identifiers.dart';
import '../dto/match_dto.dart';

class MatchMapper {
  const MatchMapper();

  MatchDto toDto(Match match) {
    return MatchDto(
      matchId: match.id.value,
      roomId: match.roomId.value,
      state: match.snapshot.matchState.name,
      config: {
        'variant': match.config.variant.name,
        'inMode': match.config.inMode.name,
        'outMode': match.config.outMode.name,
      },
      scoreboard: {
        'playerScores': match.snapshot.scoreboard.playerScores.map((k, v) => MapEntry(k.value, v)),
      },
    );
  }

  Match toDomain(MatchDto dto) {
    return Match(
      id: MatchId(dto.matchId),
      roomId: RoomId(dto.roomId),
      config: MatchConfig(
        gameType: GameType.x01,
        variant: X01Variant.x501,
        inMode: InMode.straightIn,
        outMode: OutMode.doubleOut,
        matchMode: MatchMode.legsOnly,
        legsTargetType: MatchTargetType.firstTo,
        legsTargetValue: 1,
        setsTargetType: null,
        setsTargetValue: null,
        teamMode: TeamMode.solo,
        teamSharedScore: false,
        finishConstraintEnabled: false,
        undoRequiresHost: true,
        inputSnapshot: const {},
      ),
      roster: const MatchRoster(players: [], teams: []),
      snapshot: MatchStateSnapshot(
        matchState: MatchState.values.firstWhere((e) => e.name == dto.state),
        status: MatchStatus.active,
        currentSet: 1,
        currentLeg: 1,
        currentTurn: 1,
        scoreboard: Scoreboard(
          playerScores: (dto.scoreboard['playerScores'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(PlayerId(k), (v as num).toInt())),
          teamScores: const {},
          currentTurnPlayerId: const PlayerId(''),
        ),
        lastTurns: const [],
      ),
      legs: const [],
      sets: const [],
      result: null,
      createdAt: DateTime.now(),
    );
  }
}
