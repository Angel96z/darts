import '../../domain/entities/match.dart';

class MatchStateMachine {
  const MatchStateMachine();

  bool canTransition(MatchState from, MatchState to) {
    final map = <MatchState, Set<MatchState>>{
      MatchState.created: {MatchState.legStarting, MatchState.aborted},
      MatchState.legStarting: {MatchState.turnActive, MatchState.aborted},
      MatchState.turnActive: {MatchState.turnPendingCommit, MatchState.legFinished, MatchState.aborted},
      MatchState.turnPendingCommit: {MatchState.turnActive, MatchState.legFinished, MatchState.aborted},
      MatchState.legFinished: {MatchState.setFinished, MatchState.legStarting, MatchState.matchFinished, MatchState.aborted},
      MatchState.setFinished: {MatchState.legStarting, MatchState.matchFinished, MatchState.aborted},
      MatchState.matchFinished: {},
      MatchState.aborted: {},
    };
    return map[from]?.contains(to) ?? false;
  }
}
