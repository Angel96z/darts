/// File: stats_base_controller.dart
/// TARGET: Controller base per statistiche (X01, Cricket)
/// LOGIC GOAL: Gestire selezione match singolo / periodo, caching dati
/// REACTION: UI reagisce a cambiamenti di selezione
/// ERROR STRATEGY: Stato error con messaggio
/// ANTI-REGRESSION: Mantenere compatibilità con LocalMatchSyncService

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';

enum StatsSelectionMode {
  period,
  match,
}

@immutable
class StatsSelectionState {
  final StatsSelectionMode mode;
  final DateTimeRange? periodRange;
  final LocalMatchRecord? selectedMatch;
  final List<LocalMatchRecord> matches;
  final bool isLoading;
  final String? error;

  const StatsSelectionState({
    required this.mode,
    this.periodRange,
    this.selectedMatch,
    this.matches = const [],
    this.isLoading = false,
    this.error,
  });

  StatsSelectionState copyWith({
    StatsSelectionMode? mode,
    DateTimeRange? periodRange,
    LocalMatchRecord? selectedMatch,
    List<LocalMatchRecord>? matches,
    bool? isLoading,
    String? error,
  }) {
    return StatsSelectionState(
      mode: mode ?? this.mode,
      periodRange: periodRange ?? this.periodRange,
      selectedMatch: selectedMatch ?? this.selectedMatch,
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  String getRightLabel() {
    if (mode == StatsSelectionMode.period && periodRange != null) {
      return '${DateFormat('dd/MM').format(periodRange!.start)} - ${DateFormat('dd/MM').format(periodRange!.end)}';
    }
    if (mode == StatsSelectionMode.match && selectedMatch != null) {
      return DateFormat('dd/MM/yyyy HH:mm').format(selectedMatch!.startTime);
    }
    return 'Seleziona';
  }

  String getModeLabel() {
    return mode == StatsSelectionMode.period ? 'Periodo' : 'Partita';
  }

  List<LocalMatchRecord> getFilteredMatches() {
    if (mode == StatsSelectionMode.match && selectedMatch != null) {
      return [selectedMatch!];
    }
    if (mode == StatsSelectionMode.period && periodRange != null) {
      return matches.where((m) {
        final date = m.startTime;
        final start = DateTime(periodRange!.start.year, periodRange!.start.month, periodRange!.start.day);
        final end = DateTime(periodRange!.end.year, periodRange!.end.month, periodRange!.end.day, 23, 59, 59);
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(end.add(const Duration(milliseconds: 1)));
      }).toList();
    }
    return matches;
  }
}

class StatsBaseController extends ChangeNotifier {
  StatsSelectionState _state = const StatsSelectionState(
    mode: StatsSelectionMode.period,
  );

  StatsSelectionState get state => _state;

  Future<void> loadMatches(String modeFilter) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final all = await LocalMatchSyncService.instance.getAllRecords();
      final filtered = all.where((m) => m.mode == modeFilter).toList();
      filtered.sort((a, b) => b.startTime.compareTo(a.startTime));

      _state = _state.copyWith(
        matches: filtered,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  void setMode(StatsSelectionMode mode) {
    if (mode == StatsSelectionMode.period) {
      _state = _state.copyWith(
        mode: mode,
        selectedMatch: null,
        periodRange: _state.periodRange ?? _getDefaultRange(),
      );
    } else {
      _state = _state.copyWith(
        mode: mode,
        selectedMatch: null,
      );
    }
    notifyListeners();
  }

  void setPeriodRange(DateTimeRange range) {
    _state = _state.copyWith(
      periodRange: range,
      selectedMatch: null,
    );
    notifyListeners();
  }

  void setSelectedMatch(LocalMatchRecord match) {
    _state = _state.copyWith(
      mode: StatsSelectionMode.match,
      selectedMatch: match,
    );
    notifyListeners();
  }

  void clearSelection() {
    _state = _state.copyWith(
      selectedMatch: null,
    );
    notifyListeners();
  }

  DateTimeRange _getDefaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day - 30),
      end: now,
    );
  }
}