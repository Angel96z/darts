import '../entities/match.dart';

class MatchFormatPolicy {
  const MatchFormatPolicy();

  bool isLegsTargetReached({required MatchConfig config, required int wonLegs}) {
    if (config.legsTargetType == MatchTargetType.firstTo) {
      return wonLegs >= config.legsTargetValue;
    }
    return wonLegs > (config.legsTargetValue ~/ 2);
  }

  bool isSetsTargetReached({required MatchConfig config, required int wonSets}) {
    final target = config.setsTargetValue;
    if (target == null) return false;
    if (config.setsTargetType == MatchTargetType.firstTo) {
      return wonSets >= target;
    }
    return wonSets > (target ~/ 2);
  }
}
