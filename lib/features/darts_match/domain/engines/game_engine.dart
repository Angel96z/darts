/// File: game_engine.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';

abstract class GameEngine {
  const GameEngine();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  TurnResolution resolveTurn({
    required Match match,
    required TurnDraft draft,
    required int currentPlayerScore,
    required int currentTeamScore,
    required bool inActivated,
  });
}
