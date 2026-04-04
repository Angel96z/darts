import 'package:darts/features/room_v2/room_data.dart';

class MatchLegRebuilder {
  static Map<String, dynamic> buildPerPlayer(RoomData data) {
    final result = <String, dynamic>{};

    final match = data.match;

    for (final rawSet in match) {
      final set = Map<String, dynamic>.from(rawSet);
      final setNumber = (set['setNumber'] as int?) ?? 1;
      final legs = List<Map<String, dynamic>>.from(set['legs'] ?? const []);

      for (final rawLeg in legs) {
        final leg = Map<String, dynamic>.from(rawLeg);
        final legNumber = (leg['legNumber'] as int?) ?? 1;
        final turns = List<Map<String, dynamic>>.from(leg['turns'] ?? const []);

        for (int i = 0; i < turns.length; i++) {
          final turn = Map<String, dynamic>.from(turns[i]);
          final playerId = turn['playerId']?.toString();
          if (playerId == null || playerId.isEmpty) continue;

          result.putIfAbsent(playerId, () {
            return {
              'playerId': playerId,
              'sets': <Map<String, dynamic>>[],
            };
          });

          final playerData = Map<String, dynamic>.from(result[playerId]);
          final sets = List<Map<String, dynamic>>.from(playerData['sets'] ?? const []);

          Map<String, dynamic>? currentSet;
          for (final s in sets) {
            if ((s['setNumber'] as int?) == setNumber) {
              currentSet = s;
              break;
            }
          }

          if (currentSet == null) {
            currentSet = {
              'setNumber': setNumber,
              'legs': <Map<String, dynamic>>[],
            };
            sets.add(currentSet);
          }

          final setLegs = List<Map<String, dynamic>>.from(currentSet['legs'] ?? const []);

          Map<String, dynamic>? currentLeg;
          for (final l in setLegs) {
            if ((l['legNumber'] as int?) == legNumber) {
              currentLeg = l;
              break;
            }
          }

          if (currentLeg == null) {
            currentLeg = {
              'legNumber': legNumber,
              'turns': <Map<String, dynamic>>[],
            };
            setLegs.add(currentLeg);
          }

          final legTurns = List<Map<String, dynamic>>.from(currentLeg['turns'] ?? const []);
          legTurns.add(_mapTurn(turn, i + 1));

          currentLeg['turns'] = legTurns;
          currentSet['legs'] = setLegs;
          playerData['sets'] = sets;
          result[playerId] = playerData;
        }
      }
    }

    return result;
  }

  static Map<String, dynamic> _mapTurn(
      Map<String, dynamic> turn,
      int turnNumber,
      ) {
    final rawThrows = List<Map<String, dynamic>>.from(turn['throws'] ?? const []);
    final darts = rawThrows.map<String?>((t) => _label(t)).toList();

    while (darts.length < 3) {
      darts.add(null);
    }

    if (darts.length > 3) {
      darts.removeRange(3, darts.length);
    }

    return {
      'turnNumber': turnNumber,
      'startScore': (turn['startScore'] as int?) ?? 0,
      'darts': darts,
      'total': (turn['total'] as int?) ?? 0,
      'endKind': (turn['endKind'] as String?) ?? 'normal',
      'inputMode': (turn['inputMode'] as String?) ?? 'dart',
    };
  }

  static String? _label(Map<String, dynamic> throwData) {
    if (throwData['isMiss'] == true) return 'MISS';

    final label = throwData['label'];
    if (label is String && label.isNotEmpty) {
      return label;
    }

    final value = throwData['value'];
    if (value is int) {
      return value.toString();
    }

    return null;
  }
}