import 'package:equatable/equatable.dart';

import 'enums.dart';

class RoomParticipant extends Equatable {
  const RoomParticipant({
    required this.participantId,
    required this.displayName,
    required this.role,
    required this.type,
    this.authUid,
    this.ownerParticipantId,
    this.joinedAtEpochMs,
  });

  final String participantId;
  final String displayName;
  final RoomRole role;
  final ParticipantType type;
  final String? authUid;
  final String? ownerParticipantId;
  final int? joinedAtEpochMs;

  bool get isGuest => type != ParticipantType.authUser;

  Map<String, dynamic> toMap() {
    return {
      'participantId': participantId,
      'displayName': displayName,
      'role': role.name,
      'type': type.name,
      'authUid': authUid,
      'ownerParticipantId': ownerParticipantId,
      'joinedAtEpochMs': joinedAtEpochMs,
    };
  }

  static RoomParticipant fromMap(Map<String, dynamic> map) {
    return RoomParticipant(
      participantId: map['participantId'] as String,
      displayName: map['displayName'] as String,
      role: RoomRole.values.byName(map['role'] as String),
      type: ParticipantType.values.byName(map['type'] as String),
      authUid: map['authUid'] as String?,
      ownerParticipantId: map['ownerParticipantId'] as String?,
      joinedAtEpochMs: map['joinedAtEpochMs'] as int?,
    );
  }

  RoomParticipant copyWith({
    String? participantId,
    String? displayName,
    RoomRole? role,
    ParticipantType? type,
    String? authUid,
    String? ownerParticipantId,
    int? joinedAtEpochMs,
  }) {
    return RoomParticipant(
      participantId: participantId ?? this.participantId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      type: type ?? this.type,
      authUid: authUid ?? this.authUid,
      ownerParticipantId: ownerParticipantId ?? this.ownerParticipantId,
      joinedAtEpochMs: joinedAtEpochMs ?? this.joinedAtEpochMs,
    );
  }

  @override
  List<Object?> get props => [
        participantId,
        displayName,
        role,
        type,
        authUid,
        ownerParticipantId,
        joinedAtEpochMs,
      ];
}

class RoomConfig extends Equatable {
  const RoomConfig({
    required this.startingScore,
    required this.maxPlayers,
    required this.allowSpectators,
    this.setsToWin = 1,
  });

  final int startingScore;
  final int maxPlayers;
  final bool allowSpectators;
  final int setsToWin;

  Map<String, dynamic> toMap() {
    return {
      'startingScore': startingScore,
      'maxPlayers': maxPlayers,
      'allowSpectators': allowSpectators,
      'setsToWin': setsToWin,
    };
  }

  static RoomConfig fromMap(Map<String, dynamic> map) {
    return RoomConfig(
      startingScore: map['startingScore'] as int,
      maxPlayers: map['maxPlayers'] as int,
      allowSpectators: map['allowSpectators'] as bool? ?? true,
      setsToWin: map['setsToWin'] as int? ?? 1,
    );
  }

  RoomConfig copyWith({
    int? startingScore,
    int? maxPlayers,
    bool? allowSpectators,
    int? setsToWin,
  }) {
    return RoomConfig(
      startingScore: startingScore ?? this.startingScore,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      setsToWin: setsToWin ?? this.setsToWin,
    );
  }

  @override
  List<Object?> get props => [startingScore, maxPlayers, allowSpectators, setsToWin];
}

class RoomSnapshot extends Equatable {
  const RoomSnapshot({
    required this.roomId,
    required this.hostUid,
    required this.status,
    required this.config,
    required this.participants,
    this.currentMatchId,
  });

  final String roomId;
  final String hostUid;
  final RoomStatus status;
  final RoomConfig config;
  final String? currentMatchId;
  final Map<String, RoomParticipant> participants;

  List<RoomParticipant> get players =>
      participants.values.where((p) => p.role == RoomRole.player || p.role == RoomRole.host).toList();

