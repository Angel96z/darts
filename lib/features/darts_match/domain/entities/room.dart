/// File: room.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'package:equatable/equatable.dart';

import '../value_objects/identifiers.dart';

enum RoomState { draft, waiting, ready, locked, inMatch, finished, closed }

enum ConnectionState { connected, reconnecting, disconnected, abandoned }

class InviteInfo extends Equatable {
  const InviteInfo({required this.code, required this.link, required this.expiresAt});

  final String code;
  final String link;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [code, link, expiresAt];
}

class RoomMember extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomMember({
    required this.playerId,
    required this.displayName,
    required this.connectionState,
    required this.lastSeen,
    required this.isHost,
  });

  final PlayerId playerId;
  final String displayName;
  final ConnectionState connectionState;
  final DateTime? lastSeen;
  final bool isHost;

  @override
  List<Object?> get props => [playerId, displayName, connectionState, lastSeen, isHost];
}

class RoomGuest extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomGuest({
    required this.guestId,
    required this.name,
    required this.createdBy,
  });

  final PlayerId guestId;
  final String name;
  final PlayerId createdBy;

  @override
  List<Object?> get props => [guestId, name, createdBy];
}

class RoomPresenceSummary extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomPresenceSummary({
    required this.connected,
    required this.reconnecting,
    required this.disconnected,
  });

  final int connected;
  final int reconnecting;
  final int disconnected;

  @override
  List<Object?> get props => [connected, reconnecting, disconnected];
}

class Room extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const Room({
    required this.id,
    required this.state,
    required this.hostPlayerId,
    required this.members,
    required this.guests,
    required this.invite,
    required this.currentMatchId,
    required this.createdAt,
  });

  final RoomId id;
  final RoomState state;
  final PlayerId hostPlayerId;
  final List<RoomMember> members;
  final List<RoomGuest> guests;
  final InviteInfo invite;
  final MatchId? currentMatchId;
  final DateTime createdAt;

  bool get isFull => members.length + guests.length >= 8;

  @override
  List<Object?> get props => [id, state, hostPlayerId, members, guests, invite, currentMatchId, createdAt];
}
