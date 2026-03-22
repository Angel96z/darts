import '../data/repositories/match_repository.dart';
import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/permission_policy.dart';
import 'usecase_result.dart';

class SubmitTurnUseCase {
  SubmitTurnUseCase(this._roomRepository, this._matchRepository);

  final RoomRepository _roomRepository;
  final MatchRepository _matchRepository;

  Future<UseCaseResult<MatchSnapshot>> execute({
    required String roomId,
    required String matchId,
    required Session actor,
    required List<int> darts,
  }) async {
    try {
      final updated = await _matchRepository.runTransaction((tx) async {
        final roomRef = _roomRepository.roomRef(roomId);
        final matchRef = _matchRepository.matchRef(roomId, matchId);

        final roomDoc = await tx.get(roomRef);
        final matchDoc = await tx.get(matchRef);
        if (!roomDoc.exists || roomDoc.data() == null || !matchDoc.exists || matchDoc.data() == null) {
          throw UseCaseException('Room or match not found');
        }

        final room = RoomSnapshot.fromMap(roomId, roomDoc.data()!);
        final match = MatchSnapshot.fromMap(roomId: roomId, matchId: matchId, map: matchDoc.data()!);

        if (!PermissionPolicy.canSubmitTurn(room: room, match: match, actor: actor)) {
          throw UseCaseException('Not your turn');
        }

        final turnScore = darts.fold<int>(0, (sum, value) => sum + value);
        final currentScore = match.scores[actor.participantId] ?? 0;
        final remaining = currentScore - turnScore;
        final validRemaining = remaining >= 0 ? remaining : currentScore;

        final scores = Map<String, int>.from(match.scores);
        scores[actor.participantId] = validRemaining;

        final throwHistory = Map<String, List<int>>.from(match.throwsByParticipant);
        throwHistory[actor.participantId] = [...(throwHistory[actor.participantId] ?? const []), ...darts];

        final order = room.players.map((p) => p.participantId).toList();
        final currentIndex = order.indexOf(actor.participantId);
        final nextTurn = order[(currentIndex + 1) % order.length];

        final finished = validRemaining == 0;
        final nextMatch = match.copyWith(
          status: finished ? MatchStatus.finished : MatchStatus.active,
          turnParticipantId: finished ? actor.participantId : nextTurn,
          scores: scores,
          throwsByParticipant: throwHistory,
          winnerParticipantId: finished ? actor.participantId : null,
        );

        tx.update(matchRef, nextMatch.toMap());
        if (finished) {
          tx.update(roomRef, {'status': RoomStatus.terminated.name});
        }

        return nextMatch;
      });

      return UseCaseResult.success(updated);
    } on UseCaseException catch (e) {
      return UseCaseResult.failure(e.message);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
