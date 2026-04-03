import 'package:darts/features/room_v2/room_data.dart';
import 'package:darts/features/room_v2/utils/throw_parser.dart';

List<Map<String, dynamic>> buildPlayerHistoryTurns(
  RoomData data,
  dynamic playerId,
) {
  if (data.history is! List) return [];
  return data.history.where((h) => h['playerId'] == playerId).toList();
}

List<String> buildPlayerHistoryDartLabels(
  RoomData data,
  dynamic playerId,
) {
  final historyTurns = buildPlayerHistoryTurns(data, playerId);
  return historyTurns.expand((t) {
    final values = List.from(t['throws'] ?? const []);
    return values.map(formatThrowLabel);
  }).toList();
}

List<String> buildCurrentThrowLabels(Map<String, dynamic> player) {
  final throws = player['throws'] is List
      ? List<Map<String, dynamic>>.from(player['throws'])
      : <Map<String, dynamic>>[];
  return throws.map(formatThrowLabel).toList();
}

List<String> buildTurnHistoryLabels(
  RoomData data,
  dynamic playerId,
) {
  final historyTurns = buildPlayerHistoryTurns(data, playerId);
  return historyTurns.map((t) {
    final total = t['total'];
    final kind = t['endKind'];
    final mode = t['inputMode'];
    return '$total ($mode/$kind)';
  }).toList();
}
