import '../domain/models.dart';
import '../usecases/finish_match_usecase.dart';
import '../usecases/return_to_lobby_usecase.dart';
import '../usecases/submit_turn_usecase.dart';
import '../usecases/usecase_result.dart';

class MatchController {
  MatchController({
    required SubmitTurnUseCase submitTurn,
    required FinishMatchUseCase finishMatch,
    required ReturnToLobbyUseCase returnToLobby,
  })  : _submitTurn = submitTurn,
        _finishMatch = finishMatch,
        _returnToLobby = returnToLobby;

  final SubmitTurnUseCase _submitTurn;
  final FinishMatchUseCase _finishMatch;
  final ReturnToLobbyUseCase _returnToLobby;

  Future<UseCaseResult<MatchSnapshot>> submitTurn({
    required String roomId,
    required String matchId,
    required Session actor,
    required List<int> darts,
  }) {
    return _submitTurn.execute(
      roomId: roomId,
      matchId: matchId,
      actor: actor,
      darts: darts,
    );
  }

  Future<UseCaseResult<void>> finishMatch({
    required String roomId,
    required String matchId,
    required String winnerParticipantId,
  }) {
    return _finishMatch.execute(
      roomId: roomId,
      matchId: matchId,
      winnerParticipantId: winnerParticipantId,
    );
  }

  Future<UseCaseResult<void>> returnToLobby({required String roomId, required Session actor}) {
    return _returnToLobby.execute(roomId: roomId, actor: actor);
  }
}