  Map<String, dynamic> toMap() {
    return {
      'hostUid': hostUid,
      'status': status.name,
      'config': config.toMap(),
      'currentMatchId': currentMatchId,
      'participants': participants.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  static RoomSnapshot fromMap(String roomId, Map<String, dynamic> map) {
    final participantsMap = (map['participants'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, RoomParticipant.fromMap(Map<String, dynamic>.from(value as Map))));

    return RoomSnapshot(
      roomId: roomId,
      hostUid: map['hostUid'] as String,
      status: RoomStatus.values.byName(map['status'] as String),
      config: RoomConfig.fromMap(Map<String, dynamic>.from(map['config'] as Map)),
      currentMatchId: map['currentMatchId'] as String?,
      participants: participantsMap,
    );
  }

  RoomSnapshot copyWith({
    String? roomId,
    String? hostUid,
    RoomStatus? status,
    RoomConfig? config,
    String? currentMatchId,
    Map<String, RoomParticipant>? participants,
  }) {
    return RoomSnapshot(
      roomId: roomId ?? this.roomId,
      hostUid: hostUid ?? this.hostUid,
      status: status ?? this.status,
      config: config ?? this.config,
      currentMatchId: currentMatchId ?? this.currentMatchId,
      participants: participants ?? this.participants,
    );
  }

  @override
  List<Object?> get props => [roomId, hostUid, status, config, currentMatchId, participants];
}

class MatchSnapshot extends Equatable {
  const MatchSnapshot({
    required this.matchId,
    required this.roomId,
    required this.status,
    required this.turnParticipantId,
    required this.scores,
    required this.throwsByParticipant,
    this.winnerParticipantId,
  });

  final String matchId;
  final String roomId;
  final MatchStatus status;
  final String turnParticipantId;
  final Map<String, int> scores;
  final Map<String, List<int>> throwsByParticipant;
  final String? winnerParticipantId;

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'turn': turnParticipantId,
      'scores': scores,
      'throws': throwsByParticipant,
      'result': {'winnerParticipantId': winnerParticipantId},
    };
  }

  static MatchSnapshot fromMap({
    required String roomId,
    required String matchId,
    required Map<String, dynamic> map,
  }) {
    final rawThrows = Map<String, dynamic>.from(map['throws'] as Map? ?? {});
    return MatchSnapshot(
      matchId: matchId,
      roomId: roomId,
      status: MatchStatus.values.byName(map['status'] as String),
      turnParticipantId: map['turn'] as String,
      scores: Map<String, int>.from(map['scores'] as Map? ?? {}),
      throwsByParticipant: rawThrows.map(
        (key, value) => MapEntry(key, List<int>.from(value as List<dynamic>)),
      ),
      winnerParticipantId: (map['result'] as Map<String, dynamic>? ?? {})['winnerParticipantId'] as String?,
    );
  }

  MatchSnapshot copyWith({
    MatchStatus? status,
    String? turnParticipantId,
    Map<String, int>? scores,
    Map<String, List<int>>? throwsByParticipant,
    String? winnerParticipantId,
  }) {
    return MatchSnapshot(
      matchId: matchId,
      roomId: roomId,
      status: status ?? this.status,
      turnParticipantId: turnParticipantId ?? this.turnParticipantId,
      scores: scores ?? this.scores,
      throwsByParticipant: throwsByParticipant ?? this.throwsByParticipant,
      winnerParticipantId: winnerParticipantId ?? this.winnerParticipantId,
    );
  }

  @override
  List<Object?> get props => [
        matchId,
        roomId,
        status,
        turnParticipantId,
        scores,
        throwsByParticipant,
        winnerParticipantId,
      ];
}

class Session extends Equatable {
  const Session({
    required this.authUid,
    required this.participantId,
    required this.role,
  });

  final String authUid;
  final String participantId;
  final RoomRole role;

  @override
  List<Object?> get props => [authUid, participantId, role];
}
