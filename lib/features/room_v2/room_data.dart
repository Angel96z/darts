import 'games_darts.dart';

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
  final MatchConfig matchConfig;
  final List<Map<String, dynamic>> history;

  const RoomData({
    required this.roomId,
    required this.createdAt,
    required this.game,
    required this.phase,
    this.creatorId,
    this.adminIds = const [],
    this.players = const [],
    this.teamSize = 0,
    this.matchConfig = const MatchConfig(
      mode: MatchMode.firstTo,
      setCount: 1,
      legCount: 2,
    ),
    this.history = const [],
  });

  // =========================
  // INIT MATCH
  // =========================
  RoomData initMatch() {
    final isX01 = game.type == GameType.x01;
    final isCricket = game.type == GameType.cricket;

    final startScore = game.startingScore ?? 501;

    final ordered = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final updatedPlayers = <Map<String, dynamic>>[];

    for (int i = 0; i < ordered.length; i++) {
      final p = ordered[i];
      final copy = Map<String, dynamic>.from(p);

      // GAME INIT
      if (isX01) {
        copy['score'] = startScore;
      }

      if (isCricket) {
        copy['score'] = 0;
        copy['cricket'] = {
          '20': 0,
          '19': 0,
          '18': 0,
          '17': 0,
          '16': 0,
          '15': 0,
          '25': 0,
        };
      }

      // MATCH STATE
      copy['legs'] = 0;
      copy['sets'] = 0;
      copy['turn'] = i == 0;

      copy['throws'] = [];
      copy['round'] = 1;
      copy['dart'] = 0;

      copy['inputMode'] = p['inputMode'] ?? 'dart';

      updatedPlayers.add(copy);
    }

    return copyWith(
      players: updatedPlayers,
      phase: RoomPhase.match,
    );
  }

  // =========================
  // PLAYERS
  // =========================
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
    if (teamSize <= 1) return [players];

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
        updatedAdmins.add(playerId);
      }
    }

    return copyWith(adminIds: updatedAdmins.toList());
  }

  // =========================
  // COPY
  // =========================
  RoomData copyWith({
    String? roomId,
    DateTime? createdAt,
    GameConfig? game,
    RoomPhase? phase,
    String? creatorId,
    List<String>? adminIds,
    List<Map<String, dynamic>>? players,
    int? teamSize,
    MatchConfig? matchConfig,
    List<Map<String, dynamic>>? history,
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
      matchConfig: matchConfig ?? this.matchConfig,
      history: history ?? this.history,
    );
  }

  // =========================
  // DB
  // =========================
  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'createdAt': createdAt.toIso8601String(),
    'game': game.toMap(),
    'phase': phase.name,
    'creatorId': creatorId,
    'adminIds': adminIds,
    'players': players,
    'teamSize': teamSize,
    'matchConfig': matchConfig.toMap(),
    'history': history,
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
      matchConfig: map['matchConfig'] != null
          ? MatchConfig.fromMap(
        Map<String, dynamic>.from(map['matchConfig']),
      )
          : const MatchConfig(
        mode: MatchMode.firstTo,
        setCount: 1,
        legCount: 2,
      ),
      history: map['history'] != null
          ? List<Map<String, dynamic>>.from(map['history'])
          : const [],
    );
  }
}