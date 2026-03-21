import '../entities/match.dart';

class ScorePolicy {
  const ScorePolicy();

  int nextScore({required int current, required TurnResolution resolution}) {
    if (resolution.isBust) {
      return current;
    }
    return resolution.nextScore;
  }
}
