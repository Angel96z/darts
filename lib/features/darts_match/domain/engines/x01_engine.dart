/// File: x01_engine.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';
import '../policies/team_finish_constraint.dart';
import '../rules/x01_rules.dart';
import '../value_objects/identifiers.dart';
import 'game_engine.dart';

class X01Engine extends GameEngine {
  /// Funzione: descrive in modo semplice questo blocco di logica.
  X01Engine({
    required InRule inRule,
    required OutRule outRule,
    required BustRule bustRule,
    required TeamFinishConstraint finishConstraint,
  })  : _inRule = inRule,
        _outRule = outRule,
        _bustRule = bustRule,
        _finishConstraint = finishConstraint;

  final InRule _inRule;
  final OutRule _outRule;
  final BustRule _bustRule;
  final TeamFinishConstraint _finishConstraint;

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  TurnResolution resolveTurn({
    required Match match,
    required TurnDraft draft,
    required int currentPlayerScore,
    required int currentTeamScore,
    required bool inActivated,
  }) {
    final started = _inRule.allowsStart(draft.inputs, inActivated);
    if (!started) {
      return TurnResolution(
        isBust: false,
        isCheckout: false,
        nextScore: currentPlayerScore,
        reason: 'in_not_activated',
      );
    }

    final total = draft.total;
    final projected = currentPlayerScore - total;
    final lastDart = draft.inputs.isNotEmpty
        ? draft.inputs.last
        : const DartInput(rawValue: 0, multiplier: 1);

    if (projected < 0) {
      return TurnResolution(
        isBust: true,
        isCheckout: false,
        nextScore: currentPlayerScore,
        reason: 'bust_over_score',
      );
    }

    if (match.config.outMode == OutMode.doubleOut && projected == 1) {
      return TurnResolution(
        isBust: true,
        isCheckout: false,
        nextScore: currentPlayerScore,
        reason: 'bust_on_one',
      );
    }

// 🔥 DIFFERENZA CHIAVE: separiamo PER DART vs PER TURN

    final isPerTurn = draft.inputMode == InputMode.totalTurnInput;

// checkout attempt
    final checkoutAttempt = projected == 0;

// validazione checkout
    final validCheckout = isPerTurn
    // 👉 PER TURN: NON usare lastDart (non è affidabile)
        ? checkoutAttempt
    // 👉 PER DART: validazione reale
        : (!checkoutAttempt || _outRule.isValidCheckout(lastDart));

    final bust = isPerTurn
    // 👉 PER TURN: bust solo se score sotto 0 o regole base
        ? (projected < 0 ||
        (match.config.outMode == OutMode.doubleOut && projected == 1))
    // 👉 PER DART: logica completa
        : _bustRule.isBust(
      currentScore: currentPlayerScore,
      turnScore: total,
      validCheckout: validCheckout,
    );

    if (bust) {
      return TurnResolution(
        isBust: true,
        isCheckout: false,
        nextScore: currentPlayerScore,
        reason: validCheckout ? 'bust' : 'invalid_checkout',
      );
    }

    if (checkoutAttempt &&
        match.config.teamMode == TeamMode.teams &&
        draft.playerId != match.snapshot.scoreboard.currentTurnPlayerId) {
      return TurnResolution(
        isBust: true,
        isCheckout: false,
        nextScore: currentPlayerScore,
        reason: 'invalid_turn_owner',
      );
    }

    return TurnResolution(
      isBust: false,
      isCheckout: checkoutAttempt,
      nextScore: projected,
      reason: checkoutAttempt ? 'checkout' : 'ok',
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool validateTeamCheckout({required Match match, required TeamId teamId, required Map<TeamId, int> projectedScores}) {
    return _finishConstraint.allow(teamId: teamId, teamScoresAfterCheckout: projectedScores);
  }
}
