import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Modalità di filtro unificata per TUTTE le statistiche
enum StatsFilterMode {
  period,
  session,
}

/// Stato del filtro IMMUTABILE e condiviso
@immutable
class StatsFilterState {
  final StatsFilterMode mode;
  final DateTimeRange? periodRange;
  final String? selectedSessionId;
  final String? selectedSessionLabel;

  const StatsFilterState({
    required this.mode,
    this.periodRange,
    this.selectedSessionId,
    this.selectedSessionLabel,
  });

  static const empty = StatsFilterState(mode: StatsFilterMode.period);

  String get displayLabel {
    if (mode == StatsFilterMode.period && periodRange != null) {
      return '${DateFormat('dd/MM/yyyy').format(periodRange!.start)} - ${DateFormat('dd/MM/yyyy').format(periodRange!.end)}';
    }
    if (mode == StatsFilterMode.session && selectedSessionLabel != null) {
      return selectedSessionLabel!;
    }
    return 'Seleziona';
  }

  String get modeLabel => mode == StatsFilterMode.period ? 'Periodo' : 'Sessione';

  StatsFilterState copyWith({
    StatsFilterMode? mode,
    DateTimeRange? periodRange,
    String? selectedSessionId,
    String? selectedSessionLabel,
  }) {
    return StatsFilterState(
      mode: mode ?? this.mode,
      periodRange: periodRange ?? this.periodRange,
      selectedSessionId: selectedSessionId ?? this.selectedSessionId,
      selectedSessionLabel: selectedSessionLabel ?? this.selectedSessionLabel,
    );
  }
}