/// File: score_policy.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';

class ScorePolicy {
  const ScorePolicy();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  int nextScore({required int current, required TurnResolution resolution}) {
    if (resolution.isBust) {
      return current;
    }
    return resolution.nextScore;
  }
}
