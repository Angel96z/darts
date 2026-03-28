/// File: x01_rules.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../entities/match.dart';

class InRule {
  const InRule(this.mode);
  final InMode mode;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool allowsStart(List<DartInput> inputs, bool wasActivated) {
    if (mode == InMode.straightIn || wasActivated) {
      return true;
    }
    return inputs.any((d) => d.isDouble);
  }
}

class OutRule {
  const OutRule(this.mode);
  final OutMode mode;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool isValidCheckout(DartInput lastDart) {
    return switch (mode) {
      OutMode.singleOut => true,
      OutMode.doubleOut => lastDart.isDouble,
      OutMode.masterOut => lastDart.isDouble || lastDart.isTreble,
    };
  }
}

class BustRule {
  const BustRule();

  /// Funzione: descrive in modo semplice questo blocco di logica.
  bool isBust({required int currentScore, required int turnScore, required bool validCheckout}) {
    final next = currentScore - turnScore;
    if (next < 0) {
      return true;
    }
    if (next == 0 && !validCheckout) {
      return true;
    }
    return false;
  }
}
