import '../entities/match.dart';
import '../value_objects/identifiers.dart';

abstract class TeamFinishConstraint {
  const TeamFinishConstraint();

  bool allow({
    required TeamId teamId,
    required Map<TeamId, int> teamScoresAfterCheckout,
  });
}

class NoTeamFinishConstraint extends TeamFinishConstraint {
  const NoTeamFinishConstraint();

  @override
  bool allow({required TeamId teamId, required Map<TeamId, int> teamScoresAfterCheckout}) => true;
}

class LowestTeamTotalConstraint extends TeamFinishConstraint {
  const LowestTeamTotalConstraint();

  @override
  bool allow({required TeamId teamId, required Map<TeamId, int> teamScoresAfterCheckout}) {
    final myScore = teamScoresAfterCheckout[teamId];
    if (myScore == null) return false;
    final otherScores = teamScoresAfterCheckout.entries.where((e) => e.key != teamId).map((e) => e.value);
    if (otherScores.isEmpty) return true;
    final minOther = otherScores.reduce((a, b) => a < b ? a : b);
    return myScore < minOther;
  }
}
