import 'package:equatable/equatable.dart';

import '../value_objects/identifiers.dart';

sealed class MatchEvent extends Equatable {
  const MatchEvent({
    required this.eventId,
    required this.roomId,
    required this.matchId,
    required this.createdAt,
    required this.payload,
  });

  final EventId eventId;
  final RoomId roomId;
  final MatchId matchId;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [eventId, roomId, matchId, createdAt, payload];
}

class TurnCommittedEvent extends MatchEvent { const TurnCommittedEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class TurnBustEvent extends MatchEvent { const TurnBustEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class LegWonEvent extends MatchEvent { const LegWonEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class SetWonEvent extends MatchEvent { const SetWonEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class MatchWonEvent extends MatchEvent { const MatchWonEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class UndoRequestedEvent extends MatchEvent { const UndoRequestedEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class TurnRevertedEvent extends MatchEvent { const TurnRevertedEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class PlayerDisconnectedEvent extends MatchEvent { const PlayerDisconnectedEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
class PlayerReconnectedEvent extends MatchEvent { const PlayerReconnectedEvent({required super.eventId, required super.roomId, required super.matchId, required super.createdAt, required super.payload}); }
