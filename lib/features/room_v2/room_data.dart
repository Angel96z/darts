enum GameMode { x01, cricket }
enum X01Variant { x101, x301, x501, x701, x1001 }
enum CricketMode { score, cutThroat }

class RoomData {
  final String? roomId;
  final DateTime createdAt;

  final GameMode gameMode;
  final X01Variant? x01;
  final CricketMode? cricket;

  final bool matchStarted;
  final bool matchFinished;

  const RoomData({
    required this.roomId,
    required this.createdAt,
    required this.gameMode,
    this.x01,
    this.cricket,
    required this.matchStarted,
    required this.matchFinished,
  });

  RoomData copyWith({
    String? roomId,
    DateTime? createdAt,
    GameMode? gameMode,
    X01Variant? x01,
    CricketMode? cricket,
    bool? matchStarted,
    bool? matchFinished,
  }) {
    return RoomData(
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      gameMode: gameMode ?? this.gameMode,
      x01: x01 ?? this.x01,
      cricket: cricket ?? this.cricket,
      matchStarted: matchStarted ?? this.matchStarted,
      matchFinished: matchFinished ?? this.matchFinished,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'createdAt': createdAt.toIso8601String(),
    'gameMode': gameMode.name,
    'x01': x01?.name,
    'cricket': cricket?.name,
    'matchStarted': matchStarted,
    'matchFinished': matchFinished,
  };

  factory RoomData.fromMap(Map<String, dynamic> map) {
    return RoomData(
      roomId: map['roomId'],
      createdAt: DateTime.parse(map['createdAt']),
      gameMode: GameMode.values.byName(map['gameMode']),
      x01: map['x01'] != null ? X01Variant.values.byName(map['x01']) : null,
      cricket: map['cricket'] != null ? CricketMode.values.byName(map['cricket']) : null,
      matchStarted: map['matchStarted'] ?? false,
      matchFinished: map['matchFinished'] ?? false,
    );
  }
}