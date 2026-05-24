import 'package:flutter/foundation.dart';

import '../../features/match_sync/data/services/local_match_sync_service.dart';
import '../../features/stats/data/datasources/local_training_sync_service.dart';
import '../../features/stats/shared/stats_repository.dart';

enum AppSyncReason {
  boot,
  login,
  reconnect,
  resume,
  manual,
}

class AppSyncOrchestrator {
  AppSyncOrchestrator._();

  static final AppSyncOrchestrator instance = AppSyncOrchestrator._();

  bool _running = false;
  DateTime? _lastSyncAt;

  bool get isRunning => _running;

  Future<void> syncNow({
    required AppSyncReason reason,
    bool force = false,
  }) async {
    if (_running) return;

    final now = DateTime.now();

    if (!force && _lastSyncAt != null) {
      final elapsed = now.difference(_lastSyncAt!);

      if (reason == AppSyncReason.resume &&
          elapsed < const Duration(seconds: 30)) {
        return;
      }

      if (reason == AppSyncReason.reconnect &&
          elapsed < const Duration(seconds: 10)) {
        return;
      }
    }

    _running = true;

    try {
      debugPrint('🔄 AppSync start: ${reason.name}');

      await LocalMatchSyncService.instance.syncAll();
      await LocalTrainingSyncService.instance.syncAll();

      StatsRepository.instance.invalidateCache();

      _lastSyncAt = DateTime.now();

      debugPrint('✅ AppSync complete: ${reason.name}');
    } catch (e, st) {
      debugPrint('❌ AppSync error (${reason.name}): $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _running = false;
    }
  }

  void resetSession() {
    _running = false;
    _lastSyncAt = null;
    StatsRepository.instance.invalidateCache();
  }
}