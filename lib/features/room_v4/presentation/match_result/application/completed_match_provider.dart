import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/player_info.dart';
import '../../../domain/models/set.dart';

final completedMatchDataProvider = StateProvider<(
String matchId,
String? winnerId,
List<PlayerInfo> players,
int teamSize,
Map<String, String> playerToTeam,
List<Set> sets,
DateTime startTime,
DateTime? endTime,
)>((ref) => ('', null, [], 0, {}, [], DateTime.now(), null));