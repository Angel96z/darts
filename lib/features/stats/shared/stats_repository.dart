import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../match_sync/data/services/local_match_sync_service.dart';
import '../../match_sync/domain/entities/local_match_record.dart';
import '../data/datasources/local_training_sync_service.dart';
import '../domain/services/stats_aggregator_service.dart';

/// Repository SINGLETON per TUTTI i dati statistici
/// Cache centralizzata per evitare chiamate duplicate
class StatsRepository {
  static final StatsRepository _instance = StatsRepository._internal();
  static StatsRepository get instance => _instance;
  StatsRepository._internal();

  // Cache
  List<LocalTrainingRecord>? _cachedTrainings;
  List<LocalMatchRecord>? _cachedMatches;
  DateTime? _trainingsCacheTimestamp;
  DateTime? _matchesCacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

  Future<List<LocalTrainingRecord>> getAllTrainings({bool forceRefresh = false}) async {
    final cacheTime = _trainingsCacheTimestamp;
    final isCacheValid = cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheDuration;

    if (!forceRefresh && _cachedTrainings != null && isCacheValid) {
      return _cachedTrainings!;
    }

    _cachedTrainings = await LocalTrainingSyncService.instance.getAllRecords();
    _trainingsCacheTimestamp = DateTime.now();
    return _cachedTrainings!;
  }

  Future<List<LocalMatchRecord>> getAllMatches({bool forceRefresh = false}) async {
    final cacheTime = _matchesCacheTimestamp;
    final isCacheValid = cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheDuration;

    if (!forceRefresh && _cachedMatches != null && isCacheValid) {
      return _cachedMatches!;
    }

    _cachedMatches = await LocalMatchSyncService.instance.getAllRecords();
    _matchesCacheTimestamp = DateTime.now();
    return _cachedMatches!;
  }

  void invalidateCache() {
    _cachedTrainings = null;
    _cachedMatches = null;
    _trainingsCacheTimestamp = null;
    _matchesCacheTimestamp = null;
  }

  // ========== METODI SPECIFICI ==========
  Future<int> resetGameData({
    required bool resetTraining,
    required bool resetX01,
    required bool resetCricket,
  }) async {
    var deletedCount = 0;

    if (resetTraining) {
      deletedCount += await LocalTrainingSyncService.instance.deleteAllRecords();
    }

    if (resetX01) {
      deletedCount += await LocalMatchSyncService.instance.deleteRecordsByMode('x01');
    }

    if (resetCricket) {
      deletedCount += await LocalMatchSyncService.instance.deleteRecordsByMode('cricket');
    }

    invalidateCache();
    await StatsAggregatorService.instance.updateUserStats(forceFullRecalc: true);
    invalidateCache();

    return deletedCount;
  }

  Future<List<LocalTrainingRecord>> getTrainingsByTarget(String target, {bool forceRefresh = false}) async {
    final all = await getAllTrainings(forceRefresh: forceRefresh);
    return all.where((t) => t.target == target).toList();
  }

  Future<List<LocalMatchRecord>> getMatchesByMode(String mode, {bool forceRefresh = false}) async {
    final all = await getAllMatches(forceRefresh: forceRefresh);
    return all.where((m) => m.mode == mode).toList();
  }
}