// match_session_stats.dart
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../../match_sync/domain/entities/local_match_record.dart' as sync_entities;

// Usa lo stesso enum del match
class MatchSessionStats {
  final String id;
  final String mode;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int totalTurns;
  final int totalDarts;
  final double average;
  final int checkouts;
  final int hitPercent;
  final sync_entities.LocalMatchSyncStatus? syncStatus;  // ← CAMBIA QUESTO
  final LocalMatchRecord matchRecord;

  const MatchSessionStats({
    required this.id,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalTurns,
    required this.totalDarts,
    required this.average,
    required this.checkouts,
    required this.hitPercent,
    required this.syncStatus,
    required this.matchRecord,
  });
}