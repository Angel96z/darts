import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/room_repository.dart';
import '../data/repositories/user_room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'usecase_result.dart';

class JoinRoomUseCase {
  JoinRoomUseCase(this._roomRepository, this._userRoomRepository, this._uuid);

  final RoomRepository _roomRepository;
  final UserRoomRepository _userRoomRepository;
  final Uuid _uuid;

  Future<UseCaseResult<RoomParticipant>> execute({
    required String roomId,
    required String authUid,
    required String displayName,
  }) async {
    try {
      final participant = await _roomRepository.runRoomTransaction(roomId, (tx, roomRef) async {
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }

        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (room.status == RoomStatus.closed) {
          throw UseCaseException('Room closed');
        }

        final existing = room.participants.values.where((p) => p.authUid == authUid).toList();
        if (existing.isNotEmpty) {
          return existing.first;
        }

        final players = room.players;
        if (players.length >= room.config.maxPlayers || room.status != RoomStatus.waiting) {
          throw UseCaseException('Cannot join as player');
        }

        final newParticipant = RoomParticipant(
          participantId: _uuid.v4(),
          displayName: displayName,
          role: RoomRole.player,
          type: ParticipantType.authUser,
          authUid: authUid,
          joinedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        );

        tx.update(roomRef, {'participants.${newParticipant.participantId}': newParticipant.toMap()});
        return newParticipant;
      });

      await _userRoomRepository.upsert(
        UserRoomRecord(
          uid: authUid,
          roomId: roomId,
          role: participant.role,
          participantIds: [participant.participantId],
        ),
      );

      return UseCaseResult.success(participant);
    } on FirebaseException catch (e) {
      return UseCaseResult.failure(e.message ?? e.code);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
