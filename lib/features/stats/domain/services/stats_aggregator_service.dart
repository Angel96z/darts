/// File: stats_aggregator_service.dart
/// TARGET: Servizio per aggregare statistiche carriera in modo incrementale
/// LOGIC GOAL: Calcolare statistiche solo quando nuovi dati arrivano, mai all'avvio
/// REACTION: Aggiorna il profilo utente dopo ogni match/training salvato
/// ERROR STRATEGY: Fallback a ricalcolo completo se cache corrotta

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../players/domain/user_profile.dart';
import '../../../players/data/user_repository.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../entities/training_stats.dart';

class StatsAggregatorService {
  static final StatsAggregatorService _instance = StatsAggregatorService._internal();
  static StatsAggregatorService get instance => _instance;
  StatsAggregatorService._internal();

  final UserRepository _userRepo = UserRepository();
  bool _isAggregating = false;

  /// Aggiorna statistiche utente basate sui match e training salvati
  /// MAI chiamare all'avvio. Chiamare SOLO dopo aver salvato un match/training
  Future<void> updateUserStats({bool forceFullRecalc = false}) async {
    if (_isAggregating) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isAggregating = true;

    try {
      // Recupera profilo attuale
      UserProfile? currentProfile;
      try {
        currentProfile = await _userRepo.fetchProfile(user.uid);
      } catch (_) {
        // Profilo non esiste, lo creeremo
      }

      final lastStatsUpdate = currentProfile?.stats.lastMatchDate;

      // Determina se fare ricalcolo completo o incrementale
      final needFullRecalc = forceFullRecalc || lastStatsUpdate == null;

      if (needFullRecalc) {
        await _fullRecalc(user.uid);
      } else {
        await _incrementalUpdate(user.uid, lastStatsUpdate!);
      }
    } catch (e) {
      print('Errore aggregazione stats: $e');
    } finally {
      _isAggregating = false;
    }
  }

  /// Ricalcolo completo (usato solo la prima volta o su richiesta)
  Future<void> _fullRecalc(String uid) async {
    final allMatches = await LocalMatchSyncService.instance.getAllRecords();
    final allTrainings = await LocalTrainingSyncService.instance.getAllRecords();

    final stats = _calculateStats(allMatches, allTrainings, uid);

    await _saveStats(uid, stats);
  }

  /// Aggiornamento incrementale (SOLO nuovi dati dall'ultimo update)
  Future<void> _incrementalUpdate(String uid, DateTime lastUpdate) async {
    final allMatches = await LocalMatchSyncService.instance.getAllRecords();
    final allTrainings = await LocalTrainingSyncService.instance.getAllRecords();

    // Filtra solo i nuovi dati (dopo lastUpdate)
    final newMatches = allMatches.where((m) => m.endTime.isAfter(lastUpdate)).toList();
    final newTrainings = allTrainings.where((t) => t.endTime.isAfter(lastUpdate)).toList();

    if (newMatches.isEmpty && newTrainings.isEmpty) return;

    // Recupera stats attuali
    final currentProfile = await _userRepo.fetchProfile(uid);
    final currentStats = currentProfile.stats;

    // Calcola delta dai nuovi dati
    final delta = _calculateStats(newMatches, newTrainings, uid);

    // Combina con stats esistenti
    final updatedStats = UserAggregatedStats(
      totalMatches: currentStats.totalMatches + delta.totalMatches,
      totalMatchesWon: currentStats.totalMatchesWon + delta.totalMatchesWon,
      totalTrainingSessions: currentStats.totalTrainingSessions + delta.totalTrainingSessions,
      totalTrainingThrows: currentStats.totalTrainingThrows + delta.totalTrainingThrows,
      bestX01Average: delta.bestX01Average > currentStats.bestX01Average
          ? delta.bestX01Average
          : currentStats.bestX01Average,
      bestLegDarts: delta.bestLegDarts < currentStats.bestLegDarts
          ? delta.bestLegDarts
          : currentStats.bestLegDarts,
      bestCricketMPR: delta.bestCricketMPR > currentStats.bestCricketMPR
          ? delta.bestCricketMPR
          : currentStats.bestCricketMPR,
      total180s: currentStats.total180s + delta.total180s,
      total140s: currentStats.total140s + delta.total140s,
      total100s: currentStats.total100s + delta.total100s,
      totalCheckouts: currentStats.totalCheckouts + delta.totalCheckouts,
      bestCheckout: delta.bestCheckout > currentStats.bestCheckout
          ? delta.bestCheckout
          : currentStats.bestCheckout,
      lastMatchDate: delta.lastMatchDate ?? currentStats.lastMatchDate,
      lastTrainingDate: delta.lastTrainingDate ?? currentStats.lastTrainingDate,
    );

    await _saveStats(uid, updatedStats);
  }

