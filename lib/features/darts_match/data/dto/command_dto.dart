class CommandDto {
  const CommandDto({
    required this.commandId,
    required this.roomId,
    required this.matchId,
    required this.authorId,
    required this.type,
    required this.payload,
    required this.idempotencyKey,
    required this.status,
    required this.createdAt,
  });

  final String commandId;
  final String roomId;
  final String? matchId;
  final String authorId;
  final String type;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        'roomId': roomId,
        'matchId': matchId,
        'authorId': authorId,
        'type': type,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}
