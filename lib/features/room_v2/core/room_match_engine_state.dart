import 'package:darts/features/room_v2/room_data.dart';

Map<String, dynamic>? buildWinnerOverlayData(RoomData data, String uid) {
  final isTeam = data.teamSize > 1;
  bool hasWinner = false;
  bool isLocalWinner = false;

  if (isTeam) {
    final teams = data.buildTeams();
    List<Map<String, dynamic>>? winningTeam;

    for (final team in teams) {
      final sets = (team.first['sets'] ?? 0) as int;
      if (sets >= data.matchConfig.setsToWin) {
        winningTeam = team;
        hasWinner = true;
        break;
      }
    }

    if (!hasWinner || winningTeam == null) return null;

    isLocalWinner = winningTeam.any((p) {
      return p['id'] == uid || p['ownerId'] == uid;
    });

    if (!isLocalWinner) return null;

    return {
      'title': 'TEAM VINCENTE',
      'name': winningTeam.map((p) => p['name']).join(', '),
    };
  }

  Map<String, dynamic>? winner;
  for (final p in data.players) {
    final sets = (p['sets'] ?? 0) as int;
    if (sets >= data.matchConfig.setsToWin) {
      winner = p;
      hasWinner = true;
      break;
    }
  }

  if (!hasWinner || winner == null) return null;

  isLocalWinner = winner['id'] == uid || winner['ownerId'] == uid;
  if (!isLocalWinner) return null;

  return {
    'title': 'VINCITORE',
    'name': winner['name'] ?? '-',
  };
}

List<Map<String, dynamic>> buildTeamScoreRows(RoomData data) {
  if (data.teamSize <= 1) return [];

  return data.buildTeams().asMap().entries.map((entry) {
    final index = entry.key;
    final teamPlayers = entry.value;

    final teamScore = teamPlayers.fold<int>(
      0,
      (sum, p) => sum + ((p['score'] ?? 0) as int),
    );

    return {
      'index': index,
      'players': teamPlayers,
      'score': teamScore,
    };
  }).toList();
}
