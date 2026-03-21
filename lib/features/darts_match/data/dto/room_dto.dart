class RoomDto {
  const RoomDto({
    required this.roomId,
    required this.state,
    required this.hostId,
    required this.createdAt,
  });

  final String roomId;
  final String state;
  final String hostId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'state': state,
        'hostId': hostId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RoomDto.fromMap(Map<String, dynamic> map) => RoomDto(
        roomId: map['roomId'] as String,
        state: map['state'] as String,
        hostId: map['hostId'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
