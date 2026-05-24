/// File: training_feedback_screen.dart - Allineato al tema ufficiale AppTokens
/// Con carousel per valori 1-5, commento in alto, e resizeToAvoidBottomInset

import 'package:flutter/material.dart' hide OverlayState;

import '../../../../app_theme.dart';
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
  final Future<LocalTrainingSaveResult> Function(TrainingFeedbackData feedback) onSave;

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

  /// Widget carousel per selezione valore 1-5
  /// Widget carousel per selezione valore 1-10
  Widget _ratingCarousel(String label, int? value, ValueChanged<int?> onChanged) {
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: t.bodyBold(t.textSecondary),
              ),
            ),
            Text(
              value == null ? '—/10' : '$value/10',
              style: t.bodyBold(value == null ? t.textMuted : t.accent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(10, (index) {
              final ratingValue = index + 1;
              final isSelected = value == ratingValue;

              return GestureDetector(
                onTap: () => onChanged(ratingValue),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? t.accent : t.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? t.accent : t.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ratingValue.toString(),
                      style: t.numericMedium(
                        isSelected ? t.accentFg : t.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
      _overlayMessage = 'Salvataggio sessione...';
    });

    try {
      final saveResult = await widget.onSave(feedback);
      if (!mounted) return;

      setState(() {
        _savedSessionId = saveResult.localId;
        switch (saveResult.status) {
          case LocalTrainingSyncStatus.pending:
            _overlayState = OverlayState.pending;
            _overlayMessage = 'Salvata offline. Verrà sincronizzata automaticamente';
            break;

          case LocalTrainingSyncStatus.synced:
            _overlayState = OverlayState.success;
            _overlayMessage = 'Sessione salvata con successo';
            break;

          case LocalTrainingSyncStatus.syncing:
            _overlayState = OverlayState.pending;
            _overlayMessage = 'Salvataggio sessione...';
            break;

          case LocalTrainingSyncStatus.failed:
            _overlayState = OverlayState.error;
            _overlayMessage = 'Salvata. Sincronizzazione fallita';
            break;

          case LocalTrainingSyncStatus.pendingDelete:
          case LocalTrainingSyncStatus.failedDelete:
            _overlayState = OverlayState.error;
            _overlayMessage = 'Stato salvataggio non valido';
            break;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overlayState = OverlayState.error;
        _overlayMessage = 'Saved. Sync failed';
      });
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final t = AppTokens.of(context);
    final loading = _overlayState == OverlayState.loading;

    return Container(
      color: t.bg.withOpacity(0.95),
      child: Center(
        child: Card(
          color: t.surface,
          shape: RoundedRectangleBorder(borderRadius: AppTokens.r16),
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icona in base allo stato
                if (_overlayState == OverlayState.loading)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: t.accent,
                      strokeWidth: 3,
                    ),
                  ),
                if (_overlayState == OverlayState.success)
                  Icon(Icons.check_circle, color: t.green, size: 48),
                if (_overlayState == OverlayState.error)
                  Icon(Icons.error_outline, color: t.red, size: 48),
                if (_overlayState == OverlayState.pending)
                  Icon(Icons.sync, color: t.accent, size: 48),

                const SizedBox(height: 16),

                // Messaggio
                Text(
                  _overlayMessage ?? '',
                  style: t.bodyBold(t.textPrimary),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Bottoni
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loading
                            ? null
                            : () => Navigator.pop(
                          context,
                          TrainingFeedbackResult(
                            action: TrainingFeedbackAction.goHome,
                            savedSessionId: _savedSessionId,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: t.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTokens.r10,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                        'Torna alla home',
                          style: t.bodyBold(t.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () => Navigator.pop(
                          context,
                          TrainingFeedbackResult(
                            action: TrainingFeedbackAction.goToStats,
                            savedSessionId: _savedSessionId,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.accentFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTokens.r10,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
    'Vai alle statistiche',
                          style: t.bodyBold(t.accentFg),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final showOverlay = _overlayState != null;

    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
            'Feedback sessione',
          style: TextStyle(color: t.textPrimary),
        ),
        backgroundColor: t.surface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // FIX 1: padding fisso, senza viewInsets che creava spazio extra
            padding: const EdgeInsets.only(
              bottom: 20,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commento in alto
                Text(
            'Commento (opzionale)',
            style: t.bodyBold(t.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentoController,
                  minLines: 3,
                  maxLines: 5,
                  style: t.bodySmall(t.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Scrivi tue considerazioni...',
                    hintStyle: t.bodySmall(t.textMuted),
                    filled: true,
                    fillColor: t.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: AppTokens.r12,
                      borderSide: BorderSide(color: t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppTokens.r12,
                      borderSide: BorderSide(color: t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTokens.r12,
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 24),

                // Separatore
                Divider(color: t.divider),
                const SizedBox(height: 16),

                // Valutazioni
                Text(
                    'Valutazioni (opzionali)',
                  style: t.bodyBold(t.textPrimary),
                ),
                const SizedBox(height: 16),

                // Carousel per le valutazioni
                _ratingCarousel('🎯 Focus', _focus, (v) => setState(() => _focus = v)),
                _ratingCarousel('😰 Stress', _stress, (v) => setState(() => _stress = v)),
                _ratingCarousel('⚡ Energia', _energia, (v) => setState(() => _energia = v)),
                _ratingCarousel('💪 Fiducia', _fiducia, (v) => setState(() => _fiducia = v)),
                _ratingCarousel('📱 Distrazioni', _distrazioni, (v) => setState(() => _distrazioni = v)),

                const SizedBox(height: 24),

                // Bottone Salva
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.accentFg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTokens.r12,
                      ),
                    ),
                    child: const Text(
                      'Salva sessione',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // FIX 2: Overlay con colori coerenti al tema
          if (showOverlay) _buildOverlay(context),
        ],
      ),
    );
  }
}