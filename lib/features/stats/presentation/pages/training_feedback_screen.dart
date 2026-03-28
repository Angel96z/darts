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

  const TrainingFeedbackResult({
    required this.action,
    required this.savedSessionId,
  });
}

class TrainingFeedbackScreen extends StatefulWidget {
  final Future<LocalTrainingSaveResult> Function(TrainingFeedbackData feedback)
  onSave;

  const TrainingFeedbackScreen({
    super.key,
    required this.onSave,
  });

  @override
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
  void dispose() {
    _commentoController.dispose();
    super.dispose();
  }

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

    setState(() {
      _overlayState = OverlayState.loading;
      _overlayMessage = 'Salvataggio in corso...';
    });

    try {
      final saveResult = await widget.onSave(feedback);
      if (!mounted) return;

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
      setState(() {
        _overlayState = OverlayState.error;
        _overlayMessage = 'Salvata. Sync non riuscita';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = _overlayState != null;
    final loading = _overlayState == OverlayState.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback sessione')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Valutazioni (opzionale)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _scoreField('Focus', _focus, (v) => setState(() => _focus = v)),
              _scoreField('Stress', _stress, (v) => setState(() => _stress = v)),
              _scoreField('Energia fisica', _energia, (v) => setState(() => _energia = v)),
              _scoreField('Fiducia', _fiducia, (v) => setState(() => _fiducia = v)),
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
