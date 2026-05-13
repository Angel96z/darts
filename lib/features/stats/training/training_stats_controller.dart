// training_stats_controller.dart - VERSIONE COMPLETA
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/datasources/local_training_sync_service.dart';
import '../presentation/pages/training_stats_screen.dart';
import '../shared/stats_filter.dart';
import '../shared/stats_repository.dart';

/// Controller per statistiche Training
class TrainingStatsController extends ChangeNotifier {
  final String target;
  final String? initialSessionId;

  // Stato
  StatsFilterState _filterState = const StatsFilterState(mode: StatsFilterMode.period);
  List<TrainingSessionStats> _allSessions = [];
  List<TrainingSessionStats> _filteredSessions = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  StatsFilterState get filterState => _filterState;
  List<TrainingSessionStats> get filteredSessions => _filteredSessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TrainingStatsController({
    required this.target,
    this.initialSessionId,
  }) {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allSessions = await _loadAllSessions();
      _applyFilter();

      // Se c'è un initialSessionId, selezionalo
      if (initialSessionId != null && _filteredSessions.isNotEmpty) {
        final matching = _filteredSessions.cast<TrainingSessionStats?>().firstWhere(
              (s) => s?.id == initialSessionId,
          orElse: () => null,
        );
        if (matching != null) {
          setSession(matching);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TrainingSessionStats>> _loadAllSessions() async {
    final sessions = <TrainingSessionStats>[];
    final added = <String>{};

    // Da cache locale
    final localRecords = await LocalTrainingSyncService.instance.getAllRecords();
    for (final local in localRecords.where((e) => e.target == target)) {
      final id = local.remoteId ?? local.localId;
      if (added.contains(id)) continue;
      added.add(id);
      sessions.add(TrainingSessionStats.fromRecord(local));
    }

    // Da Firestore
    final remoteRecords = await StatsRepository.instance.getTrainingsByTarget(target);
    for (final remote in remoteRecords) {
      final id = remote.remoteId ?? remote.localId;
      if (added.contains(id)) continue;
      sessions.add(TrainingSessionStats.fromRecord(remote));
    }

    return sessions;
  }

  void _applyFilter() {
    if (_filterState.mode == StatsFilterMode.session && _filterState.selectedSessionId != null) {
      _filteredSessions = _allSessions.where((s) => s.id == _filterState.selectedSessionId).toList();
    } else if (_filterState.mode == StatsFilterMode.period && _filterState.periodRange != null) {
      final start = DateTime(
        _filterState.periodRange!.start.year,
        _filterState.periodRange!.start.month,
        _filterState.periodRange!.start.day,
      );
      final end = DateTime(
        _filterState.periodRange!.end.year,
        _filterState.periodRange!.end.month,
        _filterState.periodRange!.end.day,
        23, 59, 59,
      );
      _filteredSessions = _allSessions.where((s) {
        final date = s.startTime;
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
    } else {
      _filteredSessions = List.from(_allSessions);
    }

    _filteredSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();
  }

  void setPeriodRange(DateTimeRange range) {
    _filterState = StatsFilterState(
      mode: StatsFilterMode.period,
      periodRange: range,
      selectedSessionId: null,
      selectedSessionLabel: null,
    );
    _applyFilter();
  }

  void setSession(TrainingSessionStats session) {
    _filterState = StatsFilterState(
      mode: StatsFilterMode.session,
      selectedSessionId: session.id,
      selectedSessionLabel: DateFormat('dd/MM/yyyy HH:mm').format(session.startTime),
      periodRange: null,
    );
    _applyFilter();
  }

  void clearSession() {
    _filterState = StatsFilterState(mode: StatsFilterMode.period);
    _applyFilter();
  }

  Future<void> reload() async {
    await _loadData();
  }
}