import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../../room_v4/domain/models/game_config.dart';
import '../../../room_v4/presentation/room_lobby_page.dart';
import '../../cricket_dart_extractor.dart';
import '../../shared/stats_filter.dart';
import '../widgets/match_session_stats.dart';
import '../widgets/session_picker_screen.dart';
import '../widgets/stats_filter_bar.dart';
import '../widgets/unified_stats_chart.dart';

class CricketStatsController extends ChangeNotifier {
  final _extractor = const CricketDartExtractor();

  List<LocalMatchRecord> _allMatches = [];
  List<LocalMatchRecord> _filteredMatches = [];
  LocalMatchRecord? _selectedMatch;
  CricketDartDataset _dataset = const CricketDartDataset(darts: []);
  bool _loading = true;
  String? _error;

  StatsFilterState _filterState = StatsFilterState(
    mode: StatsFilterMode.period,
    periodRange: DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    ),
  );


  List<LocalMatchRecord> get matches => _filteredMatches;
  LocalMatchRecord? get selectedMatch => _selectedMatch;
  CricketDartDataset get dataset => _dataset;
  bool get isLoading => _loading;
  String? get error => _error;
  StatsFilterState get filterState => _filterState;

  Future<void> loadMatches() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final all = await LocalMatchSyncService.instance.getAllRecords();
      _allMatches = all
          .where((m) => m.mode == 'cricket' && m.isVisible)
          .toList();
      _allMatches.sort((a, b) => b.startTime.compareTo(a.startTime));
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _applyFilter() {
    if (_filterState.mode == StatsFilterMode.session && _filterState.selectedSessionId != null) {
      _filteredMatches = _allMatches.where((m) {
        final id = m.remoteId ?? m.localId;
        return id == _filterState.selectedSessionId;
      }).toList();
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
        23,
        59,
        59,
      );

      _filteredMatches = _allMatches.where((m) {
        return m.startTime.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            m.startTime.isBefore(end.add(const Duration(milliseconds: 1)));
      }).toList();
    } else {
      _filteredMatches = List.from(_allMatches);
    }

    _rebuildDataset();
    notifyListeners();
  }

  void _rebuildDataset() {
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    _dataset = _extractor.extract(
      records: _filteredMatches,
      playerId: playerId == null || playerId.isEmpty ? null : playerId,
    );
  }

  void setPeriodRange(DateTimeRange range) {
    _selectedMatch = null;
    _filterState = StatsFilterState(
      mode: StatsFilterMode.period,
      periodRange: range,
      selectedSessionId: null,
      selectedSessionLabel: null,
    );
    _applyFilter();
  }

  void setSession(LocalMatchRecord match) {
    _selectedMatch = null;
    final id = match.remoteId ?? match.localId;

    _filterState = StatsFilterState(
      mode: StatsFilterMode.session,
      selectedSessionId: id,
      selectedSessionLabel: DateFormat('dd/MM/yyyy HH:mm').format(match.startTime),
      periodRange: null,
    );
    _applyFilter();
  }

  void selectMatch(LocalMatchRecord match) {
    _selectedMatch = match;
    final playerId = FirebaseAuth.instance.currentUser?.uid;
    _dataset = _extractor.extract(
      records: [match],
      playerId: playerId == null || playerId.isEmpty ? null : playerId,
    );
    notifyListeners();
  }

  void clearSelection() {
    _selectedMatch = null;
    _rebuildDataset();
    notifyListeners();
  }
}

class CricketStatsScreen extends StatefulWidget {
  final bool showAppBar;

  const CricketStatsScreen({
    super.key,
    this.showAppBar = false,
  });

  @override
  State<CricketStatsScreen> createState() => _CricketStatsScreenState();
}

