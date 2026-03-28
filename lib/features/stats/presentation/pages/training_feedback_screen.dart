/// File: training_feedback_screen.dart. Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:flutter/material.dart' hide OverlayState;

import '../../../../core/widgets/blocking_overlay.dart';
import '../../data/datasources/local_training_sync_service.dart';

class TrainingFeedbackData {
  final int? focus;
  final int? stress;
  final int? energia;
  final int? fiducia;
  final int? distrazioni;
  final String? commento;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingFeedbackData({
    this.focus,
    this.stress,
    this.energia,
    this.fiducia,
    this.distrazioni,
    this.commento,
  });
}

enum TrainingFeedbackAction { goToStats, goHome }

class TrainingFeedbackResult {
  final TrainingFeedbackAction action;
  final String? savedSessionId;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingFeedbackResult({
    required this.action,
    required this.savedSessionId,
  });
}

class TrainingFeedbackScreen extends StatefulWidget {
  final Future<LocalTrainingSaveResult> Function(TrainingFeedbackData feedback)
  onSave;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  const TrainingFeedbackScreen({
    super.key,
    required this.onSave,
  });

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  State<TrainingFeedbackScreen> createState() => _TrainingFeedbackScreenState();
}

class _TrainingFeedbackScreenState extends State<TrainingFeedbackScreen> {
  int? _focus;
  int? _stress;
  int? _energia;
  int? _fiducia;
  int? _distrazioni;
  final TextEditingController _commentoController = TextEditingController();
  OverlayState? _overlayState;
  String? _overlayMessage;
  String? _savedSessionId;

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  void dispose() {
    _commentoController.dispose();
    super.dispose();
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget _scoreField(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<int?>(
            value: value,
            hint: const Text('—'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('—')),
              DropdownMenuItem(value: 1, child: Text('1')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 5, child: Text('5')),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> _submit() async {
    if (_overlayState == OverlayState.loading) return;

    final feedback = TrainingFeedbackData(
      focus: _focus,
      stress: _stress,
      energia: _energia,
      fiducia: _fiducia,
      distrazioni: _distrazioni,
      commento: _commentoController.text.trim().isEmpty
          ? null
          : _commentoController.text.trim(),
    );

    /// Funzione: descrive in modo semplice questo blocco di logica.
    setState(() {
      _overlayState = OverlayState.loading;
      _overlayMessage = 'Salvataggio in corso...';
    });

    try {
      final saveResult = await widget.onSave(feedback);
      if (!mounted) return;

      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() {
        _savedSessionId = saveResult.localId;
        switch (saveResult.status) {
          case LocalTrainingSyncStatus.pending:
            _overlayState = OverlayState.pending;
            _overlayMessage =
            'Salvato offline. Verrà sincronizzato automaticamente';
            break;
          case LocalTrainingSyncStatus.synced:
            _overlayState = OverlayState.success;
            _overlayMessage = 'Sessione salvata correttamente';
            break;
          case LocalTrainingSyncStatus.failed:
          case LocalTrainingSyncStatus.syncing:
            _overlayState = OverlayState.error;
            _overlayMessage = 'Salvata. Sync non riuscita';
            break;
        }
      });
    } catch (_) {
      if (!mounted) return;
      /// Funzione: descrive in modo semplice questo blocco di logica.
      setState(() {
        _overlayState = OverlayState.error;
        _overlayMessage = 'Salvata. Sync non riuscita';
      });
    }
  }

  @override
  /// Funzione: descrive in modo semplice questo blocco di logica.
  Widget build(BuildContext context) {
    final showOverlay = _overlayState != null;
    final loading = _overlayState == OverlayState.loading;

    /// Funzione: descrive in modo semplice questo blocco di logica.
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback sessione')),
      body: Stack(
        children: [
          /// Funzione: descrive in modo semplice questo blocco di logica.
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// Funzione: descrive in modo semplice questo blocco di logica.
              const Text(
                'Valutazioni (opzionale)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              const SizedBox(height: 12),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              _scoreField('Focus', _focus, (v) => setState(() => _focus = v)),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              _scoreField('Stress', _stress, (v) => setState(() => _stress = v)),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              _scoreField('Energia fisica', _energia, (v) => setState(() => _energia = v)),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              _scoreField('Fiducia', _fiducia, (v) => setState(() => _fiducia = v)),
              /// Funzione: descrive in modo semplice questo blocco di logica.
              _scoreField('Distrazioni', _distrazioni, (v) => setState(() => _distrazioni = v)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentoController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Commento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Salva'),
              ),
            ],
          ),
          if (showOverlay)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.transparent),
              ),
            ),
          if (showOverlay)
            Positioned.fill(
              child: BlockingOverlay(
                state: _overlayState!,
                message: _overlayMessage,
                primaryActionLabel: 'Vai alle statistiche',
                secondaryActionLabel: 'Torna alla home',
                onPrimaryAction: loading
                    ? null
                    : () {
                  Navigator.pop(
                    context,
                    TrainingFeedbackResult(
                      action: TrainingFeedbackAction.goToStats,
                      savedSessionId: _savedSessionId,
                    ),
                  );
                },
                onSecondaryAction: loading
                    ? null
                    : () {
                  Navigator.pop(
                    context,
                    TrainingFeedbackResult(
                      action: TrainingFeedbackAction.goHome,
                      savedSessionId: _savedSessionId,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
