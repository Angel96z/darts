/// File: identity.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'package:equatable/equatable.dart';

import '../value_objects/identifiers.dart';

enum IdentityType { registered, anonymous, roomGuest }

sealed class AppIdentity extends Equatable {
  const AppIdentity({required this.id, required this.displayName, required this.type});

  final PlayerId id;
  final String displayName;
  final IdentityType type;

  @override
  List<Object?> get props => [id, displayName, type];
}

class RegisteredIdentity extends AppIdentity {
  const RegisteredIdentity({required super.id, required super.displayName, required this.uid})
      : super(type: IdentityType.registered);

  final String uid;

  @override
  List<Object?> get props => [...super.props, uid];
}

class AnonymousIdentity extends AppIdentity {
  const AnonymousIdentity({required super.id, required super.displayName, required this.firebaseUid})
      : super(type: IdentityType.anonymous);

  final String firebaseUid;

  @override
  List<Object?> get props => [...super.props, firebaseUid];
}

class RoomGuestIdentity extends AppIdentity {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const RoomGuestIdentity({
    required super.id,
    required super.displayName,
    required this.creatorPlayerId,
  }) : super(type: IdentityType.roomGuest);

  final PlayerId creatorPlayerId;

  @override
  List<Object?> get props => [...super.props, creatorPlayerId];
}

class PlayerSlot extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const PlayerSlot({
    required this.playerId,
    required this.order,
    this.teamId,
    this.deviceId,
  });

  final PlayerId playerId;
  final int order;
  final TeamId? teamId;
  final String? deviceId;

  @override
  List<Object?> get props => [playerId, order, teamId, deviceId];
}

class Team extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const Team({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.sharedScore,
  });

  final TeamId id;
  final String name;
  final List<PlayerId> memberIds;
  final bool sharedScore;

  @override
  List<Object?> get props => [id, name, memberIds, sharedScore];
}
