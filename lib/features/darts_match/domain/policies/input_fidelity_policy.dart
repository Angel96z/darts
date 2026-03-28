/// File: input_fidelity_policy.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';

enum StatsFidelity { full, limited }

class InputModeSnapshot {
  const InputModeSnapshot({required this.mode});

  final InputMode mode;

  StatsFidelity get fidelity => mode == InputMode.perDartPad ? StatsFidelity.full : StatsFidelity.limited;
}

class StatsFidelityPolicy {
  const StatsFidelityPolicy();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  StatsFidelity resolve(InputModeSnapshot snapshot) => snapshot.fidelity;
}
