/// File: match_command.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import 'package:equatable/equatable.dart';

import '../value_objects/identifiers.dart';

enum CommandStatus { pending, accepted, rejected }

sealed class MatchCommand extends Equatable {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  const MatchCommand({
    required this.commandId,
    required this.authorId,
    required this.createdAt,
    required this.roomId,
    required this.matchId,
    required this.payload,
    required this.idempotencyKey,
    required this.status,
  });

  final CommandId commandId;
  final PlayerId authorId;
  final DateTime createdAt;
  final RoomId roomId;
  final MatchId? matchId;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final CommandStatus status;

  @override
  List<Object?> get props => [commandId, authorId, createdAt, roomId, matchId, payload, idempotencyKey, status];
}

class JoinRoomCommand extends MatchCommand { const JoinRoomCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class AddGuestCommand extends MatchCommand { const AddGuestCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class ReorderPlayersCommand extends MatchCommand { const ReorderPlayersCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class CreateTeamsCommand extends MatchCommand { const CreateTeamsCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class UpdateMatchConfigCommand extends MatchCommand { const UpdateMatchConfigCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class StartMatchCommand extends MatchCommand { const StartMatchCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class SubmitTurnCommand extends MatchCommand { const SubmitTurnCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class UndoLastTurnRequestCommand extends MatchCommand { const UndoLastTurnRequestCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class ApproveUndoCommand extends MatchCommand { const ApproveUndoCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class DenyUndoCommand extends MatchCommand { const DenyUndoCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class PauseMatchCommand extends MatchCommand { const PauseMatchCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class ResumeMatchCommand extends MatchCommand { const ResumeMatchCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class ForfeitPlayerCommand extends MatchCommand { const ForfeitPlayerCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
class FinishMatchCommand extends MatchCommand { const FinishMatchCommand({required super.commandId, required super.authorId, required super.createdAt, required super.roomId, super.matchId, required super.payload, required super.idempotencyKey, required super.status}); }
