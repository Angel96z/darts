import 'dart:async';

import '../data/repositories/match_repository.dart';
import '../domain/models.dart';

class MatchViewModel {
  const MatchViewModel({
    required this.matchId,
    required this.currentTurnParticipantId,
    required this.scores,
    required this.winnerParticipantId,
    required this.status,
  });

  final String matchId;
  final String currentTurnParticipantId;
  final Map<String, int> scores;
  final String? winnerParticipantId;
  final String status;

  static MatchViewModel fromMatch(MatchSnapshot match) {
    return MatchViewModel(
      matchId: match.matchId,
      currentTurnParticipantId: match.turnParticipantId,
      scores: match.scores,
      winnerParticipantId: match.winnerParticipantId,
      status: match.status.name,
    );
  }
}

class MatchLiveCoordinator {
  MatchLiveCoordinator(this._matchRepository);

  final MatchRepository _matchRepository;
  StreamSubscription<MatchSnapshot?>? _subscription;

  void bind({
    required String roomId,
    required String matchId,
    required void Function(MatchViewModel viewModel) onChanged,
    required void Function(Object error) onError,
  }) {
    _subscription?.cancel();
    _subscription = _matchRepository.watchMatch(roomId, matchId).listen((match) {
      if (match == null) {
        onError(StateError('Match not found'));
        return;
      }
      onChanged(MatchViewModel.fromMatch(match));
    }, onError: onError);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
