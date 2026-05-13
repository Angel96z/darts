import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stats_filter.dart';

/// Controller base per TUTTE le statistiche
/// Gestisce solo il filtro e lo stato di caricamento
abstract class BaseStatsController<TSession, TStats> extends ChangeNotifier {
  // Stato
  StatsFilterState _filterState = StatsFilterState.empty;
  List<TSession> _filteredSessions = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  StatsFilterState get filterState => _filterState;
  List<TSession> get filteredSessions => _filteredSessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Costruttore
  BaseStatsController() {
    _loadData();
  }

  // ========== METODI ASTRATTI DA IMPLEMENTARE ==========

  /// Carica TUTTE le sessioni (dal repository)
  @protected
  Future<List<TSession>> loadAllSessions();

  /// Filtra le sessioni in base allo stato corrente
  @protected
  List<TSession> filterSessions(
      List<TSession> all,
      StatsFilterState filter,
      );

  /// Calcola statistiche aggregate dalle sessioni filtrate
  TStats computeAggregatedStats(List<TSession> filtered);

  /// Ottiene la data di una sessione (per ordinamento)
  @protected
  DateTime getSessionDate(TSession session);

  /// Ottiene l'ID di una sessione
  @protected
  String getSessionId(TSession session);

  // ========== METODI CONCRETI ==========

  /// Carica i dati e applica il filtro
  Future<void> _loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final all = await loadAllSessions();
      _applyFilterToSessions(all);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applica filtro alle sessioni
  void _applyFilterToSessions(List<TSession> all) {
    _filteredSessions = filterSessions(all, _filterState);
    // Ordina per data discendente
    _filteredSessions.sort((a, b) => getSessionDate(b).compareTo(getSessionDate(a)));
    notifyListeners();
  }

  /// Imposta modalità Periodo
  void setPeriodRange(DateTimeRange range) {
    _filterState = _filterState.copyWith(
      mode: StatsFilterMode.period,
      periodRange: range,
      selectedSessionId: null,
      selectedSessionLabel: null,
    );
    _reloadData();
  }

  /// Imposta modalità Sessione
  void setSession(TSession session) {
    _filterState = _filterState.copyWith(
      mode: StatsFilterMode.session,
      selectedSessionId: getSessionId(session),
      selectedSessionLabel: _formatSessionLabel(session),
      periodRange: null,
    );
    _reloadData();
  }

  /// Ricarica i dati dal repository
  Future<void> reload() async {
    await _loadData();
  }

  /// Riapplica filtro senza ricaricare
  void _reloadData() {
    _loadAllSessionsAndFilter();
  }

  Future<void> _loadAllSessionsAndFilter() async {
    _isLoading = true;
    notifyListeners();

    try {
      final all = await loadAllSessions();
      _applyFilterToSessions(all);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Formatta l'etichetta di una sessione
  String _formatSessionLabel(TSession session) {
    return DateFormat('dd/MM/yyyy HH:mm').format(getSessionDate(session));
  }
}