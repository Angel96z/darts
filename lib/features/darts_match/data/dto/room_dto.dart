class RoomDto {
  const RoomDto({
    required this.roomId,
    required this.state,
    required this.hostId,
    required this.createdAt,
    required this.currentMatchId,
    required this.members,
    required this.guests,
    required this.invite,
  });

  final String roomId;
  final String state;
  final String hostId;
  final DateTime createdAt;
  final String? currentMatchId;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> guests;
  final Map<String, dynamic> invite;

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'id': roomId,
        'state': state,
        'status': state,
        'hostId': hostId,
        'createdAt': createdAt.toIso8601String(),
        'currentMatchId': currentMatchId,
        'players': {
          for (final member in members)
            (member['playerId'] as String): {
              'name': member['displayName'],
              'isGuest': false,
              'ownerUid': member['ownerUid'],
              'lastSeen': member['lastSeen'],
            },
        },
        'guests': guests,
        'invite': invite,
      };

  factory RoomDto.fromMap(Map<String, dynamic> map) {
    final rawPlayers = Map<String, dynamic>.from((map['players'] as Map?) ?? const {});
    final members = <Map<String, dynamic>>[];

    for (final entry in rawPlayers.entries) {
      final player = Map<String, dynamic>.from((entry.value as Map?) ?? const {});
      members.add({
        'playerId': entry.key,
        'displayName': player['name'] ?? 'Player',
        'connectionState': player['connectionState'] ?? 'connected',
        'lastSeen': player['lastSeen'],
        'isHost': entry.key == (map['hostId'] as String? ?? ''),
        'ownerUid': player['ownerUid'],
      });
    }

    return RoomDto(
      roomId: (map['roomId'] ?? map['id'] ?? '') as String,
      state: (map['state'] ?? map['status'] ?? 'waiting') as String,
      hostId: (map['hostId'] ?? '') as String,
      createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
      currentMatchId: map['currentMatchId'] as String?,
      members: members,
      guests: List<Map<String, dynamic>>.from(
        (map['guests'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      ),
      invite: Map<String, dynamic>.from((map['invite'] as Map?) ?? const {}),
    );
  }
}
