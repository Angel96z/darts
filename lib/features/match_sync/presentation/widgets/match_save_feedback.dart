/// File: match_save_feedback.dart
/// Widget di feedback per il salvataggio del match

import 'package:flutter/material.dart';
import '../../domain/entities/local_match_record.dart';

class MatchSaveFeedback extends StatelessWidget {
  final LocalMatchSyncStatus status;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  const MatchSaveFeedback({
    super.key,
    required this.status,
    required this.onClose,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case LocalMatchSyncStatus.synced:
        message = '✅ Partita salvato con successo!';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case LocalMatchSyncStatus.pending:
        message = '⏳ Partita salvato in locale. Verrà sincronizzato automaticamente.';
        icon = Icons.cloud_queue;
        color = Colors.orange;
        break;
      case LocalMatchSyncStatus.syncing:
        message = '🔄 Sincronizzazione in corso...';
        icon = Icons.cloud_sync;
        color = Colors.blue;
        break;
      case LocalMatchSyncStatus.failed:
        message = '⚠️ Salvataggio fallito. Riprova più tardi.';
        icon = Icons.cloud_off;
        color = Colors.red;
        break;
      case LocalMatchSyncStatus.pendingDelete:
        message = '🗑️ Eliminazione in attesa di sincronizzazione.';
        icon = Icons.delete_sweep_outlined;
        color = Colors.orange;
        break;
      case LocalMatchSyncStatus.failedDelete:
        message = '⚠️ Eliminazione non sincronizzata. Riprova più tardi.';
        icon = Icons.delete_forever_outlined;
        color = Colors.red;
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == LocalMatchSyncStatus.failed && onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('RIPROVA'),
                  ),
                TextButton(
                  onPressed: onClose,
                  child: const Text('CHIUDI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}