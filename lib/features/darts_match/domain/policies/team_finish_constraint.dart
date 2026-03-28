/// File: team_finish_constraint.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';
import '../value_objects/identifiers.dart';

abstract class TeamFinishConstraint {
  const TeamFinishConstraint();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool allow({
    required TeamId teamId,
    required Map<TeamId, int> teamScoresAfterCheckout,
  });
}

class NoTeamFinishConstraint extends TeamFinishConstraint {
  const NoTeamFinishConstraint();

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool allow({required TeamId teamId, required Map<TeamId, int> teamScoresAfterCheckout}) => true;
}

class LowestTeamTotalConstraint extends TeamFinishConstraint {
  const LowestTeamTotalConstraint();

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool allow({required TeamId teamId, required Map<TeamId, int> teamScoresAfterCheckout}) {
    final myScore = teamScoresAfterCheckout[teamId];
    if (myScore == null) return false;
    final otherScores = teamScoresAfterCheckout.entries.where((e) => e.key != teamId).map((e) => e.value);
    if (otherScores.isEmpty) return true;
    final minOther = otherScores.reduce((a, b) => a < b ? a : b);
    return myScore < minOther;
  }
}
