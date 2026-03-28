/// File: room_debug_logger.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

class RoomDebugSnapshot {
  final DateTime timestamp;
  final String? deviceId;
  final String? authUid;
  final String? authName;
  final bool isAnonymous;

  final String? roomId;
  final bool isOnlineRoom;
  final String? roomStatus;
  final String? gameType;
  final String? variant;
  final String? inMode;
  final String? outMode;
  final int? legs;
  final int? sets;

  final String? viewerRole;
  final bool isAdmin;
  final bool isPlayer;
  final bool isSpectator;
  final List<String> controlledPlayerIds;

  final List<Map<String, dynamic>> players;
  final Map<String, dynamic> matchState;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomDebugSnapshot({
    required this.timestamp,
    required this.deviceId,
    required this.authUid,
    required this.authName,
    required this.isAnonymous,
    required this.roomId,
    required this.isOnlineRoom,
    required this.roomStatus,
    required this.gameType,
    required this.variant,
    required this.inMode,
    required this.outMode,
    required this.legs,
    required this.sets,
    required this.viewerRole,
    required this.isAdmin,
    required this.isPlayer,
    required this.isSpectator,
    required this.controlledPlayerIds,
    required this.players,
    required this.matchState,
  });
}

class RoomDebugLogger {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  static void dump(RoomDebugSnapshot s, {required String reason}) {
    final buffer = StringBuffer()
      ..writeln('========== ROOM DEBUG ==========')
      ..writeln('reason: $reason')
      ..writeln('timestamp: ${s.timestamp.toIso8601String()}')
      ..writeln('--- DEVICE ---')
      ..writeln('deviceId: ${s.deviceId}')
      ..writeln('authUid: ${s.authUid}')
      ..writeln('authName: ${s.authName}')
      ..writeln('isAnonymous: ${s.isAnonymous}')
      ..writeln('--- ROOM ---')
      ..writeln('roomId: ${s.roomId}')
      ..writeln('isOnlineRoom: ${s.isOnlineRoom}')
      ..writeln('roomStatus: ${s.roomStatus}')
      ..writeln('gameType: ${s.gameType}')
      ..writeln('variant: ${s.variant}')
      ..writeln('inMode: ${s.inMode}')
      ..writeln('outMode: ${s.outMode}')
      ..writeln('legs: ${s.legs}')
      ..writeln('sets: ${s.sets}')
      ..writeln('--- VIEWER ROLE ---')
      ..writeln('viewerRole: ${s.viewerRole}')
      ..writeln('isAdmin: ${s.isAdmin}')
      ..writeln('isPlayer: ${s.isPlayer}')
      ..writeln('isSpectator: ${s.isSpectator}')
      ..writeln('controlledPlayerIds: ${s.controlledPlayerIds.join(', ')}')
      ..writeln('--- PLAYERS ---');

    for (final p in s.players) {
      buffer.writeln(
        '${p['id']} | ${p['name']} | role=${p['role']} | type=${p['type']} | '
            'authUid=${p['authUid']} | deviceId=${p['deviceId']} | '
            'connection=${p['connection']}',
      );
    }

    buffer
      ..writeln('--- MATCH ---')
      ..writeln(s.matchState.toString())
      ..writeln('===============================');

    // ignore: avoid_print
    print(buffer.toString());
  }
}
