import '../data/repositories/match_repository.dart';
import '../data/repositories/room_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'usecase_result.dart';

class FinishMatchUseCase {
  FinishMatchUseCase(this._roomRepository, this._matchRepository);

  final RoomRepository _roomRepository;
  final MatchRepository _matchRepository;

  Future<UseCaseResult<void>> execute({
    required String roomId,
    required String matchId,
    required String winnerParticipantId,
  }) async {
    try {
      await _matchRepository.runTransaction((tx) async {
        tx.update(_matchRepository.matchRef(roomId, matchId), {
          'status': MatchStatus.finished.name,
          'result': {'winnerParticipantId': winnerParticipantId},
        });
        tx.update(_roomRepository.roomRef(roomId), {'status': RoomStatus.terminated.name});
      });
      return const UseCaseResult.success(null);
    } catch (e) {
      return UseCaseResult.failure(e.toString());
    }
  }
}
