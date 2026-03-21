import '../entities/match.dart';

enum StatsFidelity { full, limited }

class InputModeSnapshot {
  const InputModeSnapshot({required this.mode});

  final InputMode mode;

  StatsFidelity get fidelity => mode == InputMode.perDartPad ? StatsFidelity.full : StatsFidelity.limited;
}

class StatsFidelityPolicy {
  const StatsFidelityPolicy();

  StatsFidelity resolve(InputModeSnapshot snapshot) => snapshot.fidelity;
}
