/// File: training_save_logic.dart. Contiene regole di dominio, entità o casi d'uso per questa funzionalità.

import '../../../game/domain/entities/dart_models.dart';

class TrainingSaveResult {
  final bool canSave;
  final String message;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingSaveResult({
    required this.canSave,
    required this.message,
  });
}

class TrainingSaveLogic {

  /// Funzione: descrive in modo semplice questo blocco di logica.
  static TrainingSaveResult validateSave(
      DartThrowManagerController controller,
      ) {

    final throws = controller.throws;

    if (throws.isEmpty) {
      return const TrainingSaveResult(
        canSave: false,
        message: "Nessun tiro registrato",
      );
    }

    final last = throws.last;

    final sameTurnThrows = throws.where(
          (t) =>
      t.roundNumber == last.roundNumber &&
          t.turnNumber == last.turnNumber &&
          t.playerId == last.playerId,
    ).length;

    if (sameTurnThrows == 1 || sameTurnThrows == 2) {
      return const TrainingSaveResult(
        canSave: false,
        message:
        "Turno incompleto. Lancia tutte le freccette o annulla le ultime.",
      );
    }

    return const TrainingSaveResult(
      canSave: true,
      message: "Allenamento salvabile",
    );
  }

}
