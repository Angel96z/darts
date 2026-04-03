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
  final int legStarterOrder;
  final List<Map<String, dynamic>> match;

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
    this.legStarterOrder = 0,
    this.match = const [],
  });

  List<Map<String, dynamic>> _createInitialMatchTree() {
    return [
      {
        'setNumber': 1,
        'legs': [
          {
            'legNumber': 1,
            'turns': <Map<String, dynamic>>[],
          },
        ],
      },
    ];
  }

  RoomData initMatch() {
    final isX01 = game.type == GameType.x01;
    final isCricket = game.type == GameType.cricket;
    final startScore = game.startingScore ?? 501;

    final ordered = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    final updatedPlayers = <Map<String, dynamic>>[];

    for (int i = 0; i < ordered.length; i++) {
      final p = ordered[i];

      final base = <String, dynamic>{
        'id': p['id'],
        'name': p['name'],
        'ownerId': p['ownerId'],
        'isGuest': p['isGuest'],
        'order': i,
        'lastSeen': p['lastSeen'],
        'legs': 0,
        'sets': 0,
        'turn': i == 0,
        'round': 1,
        'dart': 0,
        'inputMode': 'dart',
        'opened': false,
        'throws': <Map<String, dynamic>>[],
        'throwMeta': <String>[],
        'lastThrowIntent': null,
        'lastDartMultiplier': 1,
      };

      if (isX01) {
        base['score'] = startScore;
        base['turnStartScore'] = startScore;
      } else {
        base['score'] = 0;
        base['turnStartScore'] = 0;
      }

      if (isCricket) {
        base['cricketScore'] = 0;
        base['cricket'] = {
          '20': 0,
          '19': 0,
          '18': 0,
          '17': 0,
          '16': 0,
          '15': 0,
          '25': 0,
        };
      }

      updatedPlayers.add(base);
    }

    return copyWith(
      players: updatedPlayers,
      phase: RoomPhase.match,
      history: const [],
      legStarterOrder: 0,
      match: _createInitialMatchTree(),
    );
  }

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

    return copyWith(players: List<Map<String, dynamic>>.from(players)..add(enriched));
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
    int? legStarterOrder,
    List<Map<String, dynamic>>? match,
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
      legStarterOrder: legStarterOrder ?? this.legStarterOrder,
      match: match ?? this.match,
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'createdAt': createdAt.toIso8601String(),
    'game': game.toMap(),
    'phase': phase.name,
    'creatorId': creatorId,
    'adminIds': adminIds,
    'players': players.map((p) {
      final copy = Map<String, dynamic>.from(p);

      copy['throws'] = List<Map<String, dynamic>>.from(
        (copy['throws'] ?? const []).map(
              (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      copy['throwMeta'] = List<String>.from(copy['throwMeta'] ?? const []);

      final lastThrowIntent = copy['lastThrowIntent'];
      if (lastThrowIntent is Map) {
        copy['lastThrowIntent'] = Map<String, dynamic>.from(lastThrowIntent);
      }

      return copy;
    }).toList(),
    'teamSize': teamSize,
    'matchConfig': matchConfig.toMap(),
    'history': history
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    'legStarterOrder': legStarterOrder,
    'match': match
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
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
      adminIds:
      map['adminIds'] != null ? List<String>.from(map['adminIds']) : const [],
      players: map['players'] != null
          ? List<Map<String, dynamic>>.from(map['players']).map((p) {
        final copy = Map<String, dynamic>.from(p);

        final rawThrows = List.from(copy['throws'] ?? const []);
        copy['throws'] = rawThrows.map<Map<String, dynamic>>((e) {
          if (e is Map) {
            return Map<String, dynamic>.from(e);
          }

          if (e is int) {
            return {
              'type': 'legacy',
              'value': e,
            };
          }

          return {
            'type': 'unknown',
            'value': e,
          };
        }).toList();

        copy['throwMeta'] =
        List<String>.from(copy['throwMeta'] ?? const []);

        final lastThrowIntent = copy['lastThrowIntent'];
        if (lastThrowIntent is Map) {
          copy['lastThrowIntent'] = Map<String, dynamic>.from(lastThrowIntent);
        } else {
          copy['lastThrowIntent'] = null;
        }

        return copy;
      }).toList()
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
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
          : const [],
      legStarterOrder: map['legStarterOrder'] ?? 0,
      match: map['match'] != null
          ? List<Map<String, dynamic>>.from(map['match'])
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
          : const [],
    );
  }
}