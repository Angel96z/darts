enum GameMode { x01, cricket }
enum X01Variant { x101, x301, x501, x701, x1001 }
enum CricketMode { score, cutThroat }
enum RoomPhase { lobby, match, result }

class RoomData {
  final String? roomId;
  final DateTime createdAt;
  final GameMode gameMode;
  final X01Variant? x01;
  final CricketMode? cricket;
  final RoomPhase phase;
  final List<String> adminIds;
  final List<Map<String, dynamic>> players;

  const RoomData({
    required this.roomId,
    required this.createdAt,
    required this.gameMode,
    this.x01,
    this.cricket,
    required this.phase,
    this.adminIds = const [],
    this.players = const [],
  });

  /// AGGIUNGE PLAYER CON OWNER
  RoomData addPlayer(dynamic player, String ownerId) {
    final String id = player is Map ? player['id'] : player.id;
    final Map<String, dynamic> playerMap =
    player is Map ? Map<String, dynamic>.from(player) : player.toMap();

    final exists = players.any((p) => p['id'] == id);
    if (exists) return this;

    final enriched = Map<String, dynamic>.from(playerMap)
      ..['ownerId'] = ownerId;

    return copyWith(players: List.from(players)..add(enriched));
  }

  /// PROMUOVE AUTOMATICAMENTE ADMIN SE OWNER È ADMIN
  RoomData syncAdminsFromPlayers() {
    final updatedAdmins = List<String>.from(adminIds);

    for (final p in players) {
      final ownerId = p['ownerId'];
      final playerId = p['id'];
      final isGuest = p['isGuest'] == true;

      if (ownerId != null &&
          adminIds.contains(ownerId) &&
          !isGuest &&
          !updatedAdmins.contains(playerId)) {
        updatedAdmins.add(playerId);
      }
    }

    return copyWith(adminIds: updatedAdmins);
  }

  RoomData copyWith({
    String? roomId,
    DateTime? createdAt,
    GameMode? gameMode,
    X01Variant? x01,
    CricketMode? cricket,
    RoomPhase? phase,
    List<String>? adminIds,
    List<Map<String, dynamic>>? players,
  }) {
    return RoomData(
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      gameMode: gameMode ?? this.gameMode,
      x01: x01 ?? this.x01,
      cricket: cricket ?? this.cricket,
      phase: phase ?? this.phase,
      adminIds: adminIds ?? this.adminIds,
      players: players ?? this.players,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'createdAt': createdAt.toIso8601String(),
    'gameMode': gameMode.name,
    'x01': x01?.name,
    'cricket': cricket?.name,
    'phase': phase.name,
    'adminIds': adminIds,
    'players': players,
  };

  factory RoomData.fromMap(Map<String, dynamic> map) {
    return RoomData(
      roomId: map['roomId'],
      createdAt: DateTime.parse(map['createdAt']),
      gameMode: GameMode.values.byName(map['gameMode']),
      x01: map['x01'] != null
          ? X01Variant.values.byName(map['x01'])
          : null,
      cricket: map['cricket'] != null
          ? CricketMode.values.byName(map['cricket'])
          : null,
      phase: map['phase'] != null
          ? RoomPhase.values.byName(map['phase'])
          : RoomPhase.lobby,
      adminIds: map['adminIds'] != null
          ? List<String>.from(map['adminIds'])
          : const [],
      players: map['players'] != null
          ? List<Map<String, dynamic>>.from(map['players'])
          : const [],
    );
  }
}