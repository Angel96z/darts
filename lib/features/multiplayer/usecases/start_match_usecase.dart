import 'package:uuid/uuid.dart';

import '../data/repositories/match_repository.dart';
import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class StartMatchUseCase {
  StartMatchUseCase(this._roomRepository, this._matchRepository, this._uuid);

  final RoomRepository _roomRepository;
  final MatchRepository _matchRepository;
  final Uuid _uuid;

  Future<UseCaseResult<MatchSnapshot>> execute({
    required String roomId,
    required Session actor,
  }) async {
    try {
      final match = await _matchRepository.runTransaction((tx) async {
        final roomRef = _roomRepository.roomRef(roomId);
        final roomDoc = await tx.get(roomRef);
        if (!roomDoc.exists || roomDoc.data() == null) {
          throw UseCaseException('Room not found');
        }
        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        if (!PermissionPolicy.canStartMatch(room: room, actor: actor)) {
          throw UseCaseException('Not allowed');
        }

        final activePlayers = room.players;
        if (activePlayers.length < 2) {
          throw UseCaseException('At least 2 players required');
        }

        final matchId = _uuid.v4();
        final initialScores = {
          for (final p in activePlayers) p.participantId: room.config.startingScore,
        };
        final snapshot = MatchSnapshot(
          matchId: matchId,
          roomId: roomId,
          status: MatchStatus.active,
          turnParticipantId: activePlayers.first.participantId,
          scores: initialScores,
          throwsByParticipant: const {},
          winnerParticipantId: null,
        );

        tx.set(_matchRepository.matchRef(roomId, matchId), snapshot.toMap());
        tx.update(roomRef, {
          'status': RoomStatus.inGame.name,
          'currentMatchId': matchId,
        });

        return snapshot;
      });

      return UseCaseResult.success(match);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