  /// Calcola statistiche da una lista di match e training
  UserAggregatedStats _calculateStats(
      List<LocalMatchRecord> matches,
      List<LocalTrainingRecord> trainings,
      String uid,
      ) {
    int totalMatches = 0;
    int totalMatchesWon = 0;
    int totalTrainingSessions = 0;
    int totalTrainingThrows = 0;
    double bestX01Average = 0.0;
    double bestCricketMPR = 0.0;
    int total180s = 0;
    int total140s = 0;
    int total100s = 0;
    int totalCheckouts = 0;
    int bestCheckout = 0;
    int bestLegDarts = 999; // 🔥 Inizializza a valore alto
    DateTime? lastMatchDate;
    DateTime? lastTrainingDate;

    // Analizza match X01
    final x01Matches = matches.where((m) => m.mode == 'x01').toList();
    for (final match in x01Matches) {
      final playerTurns = match.playerTurns[uid] ?? [];
      if (playerTurns.isEmpty) continue;

      totalMatches++;
      if (match.winnerId == uid) totalMatchesWon++;

      if (match.endTime.isAfter(lastMatchDate ?? DateTime(2000))) {
        lastMatchDate = match.endTime;
      }

      int matchScore = 0;
      int matchDarts = 0;
      int matchCheckouts = 0;
      int match180s = 0;
      int match140s = 0;
      int match100s = 0;
      int legDartsAccumulator  = 0; // 🔥 Dardi totali usati per chiudere

      for (final turn in playerTurns) {
        matchScore += turn.total;
        matchDarts += turn.throws.length;
        // Accumula dardi per il leg corrente
        legDartsAccumulator += turn.throws.length;

        if (turn.isCheckout) {
          matchCheckouts++;
          if (turn.total > bestCheckout) bestCheckout = turn.total;

          // 🔥 Miglior leg: minimo dardi totali per chiudere
          if (legDartsAccumulator < bestLegDarts) {
            bestLegDarts = legDartsAccumulator;
          }

          // Reset per il prossimo leg
          legDartsAccumulator = 0;
        }
        if (turn.total == 180) match180s++;
        if (turn.total >= 140) match140s++;
        if (turn.total >= 100 && turn.total < 140) match100s++;
      }

      totalCheckouts += matchCheckouts;
      total180s += match180s;
      total140s += match140s;
      total100s += match100s;

      final average = matchDarts > 0 ? (matchScore / matchDarts) * 3 : 0.0;
      if (average > bestX01Average) bestX01Average = average;

    }

    // Analizza match Cricket
    final cricketMatches = matches.where((m) => m.mode == 'cricket').toList();
    for (final match in cricketMatches) {
      totalMatches++;
      if (match.winnerId == uid) totalMatchesWon++;

      if (match.endTime.isAfter(lastMatchDate ?? DateTime(2000))) {
        lastMatchDate = match.endTime;
      }

      // Calcola MPR (Marks Per Round) per Cricket
      final playerTurns = match.playerTurns[uid] ?? [];
      int totalMarks = 0;
      int totalTurns = playerTurns.length;

      for (final turn in playerTurns) {
        totalMarks += turn.totalMarks;
      }

      final mpr = totalTurns > 0 ? totalMarks / totalTurns : 0.0;
      if (mpr > bestCricketMPR) bestCricketMPR = mpr;
    }

    // Analizza training
    for (final training in trainings) {
      if (training.syncStatus == LocalTrainingSyncStatus.failed) continue;

      totalTrainingSessions++;
      totalTrainingThrows += training.throwsList.length;

      if (training.endTime.isAfter(lastTrainingDate ?? DateTime(2000))) {
        lastTrainingDate = training.endTime;
      }
    }

    return UserAggregatedStats(
      totalMatches: totalMatches,
      totalMatchesWon: totalMatchesWon,
      totalTrainingSessions: totalTrainingSessions,
      totalTrainingThrows: totalTrainingThrows,
      bestX01Average: bestX01Average,
      bestLegDarts: bestLegDarts == 999
          ? 0
          : bestLegDarts,
      bestCricketMPR: bestCricketMPR,
      total180s: total180s,
      total140s: total140s,
      total100s: total100s,
      totalCheckouts: totalCheckouts,
      bestCheckout: bestCheckout,
      lastMatchDate: lastMatchDate,
      lastTrainingDate: lastTrainingDate,
    );
  }
  Future<void> _saveStats(String uid, UserAggregatedStats stats) async {
    final currentProfile = await _userRepo.fetchProfile(uid);
    final updatedProfile = currentProfile.copyWith(stats: stats);
    await _userRepo.upsertProfile(updatedProfile);
  }

  /// Reset statistiche (senza eliminare match/training)
  Future<void> resetStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentProfile = await _userRepo.fetchProfile(user.uid);
    final resetStats = UserAggregatedStats(
      totalMatches: 0,
      totalMatchesWon: 0,
      totalTrainingSessions: 0,
      totalTrainingThrows: 0,
      bestX01Average: 0.0,
      bestCricketMPR: 0.0,
      total180s: 0,
      total140s: 0,
      total100s: 0,
      totalCheckouts: 0,
      bestCheckout: 0,
      lastMatchDate: null,
      lastTrainingDate: null,
    );
    final updatedProfile = currentProfile.copyWith(stats: resetStats);
    await _userRepo.upsertProfile(updatedProfile);
  }
}