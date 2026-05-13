import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../cricket_dart_extractor.dart';
import '../../shared/stats_filter.dart';
import '../widgets/match_session_stats.dart';
import '../widgets/session_picker_screen.dart';
import '../widgets/stats_filter_bar.dart';

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
      _allMatches = all.where((m) => m.mode == 'cricket').toList();
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = CricketStatsController();
    _controller.loadMatches();
  }

  @override
  void dispose() {
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
        title: Text('Cricket', style: TextStyle(color: t.textPrimary)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CricketStatsSectionHeader(
            title: 'WIN VS LOSE',
            subtitle: 'Confronto tra leg vinti e leg persi su marker e round medi',
            onInfo: () => _openInfo(context),
            onReset: () {},
            t: t,
          ),
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
                    style: t.bodySmall(t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.overlay,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: t.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Come leggere la sezione',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Questa sezione confronta i leg vinti e persi: quanti ne hai giocati, quanti marker produci mediamente e quanti round servono.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text('CONSIGLI', style: t.labelCaps(t.textMuted)),
                const SizedBox(height: 8),
                _CricketAdviceRow(
                  t: t,
                  text: 'Se AVG marker persi è vicino ai vinti, perdi leg combattuti.',
                ),
                _CricketAdviceRow(
                  t: t,
                  text: 'Se AVG round persi è alto, chiudi o marchi troppo lentamente.',
                ),
                _CricketAdviceRow(
                  t: t,
                  text: 'Usa questo confronto per capire se il problema è precisione o ritmo.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CricketStatsSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onInfo;
  final VoidCallback onReset;
  final AppTokens t;

  const _CricketStatsSectionHeader({
    required this.title,
    required this.subtitle,
    required this.onInfo,
    required this.onReset,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.16),
              borderRadius: AppTokens.r12,
              border: Border.all(color: t.accent.withOpacity(0.38)),
            ),
            child: Icon(Icons.show_chart_rounded, color: t.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Info',
            onPressed: onInfo,
            icon: Icon(Icons.info_outline_rounded, color: t.textSecondary),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall(t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CricketAdviceRow extends StatelessWidget {
  final AppTokens t;
  final String text;

  const _CricketAdviceRow({
    required this.t,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: t.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppTokens t;

  const _ImpactMetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: AppTokens.r10,
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
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
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? (isHeader ? t.textSecondary : t.textPrimary),
          fontSize: isHeader ? 9 : 11,
          fontWeight: isHeader || isStrong ? FontWeight.w900 : FontWeight.w700,
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

class _TargetRow extends StatelessWidget {
  final _TargetSummary summary;
  final AppTokens t;

  const _TargetRow({
    required this.summary,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              summary.label,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TinyChip(label: 'D', value: '${summary.darts}', t: t),
                _TinyChip(label: 'M', value: '${summary.marks}', t: t),
                _TinyChip(label: 'MU', value: '${summary.effectiveMarks}', t: t),
                _TinyChip(label: 'P', value: '${summary.points}', t: t),
                _TinyChip(label: 'Close', value: summary.closedLegs == 0 ? '-' : _num(summary.avgDartsToClose), t: t),
                _TinyChip(label: 'Avg', value: summary.rawCloseAverage == 0 ? '-' : _num(summary.rawCloseAverage), t: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final LocalMatchRecord match;
  final VoidCallback? onTap;
  final AppTokens t;

  const _MatchRow({
    required this.match,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTokens.r8,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(match.startTime), style: _bodyBoldStyle(t)),
                  const SizedBox(height: 2),
                  Text('Vincitore: ${match.winnerName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _smallStyle(t.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textMuted),
          ],
        ),
      ),
    );
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CricketStatsSectionHeader(
            title: title.toUpperCase(),
            subtitle: 'Tabella rendimento settori Cricket',
            onInfo: () => _openInfo(context),
            onReset: () {},
            t: t,
          ),
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
                    style: t.bodySmall(t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.overlay,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: t.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Come leggere la tabella',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Ogni riga rappresenta un settore Cricket. AVG misura i marker medi, Close misura le freccette medie per chiudere il settore, S/D/T mostrano la distribuzione dei moltiplicatori.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text('CONSIGLI', style: t.labelCaps(t.textMuted)),
                const SizedBox(height: 8),
                _CricketAdviceRow(
                  t: t,
                  text: 'AVG basso indica poca produzione marker su quel settore.',
                ),
                _CricketAdviceRow(
                  t: t,
                  text: 'Close alto indica che impieghi troppe freccette per chiudere.',
                ),
                _CricketAdviceRow(
                  t: t,
                  text: 'Confronta vinti e persi per capire quali settori decidono il leg.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final AppTokens t;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.t,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r8,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? t.textPrimary)),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _smallStyle(t.textMuted)),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final AppTokens t;

  const _BigStat({
    required this.label,
    required this.value,
    required this.hint,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, height: 1, fontWeight: FontWeight.w900, color: t.textPrimary)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.textSecondary)),
          const SizedBox(height: 2),
          Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: _smallStyle(t.textMuted)),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final AppTokens t;

  const _MiniLine({
    required this.label,
    required this.value,
    required this.t,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary, fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(fontSize: 13, color: color ?? t.textPrimary, fontWeight: FontWeight.w900)),
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
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r6,
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 12, color: t.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 8, color: t.textMuted, fontWeight: FontWeight.w700)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 12)),
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

TextStyle _titleStyle(AppTokens t) {
  return TextStyle(
    color: t.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );
}

TextStyle _sectionTitleStyle(AppTokens t) {
  return TextStyle(
    color: t.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
}

TextStyle _bodyBoldStyle(AppTokens t) {
  return TextStyle(
    color: t.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );
}

TextStyle _smallStyle(Color color) {
  return TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
}

String _num(double value) {
  if (value.isNaN || value.isInfinite) return '0.0';
  return value.toStringAsFixed(1);
}

String _pct(double value) {
  if (value.isNaN || value.isInfinite) return '0%';
  return '${value.toStringAsFixed(1)}%';
}