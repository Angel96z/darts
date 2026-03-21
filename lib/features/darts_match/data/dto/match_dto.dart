class MatchDto {
  const MatchDto({
    required this.matchId,
    required this.roomId,
    required this.state,
    required this.config,
    required this.scoreboard,
  });

  final String matchId;
  final String roomId;
  final String state;
  final Map<String, dynamic> config;
  final Map<String, dynamic> scoreboard;

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'roomId': roomId,
        'state': state,
        'config': config,
        'scoreboard': scoreboard,
      };

  factory MatchDto.fromMap(Map<String, dynamic> map) => MatchDto(
        matchId: map['matchId'] as String,
        roomId: map['roomId'] as String,
        state: map['state'] as String,
        config: Map<String, dynamic>.from(map['config'] as Map),
        scoreboard: Map<String, dynamic>.from(map['scoreboard'] as Map),
      );
}
