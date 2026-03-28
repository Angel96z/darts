/// File: match_dto.dart. Contiene accesso e trasformazione dati (datasource, dto, repository o mapper).

class MatchDto {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MatchDto({
    required this.matchId,
    required this.roomId,
    required this.state,
    required this.config,
    required this.roster,
    required this.snapshot,
    required this.createdAt,
    this.result,
  });

  final String matchId;
  final String roomId;
  final String state;
  final Map<String, dynamic> config;
  final Map<String, dynamic> roster;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final Map<String, dynamic>? result;

  Map<String, dynamic> toMap() => {
    'matchId': matchId,
    'roomId': roomId,
    'state': state,
    'config': config,
    'roster': roster,
    'snapshot': snapshot,
    'createdAt': createdAt.toIso8601String(),
    'result': result,
  };

  factory MatchDto.fromMap(Map<String, dynamic> map) => MatchDto(
    matchId: map['matchId'] as String,
    roomId: map['roomId'] as String,
    state: map['state'] as String,
    config: Map<String, dynamic>.from((map['config'] as Map?) ?? const {}),
    roster: Map<String, dynamic>.from((map['roster'] as Map?) ?? const {}),
    snapshot: Map<String, dynamic>.from((map['snapshot'] as Map?) ?? const {}),
    createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
    result: map['result'] == null
        ? null
        : Map<String, dynamic>.from(map['result'] as Map),
  );
}
