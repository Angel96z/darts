import '../entities/match.dart';

abstract class GameEngine {
  const GameEngine();

  TurnResolution resolveTurn({
    required Match match,
    required TurnDraft draft,
    required int currentPlayerScore,
    required int currentTeamScore,
    required bool inActivated,
  });
}