class _CricketStatsScreenState extends State<CricketStatsScreen>
    with AutomaticKeepAliveClientMixin {
  late final CricketStatsController _controller;
  StreamSubscription<dynamic>? _syncSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = CricketStatsController();
    _controller.loadMatches();

    _syncSubscription = LocalMatchSyncService.instance.onSyncStatusChanged.listen((_) {
      if (!mounted) return;
      _controller.loadMatches();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleModeTap() async {
    final mode = await showStatsModeDialog(context);
    if (mode == null) return;

    if (mode == StatsFilterMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _controller.filterState.periodRange,
      );
      if (range != null) {
        _controller.setPeriodRange(range);
      }
    } else {
      await _openSessionPicker();
    }
  }

  Future<void> _handleSelectorTap() async {
    if (_controller.filterState.mode == StatsFilterMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _controller.filterState.periodRange,
      );
      if (range != null) {
        _controller.setPeriodRange(range);
      }
    } else {
      await _openSessionPicker();
    }
  }

  Future<void> _openSessionPicker() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionPickerScreen<MatchSessionStats>(
          type: SessionType.match,
          filterBy: 'cricket',
          highlightedId: _controller.filterState.selectedSessionId,
          onSelect: (session) {
            _controller.setSession(session.matchRecord);
          },
          allowDelete: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.showAppBar
          ? AppBar(
        title: Text(
          'Cricket',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.textPrimary),
        ),
        backgroundColor: t.surface,
        elevation: 0,
      )
          : null,
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (_, __) {
              return StatsFilterBar(
                state: _controller.filterState,
                onModeTap: _handleModeTap,
                onSelectorTap: _handleSelectorTap,
              );
            },
          ),
          Divider(color: t.divider, height: 1),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (_, __) {
                if (_controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.error != null) {
                  return _StateMessage(
                    icon: Icons.error_outline_rounded,
                    title: 'Errore caricamento statistiche',
                    subtitle: _controller.error!,
                    color: t.red,
                    t: t,
                    action: ElevatedButton(
                      onPressed: _controller.loadMatches,
                      child: const Text('RIPROVA'),
                    ),
                  );
                }

                if (_controller.matches.isEmpty) {
                  return _StateMessage(
                    icon: Icons.sports_score_rounded,
                    title: 'Nessuna partita Cricket trovata',
                    subtitle: 'Gioca almeno una partita Cricket per vedere le statistiche.',
                    color: t.textMuted,
                    t: t,
                    action: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomLobbyPage(
                              initialGameType: GameType.cricket,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Gioca a Cricket'),
                    ),
                  );
                }

                if (_controller.selectedMatch != null) {
                  return _CricketStatsView(
                    title: DateFormat('dd/MM/yyyy HH:mm').format(_controller.selectedMatch!.startTime),
                    subtitle: 'Vincitore: ${_controller.selectedMatch!.winnerName}',
                    dataset: _controller.dataset,
                    matchesCount: 1,
                    onBack: _controller.clearSelection,
                    t: t,
                  );
                }

                return _CricketStatsView(
                  title: _controller.filterState.displayLabel,
                  subtitle: '${_controller.matches.length} partite Cricket',
                  dataset: _controller.dataset,
                  matchesCount: _controller.matches.length,
                  matches: _controller.matches,
                  onMatchTap: _controller.selectMatch,
                  t: t,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CricketStatsView extends StatelessWidget {
  final String title;
  final String subtitle;
  final CricketDartDataset dataset;
  final int matchesCount;
  final List<LocalMatchRecord> matches;
  final void Function(LocalMatchRecord)? onMatchTap;
  final VoidCallback? onBack;
  final AppTokens t;

  const _CricketStatsView({
    required this.title,
    required this.subtitle,
    required this.dataset,
    required this.matchesCount,
    required this.t,
    this.matches = const [],
    this.onMatchTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final targetSummaries = _TargetSummary.fromDataset(dataset);

    return ListView(
      cacheExtent: 1800,
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 10),
        RepaintBoundary(
          child: _CricketImpactSummaryCard(
            summary: _CricketImpactSummary.fromDataset(dataset),
            t: t,
          ),
        ),

        const SizedBox(height: 10),
        RepaintBoundary(
          child: _SectionCard(
            title: 'Performance settori - leg vinti',
            t: t,
            child: _SectorPerformanceTable(
              rows: _SectorPerformanceRow.fromDataset(
                dataset,
                result: _SectorLegResult.won,
              ),
              t: t,
            ),
          ),
        ),
        const SizedBox(height: 10),
        RepaintBoundary(
          child: _SectionCard(
            title: 'Performance settori - leg persi',
            t: t,
            child: _SectorPerformanceTable(
              rows: _SectorPerformanceRow.fromDataset(
                dataset,
                result: _SectorLegResult.lost,
              ),
              t: t,
            ),
          ),
        ),

      ],
    );
  }

  static double _avgMissPerLeg(CricketDartDataset dataset) {
    if (dataset.legs.isEmpty) return 0;
    return dataset.legs.fold<double>(0, (sum, leg) => sum + leg.missCount) / dataset.legs.length;
  }

  static double _avgPointsPerLeg(CricketDartDataset dataset) {
    if (dataset.legs.isEmpty) return 0;
    return dataset.legs.fold<double>(0, (sum, leg) => sum + leg.pointsGenerated) / dataset.legs.length;
  }

  static double _avgMarksPerTurn(CricketDartDataset dataset) {
    if (dataset.turns.isEmpty) return 0;
    return dataset.turns.fold<double>(0, (sum, turn) => sum + turn.marksHit) / dataset.turns.length;
  }

  static double _avgPointsPerTurn(CricketDartDataset dataset) {
    if (dataset.turns.isEmpty) return 0;
    return dataset.turns.fold<double>(0, (sum, turn) => sum + turn.pointsGenerated) / dataset.turns.length;
  }
}

class _CricketImpactSummary {
  final int wonLegs;
  final int lostLegs;
  final double wonMarkerAverage;
  final double lostMarkerAverage;
  final double wonRoundsAverage;
  final double lostRoundsAverage;

  const _CricketImpactSummary({
    required this.wonLegs,
    required this.lostLegs,
    required this.wonMarkerAverage,
    required this.lostMarkerAverage,
    required this.wonRoundsAverage,
    required this.lostRoundsAverage,
  });

  static _CricketImpactSummary fromDataset(CricketDartDataset dataset) {
    final wonLegs = dataset.legs.where((leg) => leg.isFinished && leg.isWon).toList();
    final lostLegs = dataset.legs.where((leg) => leg.isFinished && leg.isLost).toList();

    return _CricketImpactSummary(
      wonLegs: wonLegs.length,
      lostLegs: lostLegs.length,
      wonMarkerAverage: _markerAverage(wonLegs),
      lostMarkerAverage: _markerAverage(lostLegs),
      wonRoundsAverage: _roundsAverage(wonLegs),
      lostRoundsAverage: _roundsAverage(lostLegs),
    );
  }

  static double _markerAverage(List<CricketLegSlice> legs) {
    final validDarts = legs
        .expand((leg) => leg.darts)
        .where((dart) => dart.isValidCricketTarget && !dart.isMiss)
        .toList();

    if (validDarts.isEmpty) return 0;

    final marks = validDarts.fold<int>(
      0,
          (sum, dart) => sum + dart.rawMarksAdded,
    );

    return marks / validDarts.length;
  }

  static double _roundsAverage(List<CricketLegSlice> legs) {
    if (legs.isEmpty) return 0;

    final totalRounds = legs.fold<int>(0, (sum, leg) {
      final rounds = leg.darts.map((dart) => dart.roundKey).toSet().length;
      return sum + rounds;
    });

    return totalRounds / legs.length;
  }
}

class _CricketImpactSummaryCard extends StatelessWidget {
  final _CricketImpactSummary summary;
  final AppTokens t;

  const _CricketImpactSummaryCard({
    required this.summary,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return UnifiedStatsCard(
      title: 'WIN VS LOSE',
      subtitle: 'Confronto tra leg vinti e leg persi su marker e round medi',
      info: const UnifiedStatsInfoData(
        title: 'Come leggere la sezione',
        text: 'Questa sezione confronta i leg vinti e persi nel Cricket usando marker medi e round medi. Serve a capire se vinci perché marchi meglio, chiudi prima o mantieni più ritmo nei settori.',
        advice: [
          'Se AVG marker vinti è più alto, nei leg buoni colpisci meglio i settori Cricket.',
          'Se AVG round persi è alto, chiudi o marchi troppo lentamente.',
          'Usa questo confronto per capire se il problema è precisione o ritmo.',
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceHigh,
              border: Border(
                top: BorderSide(color: t.divider),
                bottom: BorderSide(color: t.divider),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _CricketMetricCell(label: 'Leg vinti', value: '${summary.wonLegs}', color: t.green, t: t),
                    _CricketMetricCell(label: 'Leg persi', value: '${summary.lostLegs}', color: t.red, t: t),
                  ],
                ),
                Row(
                  children: [
                    _CricketMetricCell(label: 'AVG marker vinti', value: summary.wonMarkerAverage.toStringAsFixed(2), color: t.green, t: t),
                    _CricketMetricCell(label: 'AVG marker persi', value: summary.lostMarkerAverage.toStringAsFixed(2), color: t.red, t: t),
                  ],
                ),
                Row(
                  children: [
                    _CricketMetricCell(label: 'AVG round vinti', value: summary.wonRoundsAverage.toStringAsFixed(1), color: t.green, t: t),
                    _CricketMetricCell(label: 'AVG round persi', value: summary.lostRoundsAverage.toStringAsFixed(1), color: t.red, t: t),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sezione standardizzata: confronta il rendimento Cricket tra leg vinti e persi.',
                    style: tt.bodySmall?.copyWith(color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CricketMetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppTokens t;

  const _CricketMetricCell({
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: t.divider),
            bottom: BorderSide(color: t.divider),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SectorLegResult {
  won,
  lost,
}

enum _SectorPerformanceRowType {
  target,
  miss,
  average,
}

class _SectorPerformanceRow {
  final _SectorPerformanceRowType type;
  final String label;
  final int legCount;
  final int darts;
  final int singles;
  final int doubles;
  final int triples;
  final double markerAverage;
  final double dartsToCloseAverage;
  final double dartsPerLegAverage;
  final double roundsPerLegAverage;

  const _SectorPerformanceRow({
    required this.type,
    required this.label,
    required this.legCount,
    required this.darts,
    required this.singles,
    required this.doubles,
    required this.triples,
    required this.markerAverage,
    required this.dartsToCloseAverage,
    required this.dartsPerLegAverage,
    required this.roundsPerLegAverage,
  });

  double get singlePercentage => darts > 0 ? (singles / darts) * 100 : 0;
  double get doublePercentage => darts > 0 ? (doubles / darts) * 100 : 0;
  double get triplePercentage => darts > 0 ? (triples / darts) * 100 : 0;

  String get markerAverageText {
    if (type == _SectorPerformanceRowType.miss) return '-';
    if (darts == 0) return '-';
    return markerAverage.toStringAsFixed(2);
  }

  String get dartsToCloseText {
    if (type == _SectorPerformanceRowType.miss) return '-';
    if (dartsToCloseAverage <= 0) return '-';
    return dartsToCloseAverage.toStringAsFixed(1);
  }

  String get singlePercentageText {
    if (type == _SectorPerformanceRowType.miss || darts == 0) return '-';
    return '${singlePercentage.toStringAsFixed(0)}%';
  }

  String get doublePercentageText {
    if (type == _SectorPerformanceRowType.miss || darts == 0) return '-';
    return '${doublePercentage.toStringAsFixed(0)}%';
  }

  String get triplePercentageText {
    if (type == _SectorPerformanceRowType.miss || darts == 0) return '-';
    return '${triplePercentage.toStringAsFixed(0)}%';
  }

  String get dartsPerLegText {
    if (legCount == 0) return '-';
    return dartsPerLegAverage.toStringAsFixed(1);
  }

  String get roundsPerLegText {
    if (type != _SectorPerformanceRowType.average) return '-';
    if (roundsPerLegAverage <= 0) return '-';
    return roundsPerLegAverage.toStringAsFixed(1);
  }

  static List<_SectorPerformanceRow> fromDataset(
      CricketDartDataset dataset, {
        required _SectorLegResult result,
      }) {
    const targets = [20, 19, 18, 17, 16, 15, 25];

    final legs = dataset.legs.where((leg) {
      if (!leg.isFinished) return false;
      return result == _SectorLegResult.won ? leg.isWon : leg.isLost;
    }).toList();

    final rows = <_SectorPerformanceRow>[];

    int totalValidDarts = 0;
    int totalSingles = 0;
    int totalDoubles = 0;
    int totalTriples = 0;
    int totalMarks = 0;
    final allCloseValues = <int>[];

    for (final target in targets) {
      final targetDarts = <CricketDartAtom>[];
      final closeValues = <int>[];

      for (final leg in legs) {
        final legTargetDarts = leg.darts
            .where((dart) => dart.dartTarget == target && dart.isValidCricketTarget && !dart.isMiss)
            .toList();

        targetDarts.addAll(legTargetDarts);

        int marks = 0;
        for (int i = 0; i < legTargetDarts.length; i++) {
          marks += legTargetDarts[i].rawMarksAdded;

          if (marks >= 3) {
            closeValues.add(i + 1);
            allCloseValues.add(i + 1);
            break;
          }
        }
      }

      final singles = targetDarts.where((dart) => dart.isSingle).length;
      final doubles = targetDarts.where((dart) => dart.isDouble).length;
      final triples = targetDarts.where((dart) => dart.isTriple).length;
      final marks = targetDarts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);

      totalValidDarts += targetDarts.length;
      totalSingles += singles;
      totalDoubles += doubles;
      totalTriples += triples;
      totalMarks += marks;

      rows.add(
        _SectorPerformanceRow(
          type: _SectorPerformanceRowType.target,
          label: target == 25 ? 'BULL' : '$target',
          legCount: legs.length,
          darts: targetDarts.length,
          singles: singles,
          doubles: doubles,
          triples: triples,
          markerAverage: targetDarts.isEmpty ? 0 : marks / targetDarts.length,
          dartsToCloseAverage: closeValues.isEmpty
              ? 0
              : closeValues.fold<int>(0, (sum, value) => sum + value) / closeValues.length,
          dartsPerLegAverage: legs.isEmpty ? 0 : targetDarts.length / legs.length,
          roundsPerLegAverage: 0,
        ),
      );
    }

    final missCount = legs.fold<int>(
      0,
          (sum, leg) => sum + leg.darts.where((dart) => dart.isMiss).length,
    );

    rows.add(
      _SectorPerformanceRow(
        type: _SectorPerformanceRowType.miss,
        label: 'MISS',
        legCount: legs.length,
        darts: missCount,
        singles: 0,
        doubles: 0,
        triples: 0,
        markerAverage: 0,
        dartsToCloseAverage: 0,
        dartsPerLegAverage: legs.isEmpty ? 0 : missCount / legs.length,
        roundsPerLegAverage: 0,
      ),
    );

    final totalRounds = legs.fold<int>(0, (sum, leg) {
      final rounds = leg.darts.map((dart) => dart.roundKey).toSet().length;
      return sum + rounds;
    });

    rows.add(
      _SectorPerformanceRow(
        type: _SectorPerformanceRowType.average,
        label: 'MEDIA',
        legCount: legs.length,
        darts: totalValidDarts,
        singles: totalSingles,
        doubles: totalDoubles,
        triples: totalTriples,
        markerAverage: totalValidDarts == 0 ? 0 : totalMarks / totalValidDarts,
        dartsToCloseAverage: allCloseValues.isEmpty
            ? 0
            : allCloseValues.fold<int>(0, (sum, value) => sum + value) / allCloseValues.length,
        dartsPerLegAverage: legs.isEmpty ? 0 : totalValidDarts / legs.length,
        roundsPerLegAverage: legs.isEmpty ? 0 : totalRounds / legs.length,
      ),
    );

    return rows;
  }
}

class _SectorPerformanceTable extends StatelessWidget {
  final List<_SectorPerformanceRow> rows;
  final AppTokens t;

  const _SectorPerformanceTable({
    required this.rows,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectorPerformanceHeader(t: t),
        for (final row in rows) _SectorPerformanceLine(row: row, t: t),
      ],
    );
  }
}

class _SectorPerformanceHeader extends StatelessWidget {
  final AppTokens t;

  const _SectorPerformanceHeader({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.08),
        borderRadius: AppTokens.r6,
      ),
      child: Row(
        children: [
          _SectorCell('Sett.', t: t, isHeader: true, flex: 15),
          _SectorCell('AVG', t: t, isHeader: true, flex: 13),
          _SectorCell('Close', t: t, isHeader: true, flex: 14),
          _SectorCell('S%', t: t, isHeader: true, flex: 10),
          _SectorCell('D%', t: t, isHeader: true, flex: 10),
          _SectorCell('T%', t: t, isHeader: true, flex: 10),
          _SectorCell('D/Leg', t: t, isHeader: true, flex: 14),
          _SectorCell('Round', t: t, isHeader: true, flex: 14),
        ],
      ),
    );
  }
}

class _SectorPerformanceLine extends StatelessWidget {
  final _SectorPerformanceRow row;
  final AppTokens t;

  const _SectorPerformanceLine({
    required this.row,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final isAverage = row.type == _SectorPerformanceRowType.average;
    final isMiss = row.type == _SectorPerformanceRowType.miss;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: isAverage ? t.accent.withOpacity(0.06) : null,
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          _SectorCell(
            row.label,
            t: t,
            flex: 15,
            isStrong: true,
            color: isMiss ? t.orange : (isAverage ? t.accent : null),
          ),
          _SectorCell(row.markerAverageText, t: t, flex: 13, color: isAverage ? t.accent : t.textPrimary),
          _SectorCell(row.dartsToCloseText, t: t, flex: 14, color: t.green),
          _SectorCell(row.singlePercentageText, t: t, flex: 10),
          _SectorCell(row.doublePercentageText, t: t, flex: 10),
          _SectorCell(row.triplePercentageText, t: t, flex: 10),
          _SectorCell(row.dartsPerLegText, t: t, flex: 14, color: isMiss ? t.orange : null),
          _SectorCell(row.roundsPerLegText, t: t, flex: 14, color: isAverage ? t.accent : t.textMuted),
        ],
      ),
    );
  }
}

class _SectorCell extends StatelessWidget {
  final String text;
  final AppTokens t;
  final int flex;
  final bool isHeader;
  final bool isStrong;
  final Color? color;

  const _SectorCell(
      this.text, {
        required this.t,
        this.flex = 1,
        this.isHeader = false,
        this.isStrong = false,
        this.color,
      });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: (isHeader ? tt.labelSmall : tt.bodySmall)?.copyWith(
          color: color ?? (isHeader ? t.textSecondary : t.textPrimary),
        ),
      ),
    );
  }
}



class _TargetSummary {
  final int target;
  final int darts;
  final int marks;
  final int effectiveMarks;
  final int points;
  final int scoringDarts;
  final int closedLegs;
  final double avgDartsToClose;
  final double rawCloseAverage;
  final double effectiveCloseAverage;

  const _TargetSummary({
    required this.target,
    required this.darts,
    required this.marks,
    required this.effectiveMarks,
    required this.points,
    required this.scoringDarts,
    required this.closedLegs,
    required this.avgDartsToClose,
    required this.rawCloseAverage,
    required this.effectiveCloseAverage,
  });

  String get label => target == 25 ? 'BULL' : '$target';

  static List<_TargetSummary> fromDataset(CricketDartDataset dataset) {
    const targets = [20, 19, 18, 17, 16, 15, 25];

    return targets.map((target) {
      final targetDarts = dataset.darts.where((d) => d.dartTarget == target && !d.isMiss).toList();

      final closeStats = <CricketTargetStats>[];
      for (final leg in dataset.legs) {
        final legTargetDarts = leg.darts.where((d) => d.dartTarget == target && !d.isMiss).toList();
        if (legTargetDarts.isEmpty) continue;

        final stats = CricketTargetStats(target: target, darts: legTargetDarts);
        if (stats.dartsToClose > 0) closeStats.add(stats);
      }

      final avgDartsToClose = closeStats.isEmpty
          ? 0.0
          : closeStats.fold<double>(0, (sum, s) => sum + s.dartsToClose) / closeStats.length;

      final rawCloseAverage = closeStats.isEmpty
          ? 0.0
          : closeStats.fold<double>(0, (sum, s) => sum + s.rawCloseMultiplierAverage) / closeStats.length;

      final effectiveCloseAverage = closeStats.isEmpty
          ? 0.0
          : closeStats.fold<double>(0, (sum, s) => sum + s.effectiveCloseMultiplierAverage) / closeStats.length;

      return _TargetSummary(
        target: target,
        darts: targetDarts.length,
        marks: targetDarts.fold<int>(0, (sum, d) => sum + d.rawMarksAdded),
        effectiveMarks: targetDarts.fold<int>(0, (sum, d) => sum + d.effectiveMarksAdded),
        points: targetDarts.fold<int>(0, (sum, d) => sum + d.pointsGenerated),
        scoringDarts: targetDarts.where((d) => d.pointsGenerated > 0).length,
        closedLegs: closeStats.length,
        avgDartsToClose: avgDartsToClose,
        rawCloseAverage: rawCloseAverage,
        effectiveCloseAverage: effectiveCloseAverage,
      );
    }).toList();
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final AppTokens t;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return UnifiedStatsCard(
      title: title.toUpperCase(),
      subtitle: 'Tabella rendimento settori Cricket',
      info: const UnifiedStatsInfoData(
        title: 'Come leggere la tabella',
        text: 'Questa tabella confronta il rendimento dei settori Cricket: marker prodotti, chiusura del settore e distribuzione tra singoli, doppi e tripli.',
        advice: [
          'Controlla i settori con pochi marker per capire dove perdi precisione.',
          'Confronta S, D e T per capire se il problema è nella mira base o nei moltiplicatori.',
          'Nei leg persi cerca i settori che restano indietro più spesso.',
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceHigh,
              border: Border(
                top: BorderSide(color: t.divider),
                bottom: BorderSide(color: t.divider),
              ),
            ),
            child: child,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.table_chart_rounded, color: t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tabella standardizzata: confronta marker, chiusura settore e distribuzione S/D/T.',
                    style: tt.bodySmall?.copyWith(color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _TinyChip extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;

  const _TinyChip({
    required this.label,
    required this.value,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r6,
      ),
      child: Column(
        children: [
          Text(value, style: tt.titleSmall?.copyWith(color: t.textPrimary)),
          const SizedBox(height: 1),
          Text(label, style: tt.labelSmall?.copyWith(color: t.textMuted)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final AppTokens t;
  final Widget? action;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.t,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: t.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

String _num(double value) {
  if (value.isNaN || value.isInfinite) return '0.0';
  return value.toStringAsFixed(1);
}
