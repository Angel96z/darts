/// File: match_format_policy.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';

class MatchFormatPolicy {
  const MatchFormatPolicy();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool isLegsTargetReached({required MatchConfig config, required int wonLegs}) {
    if (config.legsTargetType == MatchTargetType.firstTo) {
      return wonLegs >= config.legsTargetValue;
    }
    return wonLegs > (config.legsTargetValue ~/ 2);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool isSetsTargetReached({required MatchConfig config, required int wonSets}) {
    final target = config.setsTargetValue;
    if (target == null) return false;
    if (config.setsTargetType == MatchTargetType.firstTo) {
      return wonSets >= target;
    }
    return wonSets > (target ~/ 2);
  }
}
