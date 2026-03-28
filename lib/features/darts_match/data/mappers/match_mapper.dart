/// File: match_mapper.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

import '../../domain/entities/identity.dart';
import '../../domain/entities/match.dart';
import '../../domain/policies/input_fidelity_policy.dart';
import '../../domain/value_objects/identifiers.dart';
import '../dto/match_dto.dart';

class MatchMapper {
  const MatchMapper();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  MatchDto toDto(Match match) {
    /// Funzione: descrive in modo semplice questo blocco di logica.
    return MatchDto(
      matchId: match.id.value,
      roomId: match.roomId.value,
      state: match.snapshot.matchState.name,
      config: {
        'gameType': match.config.gameType.name,
        'variant': match.config.variant.name,
        'inMode': match.config.inMode.name,
        'outMode': match.config.outMode.name,
        'matchMode': match.config.matchMode.name,
        'legsTargetType': match.config.legsTargetType.name,
        'legsTargetValue': match.config.legsTargetValue,
        'setsTargetType': match.config.setsTargetType?.name,
        'setsTargetValue': match.config.setsTargetValue,
        'teamMode': match.config.teamMode.name,
        'teamSharedScore': match.config.teamSharedScore,
        'finishConstraintEnabled': match.config.finishConstraintEnabled,
        'undoRequiresHost': match.config.undoRequiresHost,
        'inputSnapshot': {
          for (final entry in match.config.inputSnapshot.entries)
            entry.key.value: {
              'mode': entry.value.mode.name,
            },
        },
      },
      roster: {
        'players': [
          for (final player in match.roster.players)
            {
              'playerId': player.playerId.value,
              'order': player.order,
              'teamId': player.teamId?.value,
              'deviceId': player.deviceId,
            },
        ],
        'teams': [
          for (final team in match.roster.teams)
            {
              'id': team.id.value,
              'name': team.name,
              'memberIds': team.memberIds.map((e) => e.value).toList(),
              'sharedScore': team.sharedScore,
            },
        ],
      },
      snapshot: {
        'status': match.snapshot.status.name,
        'currentSet': match.snapshot.currentSet,
        'currentLeg': match.snapshot.currentLeg,
        'currentTurn': match.snapshot.currentTurn,
        'scoreboard': {
          'playerScores': {
            for (final entry in match.snapshot.scoreboard.playerScores.entries)
              entry.key.value: entry.value,
          },
          'teamScores': {
            for (final entry in match.snapshot.scoreboard.teamScores.entries)
              entry.key.value: entry.value,
          },
          'currentTurnPlayerId': match.snapshot.scoreboard.currentTurnPlayerId.value,
        },
        'lastTurns': [
          for (final turn in match.snapshot.lastTurns)
            {
              'turnId': turn.turnId,
              'committedAt': turn.committedAt.toIso8601String(),
              'draft': {
                'playerId': turn.draft.playerId.value,
                'legNumber': turn.draft.legNumber,
                'turnNumber': turn.draft.turnNumber,
                'inputMode': turn.draft.inputMode.name,
                'inputs': [
                  for (final input in turn.draft.inputs)
                    {
                      'rawValue': input.rawValue,
                      'multiplier': input.multiplier,
                    },
                ],
              },
              'resolution': {
                'isBust': turn.resolution.isBust,
                'isCheckout': turn.resolution.isCheckout,
                'nextScore': turn.resolution.nextScore,
                'reason': turn.resolution.reason,
              },
            },
        ],
      },
      createdAt: match.createdAt,
      result: match.result == null
          ? null
          : {
        'winnerPlayerId': match.result!.winnerPlayerId?.value,
        'winnerTeamId': match.result!.winnerTeamId?.value,
        'ranking': match.result!.ranking.map((e) => e.value).toList(),
        'playerStats': [
          for (final stat in match.result!.playerStats)
            {
              'playerId': stat.playerId.value,
              'average': stat.average,
              'highestCheckout': stat.highestCheckout,
              'maxTurn': stat.maxTurn,
              'inputFidelity': stat.inputFidelity.name,
            },
        ],
        'teamStats': [
          for (final stat in match.result!.teamStats)
            {
              'teamId': stat.teamId.value,
              'average': stat.average,
            },
        ],
        'mvpPlayerId': match.result!.mvpPlayerId?.value,
        'highestScore': match.result!.highestScore,
      },
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Match toDomain(MatchDto dto) {
    final configMap = dto.config;
    final rosterMap = dto.roster;
    final snapshotMap = dto.snapshot;

    final playersRaw = List<Map<String, dynamic>>.from(
      (rosterMap['players'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          const [],
    );

    final teamsRaw = List<Map<String, dynamic>>.from(
      (rosterMap['teams'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          const [],
    );

    final playerSlots = playersRaw
        .map(
          (p) => PlayerSlot(
        playerId: PlayerId((p['playerId'] ?? '') as String),
        order: (p['order'] as num?)?.toInt() ?? 0,
        teamId: p['teamId'] == null ? null : TeamId(p['teamId'] as String),
        deviceId: p['deviceId'] as String?,
      ),
    )
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final teams = teamsRaw
        .map(
          (t) => Team(
        id: TeamId((t['id'] ?? '') as String),
        name: (t['name'] ?? '') as String,
        memberIds: List<String>.from((t['memberIds'] as List?) ?? const [])
            .map((e) => PlayerId(e))
            .toList(),
        sharedScore: (t['sharedScore'] as bool?) ?? false,
      ),
    )
        .toList();

    final inputSnapshotRaw = Map<String, dynamic>.from(
      (configMap['inputSnapshot'] as Map?) ?? const {},
    );

    final inputSnapshot = <PlayerId, InputModeSnapshot>{
      for (final entry in inputSnapshotRaw.entries)
        /// Funzione: descrive in modo semplice questo blocco di logica.
        PlayerId(entry.key): InputModeSnapshot(
          mode: InputMode.values.firstWhere(
                (e) => e.name == ((entry.value as Map)['mode'] ?? InputMode.totalTurnInput.name),
            orElse: () => InputMode.totalTurnInput,
          ),
        ),
    };

    final scoreboardMap = Map<String, dynamic>.from(
      (snapshotMap['scoreboard'] as Map?) ?? const {},
    );

    final playerScoresRaw = Map<String, dynamic>.from(
      (scoreboardMap['playerScores'] as Map?) ?? const {},
    );

    final teamScoresRaw = Map<String, dynamic>.from(
      (scoreboardMap['teamScores'] as Map?) ?? const {},
    );

    final currentTurnPlayerIdValue =
        (scoreboardMap['currentTurnPlayerId'] as String?) ??
            (playerSlots.isNotEmpty ? playerSlots.first.playerId.value : '');

    final lastTurnsRaw = List<Map<String, dynamic>>.from(
      (snapshotMap['lastTurns'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          const [],
    );

    final lastTurns = lastTurnsRaw.map((turnMap) {
      final draftMap = Map<String, dynamic>.from((turnMap['draft'] as Map?) ?? const {});
      final resolutionMap =
      Map<String, dynamic>.from((turnMap['resolution'] as Map?) ?? const {});

      final inputs = List<Map<String, dynamic>>.from(
        (draftMap['inputs'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
            const [],
      )
          .map(
            (input) => DartInput(
          rawValue: (input['rawValue'] as num?)?.toInt() ?? 0,
          multiplier: (input['multiplier'] as num?)?.toInt() ?? 1,
        ),
      )
          .toList();

      /// Funzione: descrive in modo semplice questo blocco di logica.
      return TurnCommitted(
        turnId: (turnMap['turnId'] ?? '') as String,
        committedAt: DateTime.tryParse((turnMap['committedAt'] ?? '') as String) ?? DateTime.now(),
        draft: TurnDraft(
          playerId: PlayerId((draftMap['playerId'] ?? '') as String),
          legNumber: (draftMap['legNumber'] as num?)?.toInt() ?? 1,
          turnNumber: (draftMap['turnNumber'] as num?)?.toInt() ?? 1,
          inputs: inputs,
          inputMode: InputMode.values.firstWhere(
                (e) => e.name == ((draftMap['inputMode'] ?? InputMode.totalTurnInput.name) as String),
            orElse: () => InputMode.totalTurnInput,
          ),
        ),
        resolution: TurnResolution(
          isBust: (resolutionMap['isBust'] as bool?) ?? false,
          isCheckout: (resolutionMap['isCheckout'] as bool?) ?? false,
          nextScore: (resolutionMap['nextScore'] as num?)?.toInt() ?? 0,
          reason: (resolutionMap['reason'] ?? '') as String,
        ),
      );
    }).toList();

    MatchResult? result;
    final resultMap = dto.result;
    if (resultMap != null) {
      final playerStatsRaw = List<Map<String, dynamic>>.from(
        (resultMap['playerStats'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
            const [],
      );

      final teamStatsRaw = List<Map<String, dynamic>>.from(
        (resultMap['teamStats'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
            const [],
      );

      result = MatchResult(
        winnerPlayerId: resultMap['winnerPlayerId'] == null
            ? null
            : PlayerId(resultMap['winnerPlayerId'] as String),
        winnerTeamId: resultMap['winnerTeamId'] == null
            ? null
            : TeamId(resultMap['winnerTeamId'] as String),
        ranking: List<String>.from((resultMap['ranking'] as List?) ?? const [])
            .map((e) => PlayerId(e))
            .toList(),
        playerStats: playerStatsRaw
            .map(
              (s) => PlayerMatchStats(
            playerId: PlayerId((s['playerId'] ?? '') as String),
            average: (s['average'] as num?)?.toDouble() ?? 0,
            highestCheckout: (s['highestCheckout'] as num?)?.toInt() ?? 0,
            maxTurn: (s['maxTurn'] as num?)?.toInt() ?? 0,
            inputFidelity: StatsFidelity.values.firstWhere(
                  (e) => e.name == ((s['inputFidelity'] ?? StatsFidelity.limited.name) as String),
              orElse: () => StatsFidelity.limited,
            ),
          ),
        )
            .toList(),
        teamStats: teamStatsRaw
            .map(
              (s) => TeamMatchStats(
            teamId: TeamId((s['teamId'] ?? '') as String),
            average: (s['average'] as num?)?.toDouble() ?? 0,
          ),
        )
            .toList(),
        mvpPlayerId:
        resultMap['mvpPlayerId'] == null ? null : PlayerId(resultMap['mvpPlayerId'] as String),
        highestScore: (resultMap['highestScore'] as num?)?.toInt() ?? 0,
      );
    }

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return Match(
      id: MatchId(dto.matchId),
      roomId: RoomId(dto.roomId),
      config: MatchConfig(
        gameType: GameType.values.firstWhere(
              (e) => e.name == ((configMap['gameType'] ?? GameType.x01.name) as String),
          orElse: () => GameType.x01,
        ),
        variant: X01Variant.values.firstWhere(
              (e) => e.name == ((configMap['variant'] ?? X01Variant.x501.name) as String),
          orElse: () => X01Variant.x501,
        ),
        inMode: InMode.values.firstWhere(
              (e) => e.name == ((configMap['inMode'] ?? InMode.straightIn.name) as String),
          orElse: () => InMode.straightIn,
        ),
        outMode: OutMode.values.firstWhere(
              (e) => e.name == ((configMap['outMode'] ?? OutMode.doubleOut.name) as String),
          orElse: () => OutMode.doubleOut,
        ),
        matchMode: MatchMode.values.firstWhere(
              (e) => e.name == ((configMap['matchMode'] ?? MatchMode.legsOnly.name) as String),
          orElse: () => MatchMode.legsOnly,
        ),
        legsTargetType: MatchTargetType.values.firstWhere(
              (e) => e.name == ((configMap['legsTargetType'] ?? MatchTargetType.firstTo.name) as String),
          orElse: () => MatchTargetType.firstTo,
        ),
        legsTargetValue: (configMap['legsTargetValue'] as num?)?.toInt() ?? 1,
        setsTargetType: configMap['setsTargetType'] == null
            ? null
            : MatchTargetType.values.firstWhere(
              (e) => e.name == (configMap['setsTargetType'] as String),
          orElse: () => MatchTargetType.firstTo,
        ),
        setsTargetValue: (configMap['setsTargetValue'] as num?)?.toInt(),
        teamMode: TeamMode.values.firstWhere(
              (e) => e.name == ((configMap['teamMode'] ?? TeamMode.solo.name) as String),
          orElse: () => TeamMode.solo,
        ),
        teamSharedScore: (configMap['teamSharedScore'] as bool?) ?? false,
        finishConstraintEnabled: (configMap['finishConstraintEnabled'] as bool?) ?? false,
        undoRequiresHost: (configMap['undoRequiresHost'] as bool?) ?? true,
        inputSnapshot: inputSnapshot,
      ),
      roster: MatchRoster(
        players: playerSlots,
        teams: teams,
      ),
      snapshot: MatchStateSnapshot(
        matchState: MatchState.values.firstWhere(
              (e) => e.name == dto.state,
          orElse: () => MatchState.turnActive,
        ),
        status: MatchStatus.values.firstWhere(
              (e) => e.name == ((snapshotMap['status'] ?? MatchStatus.active.name) as String),
          orElse: () => MatchStatus.active,
        ),
        currentSet: (snapshotMap['currentSet'] as num?)?.toInt() ?? 1,
        currentLeg: (snapshotMap['currentLeg'] as num?)?.toInt() ?? 1,
        currentTurn: (snapshotMap['currentTurn'] as num?)?.toInt() ?? 1,
        scoreboard: Scoreboard(
          playerScores: {
            for (final entry in playerScoresRaw.entries)
              /// Funzione: descrive in modo semplice questo blocco di logica.
              PlayerId(entry.key): (entry.value as num).toInt(),
          },
          teamScores: {
            for (final entry in teamScoresRaw.entries)
              TeamId(entry.key): (entry.value as num).toInt(),
          },
          currentTurnPlayerId: PlayerId(currentTurnPlayerIdValue),
        ),
        lastTurns: lastTurns,
      ),
      legs: const [],
      sets: const [],
      result: result,
      createdAt: dto.createdAt,
    );
  }
}
