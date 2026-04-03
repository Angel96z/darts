import 'package:darts/features/room_v2/room_data.dart';

Map<String, dynamic>? resolveActiveInputPlayer(RoomData data, String uid) {
  return data.players.firstWhere(
    (p) => p['turn'] == true && (p['ownerId'] == uid || p['id'] == uid),
    orElse: () => {},
  );
}

bool canSwitchInputMode(Map<String, dynamic> player) {
  final throws = List.from(player['throws'] ?? []);
  return throws.isEmpty;
}

bool canUndoForPlayer(RoomData data, Map<String, dynamic> player) {
  final throws = List.from(player['throws'] ?? []);
  return data.history.isNotEmpty || throws.isNotEmpty;
}

bool isTripleBullDisabled(int multiplier, int base) {
  return multiplier == 3 && base == 25;
}

bool canAppendTotalInput(String input, int n) {
  if (input.length >= 3) return false;
  final next = input + '$n';
  final parsed = int.tryParse(next);
  return parsed != null && parsed <= 180;
}

RoomData copyWithPlayerInputMode(
  RoomData data,
  dynamic playerId,
  String newMode,
) {
  final players = List<Map<String, dynamic>>.from(data.players);
  final index = players.indexWhere((p) => p['id'] == playerId);
  if (index == -1) return data;

  final updated = Map<String, dynamic>.from(players[index]);
  updated['inputMode'] = newMode;
  players[index] = updated;
  return data.copyWith(players: players);
}
