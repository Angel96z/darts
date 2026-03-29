import 'games_darts.dart';

enum GameMode { x01, cricket }
enum X01Variant { x101, x301, x501, x701, x1001 }
enum CricketMode { score, cutThroat }
enum RoomPhase { lobby, match, result }

class RoomData {
  final String? roomId;
  final DateTime createdAt;
  final GameConfig game;
  final RoomPhase phase;
  final String? creatorId;
  final List<String> adminIds;
  final List<Map<String, dynamic>> players;
  final int teamSize;

  const RoomData({
    required this.roomId,
    required this.createdAt,
    required this.game,
    required this.phase,
    this.creatorId,
    this.adminIds = const [],
    this.players = const [],
    this.teamSize = 0,
  });

  RoomData addPlayer(dynamic player, String ownerId) {
    final String id = player is Map ? player['id'] : player.id;
    final Map<String, dynamic> playerMap =
    player is Map ? Map<String, dynamic>.from(player) : player.toMap();

    final exists = players.any((p) => p['id'] == id);
    if (exists) return this;

    final nextOrder = players.isEmpty
        ? 0
        : players
        .map((p) => p['order'] ?? 0)
        .reduce((a, b) => a > b ? a : b) +
        1;

    final enriched = Map<String, dynamic>.from(playerMap)
      ..['ownerId'] = ownerId
      ..['lastSeen'] = DateTime.now().millisecondsSinceEpoch
      ..['order'] = nextOrder;

    return copyWith(players: List.from(players)..add(enriched));
  }

  List<List<Map<String, dynamic>>> buildTeams() {
    if (teamSize <= 1) {
      return [players];
    }

    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final teams = <List<Map<String, dynamic>>>[];

    for (int i = 0; i < sorted.length; i += teamSize) {
      if (i + teamSize <= sorted.length) {
        teams.add(sorted.sublist(i, i + teamSize));
      }
    }

    return teams;
  }

  bool isValidTeamSetup() {
    if (teamSize <= 1) return true;
    return players.length % teamSize == 0;
  }

  RoomData removePlayerAndReorder(String playerId) {
    final updated = players
        .where((p) => p['id'] != playerId)
        .map((p) => Map<String, dynamic>.from(p))
        .toList()
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    for (int i = 0; i < updated.length; i++) {
      updated[i]['order'] = i;
    }

    return copyWith(players: updated);
  }
  RoomData syncAdminsFromPlayers() {
    final updatedAdmins = <String>{...adminIds};

    for (final p in players) {
      final ownerId = p['ownerId'];
      final playerId = p['id'];
      final isGuest = p['isGuest'] == true;

      if (ownerId != null &&
          adminIds.contains(ownerId) &&
          !isGuest &&
          playerId != null &&
          playerId != creatorId) {
        if (!updatedAdmins.contains(playerId)) {
          updatedAdmins.add(playerId);
        }
      }
    }

    return copyWith(adminIds: updatedAdmins.toList());
  }

  RoomData copyWith({
    String? roomId,
    DateTime? createdAt,
    GameConfig? game,
    RoomPhase? phase,
    String? creatorId,
    List<String>? adminIds,
    List<Map<String, dynamic>>? players,
    int? teamSize,
  }) {
    return RoomData(
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      game: game ?? this.game,
      phase: phase ?? this.phase,
      creatorId: creatorId ?? this.creatorId,
      adminIds: adminIds ?? this.adminIds,
      players: players ?? this.players,
      teamSize: teamSize ?? this.teamSize,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'createdAt': createdAt.toIso8601String(),
    'game': game.toMap(),
    'phase': phase.name,
    'creatorId': creatorId,
    'adminIds': adminIds,
    'players': players,
    'teamSize': teamSize,
  };

  factory RoomData.fromMap(Map<String, dynamic> map) {
    return RoomData(
      roomId: map['roomId'],
      createdAt: DateTime.parse(map['createdAt']),
      game: map['game'] != null
          ? GameConfig.fromMap(Map<String, dynamic>.from(map['game']))
          : GameConfig.x01(),
      phase: map['phase'] != null
          ? RoomPhase.values.byName(map['phase'])
          : RoomPhase.lobby,
      creatorId: map['creatorId'],
      adminIds: map['adminIds'] != null
          ? List<String>.from(map['adminIds'])
          : const [],
      players: map['players'] != null
          ? List<Map<String, dynamic>>.from(map['players'])
          : const [],
      teamSize: map['teamSize'] ?? 0,
    );
  }
}