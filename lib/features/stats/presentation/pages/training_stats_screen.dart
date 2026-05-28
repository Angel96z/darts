/// File: training_stats_screen.dart - Stable VM based screen.
/// Carica i dati una volta, costruisce un ViewModel immutabile e ridisegna solo dati già pronti.

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide OverlayState;
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../../ai_coach/domain/ai_coach_models.dart';
import '../../../ai_coach/presentation/widgets/ai_coach_card.dart';
import '../../../game/domain/entities/dart_models.dart';
import '../../../game/domain/entities/training_mode.dart';
import '../../../game/presentation/widgets/dartboard_widget.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../../domain/entities/training_stats.dart';
import '../../shared/stats_filter.dart';
import '../widgets/session_picker_screen.dart';
import '../widgets/stats_filter_bar.dart';
import '../widgets/target_sector_selector.dart';
import '../widgets/unified_stats_chart.dart';
import 'training_charts.dart';
import 'training_screen.dart';

enum StatsMode { period, session }

enum StatsViewType {
  heatmap,
  accuracy,
  precision,
  bias,
  directionalBias,
}

class StatsFilter {
  final int? dartIndex;

  const StatsFilter({this.dartIndex});
}

class TrainingStatsScreen extends StatefulWidget {
  final String title;
  final TrainingMode mode;
  final String? initialSessionId;
  final String? initialTarget;
  final bool showAppBar;

  const TrainingStatsScreen({
    super.key,
    required this.title,
    required this.mode,
    this.initialSessionId,
    this.initialTarget,
    this.showAppBar = false,
  });

  @override
  State<TrainingStatsScreen> createState() => _TrainingStatsScreenState();
}

class _TrainingStatsScreenState extends State<TrainingStatsScreen> {
  late String _target;
  late DateTimeRange _range;
  late Future<_TrainingStatsBaseVm> _future;

  StatsMode _mode = StatsMode.period;
  StatsViewType _view = StatsViewType.heatmap;
  StatsFilter _filter = const StatsFilter();
  TrainingSessionStats? _session;
  bool _boardGestureActive = false;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget ?? 'T20';

    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    _future = _loadBaseVm();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _session = null;
      _mode = StatsMode.period;
      _future = _loadBaseVm();
    });
  }

  Future<_TrainingStatsBaseVm> _loadBaseVm() async {
    final localRecords = await LocalTrainingSyncService.instance.getAllRecords();

    final throwRecords = <_CachedThrowRecord>[];
    final sessionsById = <String, TrainingSessionStats>{};

    for (final record in localRecords.where((record) => record.isVisible)) {
      final id = record.remoteId ?? record.localId;
      sessionsById[id] = TrainingSessionStats.fromRecord(record);

      for (final dart in record.throwsList) {
        throwRecords.add(
          _CachedThrowRecord(
            trainingId: id,
            trainingTarget: record.target,
            dartThrow: dart,
          ),
        );
      }
    }

    final sessions = sessionsById.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    TrainingSessionStats? initialSession;
    if (widget.initialSessionId != null) {
      for (final session in sessions) {
        if (session.id == widget.initialSessionId) {
          initialSession = session;
          break;
        }
      }
    }
    final resolvedInitialSession = initialSession;

    if (resolvedInitialSession != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _mode = StatsMode.session;
          _session = resolvedInitialSession;
          _target = resolvedInitialSession.target;
        });
      });
    }

    return _TrainingStatsBaseVm(
      sessions: sessions,
      throwRecords: throwRecords,
    );
  }


  _TrainingStatsVisibleVm _buildVisibleVm(_TrainingStatsBaseVm base) {
    final targetSessions = base.sessions
        .where((session) => session.target == _target)
        .toList(growable: false);

    final periodSessions = targetSessions.where((session) {
      return _isInsideRange(session.startTime, _range);
    }).toList(growable: false);

    Iterable<_CachedThrowRecord> records = base.throwRecords.where(
          (record) => record.trainingTarget == _target,
    );

    if (_mode == StatsMode.session && _session != null) {
      records = records.where((record) => record.trainingId == _session!.id);
    } else {
      records = records.where((record) {
        return _isInsideRange(record.dartThrow.timestamp, _range);
      });
    }

    var throws = records.map((record) => record.dartThrow).toList();
    throws.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final dartIndex = _filter.dartIndex;
    if (dartIndex != null) {
      throws = throws.where((dart) => dart.dartInTurn == dartIndex).toList();
    }

    return _TrainingStatsVisibleVm(
      target: _target,
      mode: _mode,
      range: _range,
      selectedSession: _session,
      allTargetSessions: targetSessions,
      periodSessions: periodSessions,
      throws: throws,
      filter: _filter,
      view: _view,
    );
  }

  bool _isInsideRange(DateTime date, DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    return !date.isBefore(start) && !date.isAfter(end);
  }

  Future<void> _handleModeTap() async {
    final selected = await showStatsModeDialog(context);
    if (selected == null) return;

    if (selected == StatsFilterMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _range,
      );
      if (range == null) return;

      setState(() {
        _mode = StatsMode.period;
        _range = range;
        _session = null;
      });
      return;
    }

    _openSessionPicker();
  }

  Future<void> _handleSelectorTap() async {
    if (_mode == StatsMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _range,
      );
      if (range == null) return;

      setState(() {
        _range = range;
        _session = null;
      });
      return;
    }

    _openSessionPicker();
  }

  void _openSessionPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionPickerScreen<TrainingSessionStats>(
          type: SessionType.training,
          filterBy: _target,
          highlightedId: _session?.id ?? widget.initialSessionId,
          allowDelete: true,
          onSelect: (session) {
            setState(() {
              _mode = StatsMode.session;
              _session = session;
              _target = session.target;
            });
          },
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _future = _loadBaseVm();
      });
    });
  }

  void _selectTarget(String target) {
    if (_target == target) return;
    setState(() {
      _target = target;
      _mode = StatsMode.period;
      _session = null;
    });
  }

  void _selectView(StatsViewType view) {
    if (_view == view) return;
    setState(() => _view = view);
    _pageController.jumpToPage(view.index);
  }

  void _selectDartFilter(int? dartIndex) {
    if (_filter.dartIndex == dartIndex) return;
    setState(() => _filter = StatsFilter(dartIndex: dartIndex));
  }

  void _openTrainingForTarget(String target) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingScreen(
          title: 'ROSES Throws',
          mode: widget.mode,
          initialTarget: target,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.showAppBar
          ? AppBar(
        title: Text(
          'Statistiche - ${widget.title}',
          style: tt.titleMedium?.copyWith(color: t.textPrimary),
        ),
        backgroundColor: t.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: t.textPrimary),
            onPressed: _refresh,
          ),
        ],
      )
          : null,
      body: FutureBuilder<_TrainingStatsBaseVm>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _TrainingStatsErrorView(
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final baseVm = snapshot.data;
          if (baseVm == null) {
            return _TrainingStatsErrorView(
              error: 'Dati statistiche non disponibili',
              onRetry: _refresh,
            );
          }

          final vm = _buildVisibleVm(baseVm);
          return _TrainingStatsLoadedView(
            vm: vm,
            pageController: _pageController,
            boardGestureActive: _boardGestureActive,
            onBoardGestureChanged: (value) {
              if (_boardGestureActive == value) return;
              setState(() => _boardGestureActive = value);
            },
            onModeTap: _handleModeTap,
            onSelectorTap: _handleSelectorTap,
            onTargetSelected: _selectTarget,
            onViewSelected: _selectView,
            onDartFilterSelected: _selectDartFilter,
            onTrainTarget: _openTrainingForTarget,
          );
        },
      ),
    );
  }
}

class _TrainingStatsLoadedView extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;
  final PageController pageController;
  final bool boardGestureActive;
  final ValueChanged<bool> onBoardGestureChanged;
  final VoidCallback onModeTap;
  final VoidCallback onSelectorTap;
  final ValueChanged<String> onTargetSelected;
  final ValueChanged<StatsViewType> onViewSelected;
  final ValueChanged<int?> onDartFilterSelected;
  final ValueChanged<String> onTrainTarget;

  const _TrainingStatsLoadedView({
    required this.vm,
    required this.pageController,
    required this.boardGestureActive,
    required this.onBoardGestureChanged,
    required this.onModeTap,
    required this.onSelectorTap,
    required this.onTargetSelected,
    required this.onViewSelected,
    required this.onDartFilterSelected,
    required this.onTrainTarget,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    final filterState = StatsFilterState(
      mode: vm.mode == StatsMode.period
          ? StatsFilterMode.period
          : StatsFilterMode.session,
      periodRange: vm.range,
      selectedSessionId: vm.selectedSession?.id,
      selectedSessionLabel: vm.selectedSession == null
          ? null
          : DateFormat('dd/MM/yyyy HH:mm').format(vm.selectedSession!.startTime),
    );

    return Column(
      children: [
        StatsFilterBar(
          state: filterState,
          onModeTap: onModeTap,
          onSelectorTap: onSelectorTap,
          leadingChild: TargetSectorSelector(
            currentTarget: vm.target,
            onSelected: onTargetSelected,
          ),
        ),
        Divider(color: t.divider, height: 1),
        Expanded(
          child: RepaintBoundary(
            child: vm.throws.isEmpty
                ? _TrainingStatsEmptyState(
              target: vm.target,
              t: t,
              onTrain: () => onTrainTarget(vm.target),
            )
                : Stack(
              children: [
                Positioned.fill(
                  child: isDesktop
                      ? _TrainingStatsDesktopLayout(
                    vm: vm,
                    pageController: pageController,
                    onViewSelected: onViewSelected,
                    onDartFilterSelected: onDartFilterSelected,
                    topSpacer: 0,
                  )
                      : _TrainingStatsMobileLayout(
                    vm: vm,
                    pageController: pageController,
                    boardGestureActive: boardGestureActive,
                    onBoardGestureChanged: onBoardGestureChanged,
                    onViewSelected: onViewSelected,
                    topSpacer: 62,
                  ),
                ),
                if (!isDesktop)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _FloatingDartFilterSelector(
                      selected: vm.filter.dartIndex,
                      onSelected: onDartFilterSelected,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}



class _TrainingStatsEmptyState extends StatelessWidget {
  final String target;
  final AppTokens t;
  final VoidCallback onTrain;

  const _TrainingStatsEmptyState({
    required this.target,
    required this.t,
    required this.onTrain,
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
            Icon(
              Icons.sports_score_rounded,
              color: t.textMuted,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              'Nessun dato training trovato',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Non ci sono tiri per $target con il filtro selezionato.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: t.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onTrain,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: Text('Allenati su $target'),
            ),
          ],
        ),
      ),
    );
  }
}





class _TrainingStatsDesktopLayout extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;
  final PageController pageController;
  final ValueChanged<StatsViewType> onViewSelected;
  final ValueChanged<int?> onDartFilterSelected;
  final double topSpacer;

  const _TrainingStatsDesktopLayout({
    required this.vm,
    required this.pageController,
    required this.onViewSelected,
    required this.onDartFilterSelected,
    required this.topSpacer,
  });

  @override
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.65,
          child: Column(
            children: [
              SizedBox(height: topSpacer),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _TrainingBoardPanel(
                      vm: vm,
                      pageController: pageController,
                      onViewSelected: onViewSelected,
                      showDartFilterInside: true,
                      onDartFilterSelected: onDartFilterSelected,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            physics: const BouncingScrollPhysics(),
            child: RepaintBoundary(
              child: _TrainingStatsCharts(vm: vm),
            ),
          ),
        ),
      ],
    );
  }}

class _TrainingStatsMobileLayout extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;
  final PageController pageController;
  final bool boardGestureActive;
  final ValueChanged<bool> onBoardGestureChanged;
  final ValueChanged<StatsViewType> onViewSelected;
  final double topSpacer;

  const _TrainingStatsMobileLayout({
    required this.vm,
    required this.pageController,
    required this.boardGestureActive,
    required this.onBoardGestureChanged,
    required this.onViewSelected,
    required this.topSpacer,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: boardGestureActive
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          SizedBox(height: topSpacer),
          SizedBox(
            height: 420,
            child: _TrainingBoardPanel(
              vm: vm,
              pageController: pageController,
              onViewSelected: onViewSelected,
              onBoardGestureChanged: onBoardGestureChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: RepaintBoundary(
              child: _TrainingStatsCharts(vm: vm),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingBoardPanel extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;
  final PageController pageController;
  final ValueChanged<StatsViewType> onViewSelected;
  final ValueChanged<bool>? onBoardGestureChanged;
  final bool showDartFilterInside;
  final ValueChanged<int?>? onDartFilterSelected;

  const _TrainingBoardPanel({
    required this.vm,
    required this.pageController,
    required this.onViewSelected,
    this.onBoardGestureChanged,
    this.showDartFilterInside = false,
    this.onDartFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: onBoardGestureChanged == null
                      ? null
                      : (_) => onBoardGestureChanged!(true),
                  onPointerUp: onBoardGestureChanged == null
                      ? null
                      : (_) => onBoardGestureChanged!(false),
                  onPointerCancel: onBoardGestureChanged == null
                      ? null
                      : (_) => onBoardGestureChanged!(false),
                  child: PageView(
                    controller: pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _BoardView(
                        throws: vm.throws,
                        target: vm.target,
                        overlays: const {DartboardOverlayType.heatmap},
                      ),
                      _BoardView(
                        throws: vm.throws,
                        target: vm.target,
                        overlays: const {
                          DartboardOverlayType.targetZone,
                          DartboardOverlayType.targetCenter,
                          DartboardOverlayType.radialError,
                        },
                      ),
                      _BoardView(
                        throws: vm.throws,
                        target: vm.target,
                        overlays: const {DartboardOverlayType.dispersion},
                      ),
                      _BoardView(
                        throws: vm.throws,
                        target: vm.target,
                        overlays: const {
                          DartboardOverlayType.targetCenter,
                          DartboardOverlayType.bias,
                        },
                      ),
                      _BoardView(
                        throws: vm.throws,
                        target: vm.target,
                        overlays: const {
                          DartboardOverlayType.targetCenter,
                          DartboardOverlayType.directionalBias,
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _TrainingInsight(vm: vm),
            ],
          ),
        ),
        Positioned(
          left: 8,
          top: 40,
          child: _VerticalSelector<StatsViewType>(
            selected: vm.view,
            entries: const [
              _SelectorEntry('H', StatsViewType.heatmap),
              _SelectorEntry('A', StatsViewType.accuracy),
              _SelectorEntry('P', StatsViewType.precision),
              _SelectorEntry('B', StatsViewType.bias),
              _SelectorEntry('DB', StatsViewType.directionalBias),
            ],
            onSelected: onViewSelected,
          ),
        ),
        if (showDartFilterInside && onDartFilterSelected != null)
          Positioned(
            top: 8,
            right: 8,
            child: _FloatingDartFilterSelector(
              selected: vm.filter.dartIndex,
              onSelected: onDartFilterSelected!,
            ),
          ),
      ],
    );
  }
}

class _FloatingDartFilterSelector extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onSelected;

  const _FloatingDartFilterSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface.withOpacity(0.94),
          borderRadius: AppTokens.r16,
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SelectorButton<int?>(
                label: 'T',
                value: null,
                selected: selected == null,
                tokens: t,
                onSelected: onSelected,
              ),
              const SizedBox(width: 6),
              _SelectorButton<int?>(
                label: '1',
                value: 1,
                selected: selected == 1,
                tokens: t,
                onSelected: onSelected,
              ),
              const SizedBox(width: 6),
              _SelectorButton<int?>(
                label: '2',
                value: 2,
                selected: selected == 2,
                tokens: t,
                onSelected: onSelected,
              ),
              const SizedBox(width: 6),
              _SelectorButton<int?>(
                label: '3',
                value: 3,
                selected: selected == 3,
                tokens: t,
                onSelected: onSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  final List<DartThrow> throws;
  final String target;
  final Set<DartboardOverlayType> overlays;

  const _BoardView({
    required this.throws,
    required this.target,
    required this.overlays,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DartboardWidget(
        throws: throws,
        target: target,
        overlays: overlays,
      ),
    );
  }
}

class _TrainingStatsCharts extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;

  const _TrainingStatsCharts({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final throws = vm.throws;

    return Column(
      children: [
        if (vm.filter.dartIndex == null) ...[
          AiCoachCard(input: vm.aiCoachInput),
          const SizedBox(height: 12),
        ],
        _ClusterTitle('PRECISIONE', t),
        _UnifiedPrecisionTrendChart(throws: throws),
        TrainingCharts.distanceAnalysis(throws, vm.target),
        TrainingCharts.directionalBias(throws, vm.target),
        _ClusterTitle('PERFORMANCE', t),
        TrainingCharts.hitTrend(throws, vm.target),
        TrainingCharts.dartBreakdown(throws, vm.target),
        TrainingCharts.streak(throws, vm.target),
        _ClusterTitle('CONTROLLO', t),
        TrainingCharts.consistencyTrend(throws, vm.target),
        TrainingCharts.relationalPerformance(
          throws,
          vm.target,
          showSessionTime: vm.mode == StatsMode.period,
        ),
        _ClusterTitle('RIEPILOGO', t),
        TrainingCharts.performanceScore(throws, vm.target),
        TrainingCharts.quadrantDistance(throws, vm.target),
        TrainingCharts.ringDistribution(throws, vm.target),
        _ClusterTitle('SESSIONI', t),
        TrainingCharts.topSessions(vm.sessionPoints),
        TrainingCharts.worstSessions(vm.sessionPoints),
      ],
    );
  }
}

class _UnifiedPrecisionTrendChart extends StatelessWidget {
  final List<DartThrow> throws;

  const _UnifiedPrecisionTrendChart({required this.throws});

  @override
  Widget build(BuildContext context) {
    final points = <UnifiedStatsPoint>[];

    for (var i = 0; i < throws.length; i++) {
      final dart = throws[i];
      points.add(
        UnifiedStatsPoint(
          x: i + 1.0,
          y: dart.distanceMm,
          label: 'Tiro ${i + 1}',
          detail: 'Hit ${dart.sector.isEmpty ? '—' : dart.sector}',
        ),
      );
    }

    return UnifiedStatsChart(
      title: 'Precisione',
      subtitle: 'Distanza freccette dal target.',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: 'dart',
      yAxisLabel: 'mm',
      invertYAxis: true,
      minYValue: -5,
      minYRange: 200,
      minXRange: 15,
      infoTitle: 'Come leggere il grafico della precisione',
      infoText:
      'Il grafico mostra la distanza in millimetri di ogni freccetta dal target di allenamento. '
          'Più il valore è basso, più il tiro è vicino al bersaglio. '
          'Non misura il punteggio: misura la qualità tecnica della mira e la capacità di ripetere un lancio preciso nel tempo.',
      advice: const [
        'Valori bassi e stabili: la precisione è solida; mantieni routine, ritmo e setup.',
        'Picchi improvvisi: possibile perdita momentanea di routine, rilascio o focus; inserisci un reset prima della freccetta successiva.',
        'Valori che aumentano nel finale: possibile fatica tecnica o mentale; riduci durata, ritmo o intensità della sessione.',
      ],
    );
  }
}

class _TrainingInsight extends StatelessWidget {
  final _TrainingStatsVisibleVm vm;

  const _TrainingInsight({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final throws = vm.throws;

    if (throws.isEmpty) {
      return _InsightBox(
        title: 'Nessun dato',
        text: 'Non ci sono tiri per il filtro selezionato.',
        tokens: t,
      );
    }

    final stats = TrainingStats(throws);
    final hit = stats.targetHits(vm.target);
    final percent = throws.isEmpty ? 0 : (hit / throws.length) * 100;

    switch (vm.view) {
      case StatsViewType.heatmap:
        return _InsightBox(
          title: 'Distribuzione colpi',
          text: 'Mostra dove colpisci più spesso. Cerca concentrazione sul target.',
          tokens: t,
        );
      case StatsViewType.accuracy:
        return _InsightBox(
          title: 'Precisione sul target',
          text: 'Errore medio: ${stats.averageDistanceMm.toStringAsFixed(1)} mm\n'
              '${percent.toStringAsFixed(0)}% hit\n'
              '${percent > 60 ? 'Buona precisione' : 'Riduci distanza dal target'}',
          tokens: t,
        );
      case StatsViewType.precision:
        return _InsightBox(
          title: 'Consistenza',
          text: 'Valuta quanto i tiri sono raggruppati.\n'
              'Ellisse stretta = alta precisione.\n'
              'Ellisse larga = gesto instabile.',
          tokens: t,
        );
      case StatsViewType.bias:
        return _InsightBox(
          title: 'Errore direzionale',
          text: 'Il punto rosso mostra dove tendi a tirare.\n'
              'Correggi nella direzione opposta.',
          tokens: t,
        );
      case StatsViewType.directionalBias:
        return _InsightBox(
          title: 'Bias direzionale (bande)',
          text: 'Le bande mostrano media e dispersione orizzontale/verticale.\n'
              'Banda più larga = più variabilità su quell\'asse.',
          tokens: t,
        );
    }
  }
}

class _InsightBox extends StatelessWidget {
  final String title;
  final String text;
  final AppTokens tokens;

  const _InsightBox({
    required this.title,
    required this.text,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: tt.bodySmall?.copyWith(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ClusterTitle extends StatelessWidget {
  final String title;
  final AppTokens tokens;

  const _ClusterTitle(this.title, this.tokens);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.accent.withOpacity(0.08),
        borderRadius: AppTokens.r8,
      ),
      child: Text(
        title,
        style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
      ),
    );
  }
}

class _VerticalSelector<T> extends StatelessWidget {
  final T selected;
  final List<_SelectorEntry<T>> entries;
  final ValueChanged<T> onSelected;

  const _VerticalSelector({
    required this.selected,
    required this.entries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Column(
      children: [
        for (final entry in entries) ...[
          _SelectorButton<T>(
            label: entry.label,
            value: entry.value,
            selected: selected == entry.value,
            tokens: t,
            onSelected: onSelected,
          ),
          if (entry != entries.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SelectorButton<T> extends StatelessWidget {
  final String label;
  final T value;
  final bool selected;
  final AppTokens tokens;
  final ValueChanged<T> onSelected;

  const _SelectorButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.tokens,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: AppTokens.r10,
          color: selected ? tokens.accent : tokens.surfaceHigh,
          border: Border.all(color: tokens.border),
        ),
        child: Text(
          label,
          style: tt.titleSmall?.copyWith(
            color: selected ? tokens.accentFg : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SelectorEntry<T> {
  final String label;
  final T value;

  const _SelectorEntry(this.label, this.value);
}

class _TrainingStatsErrorView extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _TrainingStatsErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Errore caricamento statistiche',
              style: tt.titleMedium?.copyWith(color: t.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Errore sconosciuto',
              style: tt.bodySmall?.copyWith(color: t.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: t.accent),
              label: Text(
                'Riprova',
                style: tt.titleSmall?.copyWith(color: t.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingStatsBaseVm {
  final List<TrainingSessionStats> sessions;
  final List<_CachedThrowRecord> throwRecords;

  const _TrainingStatsBaseVm({
    required this.sessions,
    required this.throwRecords,
  });
}

class _TrainingStatsVisibleVm {
  final String target;
  final StatsMode mode;
  final DateTimeRange range;
  final TrainingSessionStats? selectedSession;
  final List<TrainingSessionStats> allTargetSessions;
  final List<TrainingSessionStats> periodSessions;
  final List<DartThrow> throws;
  final StatsFilter filter;
  final StatsViewType view;

  const _TrainingStatsVisibleVm({
    required this.target,
    required this.mode,
    required this.range,
    required this.selectedSession,
    required this.allTargetSessions,
    required this.periodSessions,
    required this.throws,
    required this.filter,
    required this.view,
  });

  List<SessionPerformancePoint> get sessionPoints {
    return periodSessions.map((session) {
      return SessionPerformancePoint(
        id: session.id,
        performance: session.hitPercent.toDouble(),
        sessionDate: session.startTime,
        focus: session.focus,
        stress: session.stress,
        energia: session.energia,
        fiducia: session.fiducia,
        distrazioni: session.distrazioni,
        commento: session.commento,
      );
    }).toList(growable: false);
  }

  AiCoachInput get aiCoachInput {
    final stats = TrainingStats(throws);
    final total = throws.length;
    final hits = stats.targetHits(target);
    final hitPercent = total == 0 ? 0.0 : (hits / total) * 100.0;

    final dart1 = _hitPercentForDart(1);
    final dart2 = _hitPercentForDart(2);
    final dart3 = _hitPercentForDart(3);

    final completeTurns = _completeTurns;
    final avgHitsPerTurn = completeTurns.isEmpty
        ? 0.0
        : completeTurns
        .map((turn) => turn.where((dart) => dart.sector == target).length)
        .reduce((a, b) => a + b) /
        completeTurns.length;

    final zeroHitTurns = _turnHitPercent(0);
    final oneHitTurns = _turnHitPercent(1);
    final twoHitTurns = _turnHitPercent(2);
    final threeHitTurns = _turnHitPercent(3);

    final avgDistance = stats.averageDistanceMm;
    final consistency = _turnConsistencyScore;
    final biasX = _averageBiasXmm;
    final biasY = _averageBiasYmm;
    final bestStreak = stats.bestStreak(target).toDouble();

    final avgSessionPerformance = periodSessions.isEmpty
        ? hitPercent
        : periodSessions
        .map((session) => session.hitPercent.toDouble())
        .reduce((a, b) => a + b) /
        periodSessions.length;

    final avgFocus = _averageSessionValue((session) => session.focus);
    final avgStress = _averageSessionValue((session) => session.stress);
    final avgEnergy = _averageSessionValue((session) => session.energia);
    final avgConfidence = _averageSessionValue((session) => session.fiducia);
    final avgDistractions = _averageSessionValue((session) => session.distrazioni);

    final fingerprint = [
      'training-global',
      target,
      mode.name,
      range.start.millisecondsSinceEpoch,
      range.end.millisecondsSinceEpoch,
      selectedSession?.id ?? '-',
      filter.dartIndex?.toString() ?? 'T',
      total,
      hits,
      hitPercent.toStringAsFixed(1),
      avgDistance.toStringAsFixed(1),
      dart1.toStringAsFixed(1),
      dart2.toStringAsFixed(1),
      dart3.toStringAsFixed(1),
      avgHitsPerTurn.toStringAsFixed(2),
      consistency.toStringAsFixed(1),
      bestStreak.toStringAsFixed(0),
      avgSessionPerformance.toStringAsFixed(1),
    ].join('|');

    return AiCoachInput(
      mode: AiCoachMode.training,
      title: 'Analisi globale training $target',
      subtitle: '$total tiri · ${completeTurns.length} turni completi · ${periodSessions.length} sessioni',
      fingerprint: fingerprint,
      updatedAt: DateTime.now(),
      sessionSnapshots: _aiSessionSnapshots,
      signals: [
        AiCoachSignal(label: 'Hit target', value: hitPercent, unit: '%', higherIsBetter: true, category: 'precisione generale'),
        AiCoachSignal(label: 'Distanza media', value: avgDistance, unit: ' mm', higherIsBetter: false, category: 'mira'),
        AiCoachSignal(label: 'Dart 1 hit', value: dart1, unit: '%', higherIsBetter: true, category: 'prima freccia'),
        AiCoachSignal(label: 'Dart 2 hit', value: dart2, unit: '%', higherIsBetter: true, category: 'seconda freccia'),
        AiCoachSignal(label: 'Dart 3 hit', value: dart3, unit: '%', higherIsBetter: true, category: 'terza freccia'),
        AiCoachSignal(label: 'Hit medie per turno', value: avgHitsPerTurn * 33.333, unit: '/3', higherIsBetter: true, category: 'qualità turno'),
        AiCoachSignal(label: 'Turni 0 hit', value: zeroHitTurns, unit: '%', higherIsBetter: false, category: 'turni vuoti'),
        AiCoachSignal(label: 'Turni 1 hit', value: oneHitTurns, unit: '%', higherIsBetter: true, category: 'base minima'),
        AiCoachSignal(label: 'Turni 2 hit', value: twoHitTurns, unit: '%', higherIsBetter: true, category: 'solidità'),
        AiCoachSignal(label: 'Turni 3 hit', value: threeHitTurns, unit: '%', higherIsBetter: true, category: 'eccellenza'),
        AiCoachSignal(label: 'Consistenza turno', value: consistency, unit: '%', higherIsBetter: true, category: 'controllo'),
        AiCoachSignal(label: 'Bias orizzontale', value: biasX.abs(), unit: ' mm', higherIsBetter: false, category: biasX >= 0 ? 'tendenza destra' : 'tendenza sinistra'),
        AiCoachSignal(label: 'Bias verticale', value: biasY.abs(), unit: ' mm', higherIsBetter: false, category: biasY >= 0 ? 'tendenza basso' : 'tendenza alto'),
        AiCoachSignal(label: 'Miglior serie', value: bestStreak, unit: ' hit', higherIsBetter: true, category: 'tenuta mentale'),
        AiCoachSignal(label: 'Performance sessioni', value: avgSessionPerformance, unit: '%', higherIsBetter: true, category: 'andamento periodo'),
        if (avgFocus != null) AiCoachSignal(label: 'Focus medio', value: avgFocus, unit: '/10', higherIsBetter: true, category: 'stato mentale'),
        if (avgStress != null) AiCoachSignal(label: 'Stress medio', value: avgStress, unit: '/10', higherIsBetter: false, category: 'stato mentale'),
        if (avgEnergy != null) AiCoachSignal(label: 'Energia media', value: avgEnergy, unit: '/10', higherIsBetter: true, category: 'stato fisico'),
        if (avgConfidence != null) AiCoachSignal(label: 'Fiducia media', value: avgConfidence, unit: '/10', higherIsBetter: true, category: 'stato mentale'),
        if (avgDistractions != null) AiCoachSignal(label: 'Distrazioni medie', value: avgDistractions, unit: '/10', higherIsBetter: false, category: 'stato mentale'),
      ],
    );
  }

  List<List<DartThrow>> get _completeTurns {
    final ordered = [...throws]
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;

        final byTurn = a.turnNumber.compareTo(b.turnNumber);
        if (byTurn != 0) return byTurn;

        return a.dartInTurn.compareTo(b.dartInTurn);
      });

    final turns = <List<DartThrow>>[];

    for (var i = 0; i + 2 < ordered.length; i += 3) {
      turns.add([
        ordered[i],
        ordered[i + 1],
        ordered[i + 2],
      ]);
    }

    return turns;
  }

  double _hitPercentForDart(int dartIndex) {
    final selected = throws.where((dart) => dart.dartInTurn == dartIndex).toList();
    if (selected.isEmpty) return 0;

    final hits = selected.where((dart) => dart.sector == target).length;
    return (hits / selected.length) * 100.0;
  }

  double _turnHitPercent(int hitCount) {
    final turns = _completeTurns;
    if (turns.isEmpty) return 0;

    final count = turns.where((turn) {
      return turn.where((dart) => dart.sector == target).length == hitCount;
    }).length;

    return (count / turns.length) * 100.0;
  }

  double get _turnConsistencyScore {
    final turns = _completeTurns;
    if (turns.isEmpty) return 0;

    final avgDistances = turns.map((turn) {
      return turn.map((dart) => dart.distanceMm).reduce((a, b) => a + b) / turn.length;
    }).toList();

    final avg = avgDistances.reduce((a, b) => a + b) / avgDistances.length;
    final avgDeviation = avgDistances
        .map((value) => (value - avg).abs())
        .reduce((a, b) => a + b) /
        avgDistances.length;

    return (100 - avgDeviation).clamp(0, 100).toDouble();
  }

  Offset get _targetCenter {
    final normalized = target.trim().toUpperCase();

    if (normalized == 'BULL' || normalized == '25' || normalized.endsWith('25')) {
      return const Offset(0.5, 0.5);
    }

    const sectors = [
      20, 1, 18, 4, 13,
      6, 10, 15, 2, 17,
      3, 19, 7, 16, 8,
      11, 14, 9, 12, 5,
    ];

    const sectorAngle = 2 * 3.141592653589793 / 20;
    const startOffset = -3.141592653589793 / 2 - sectorAngle / 2;

    final ring = normalized[0];
    final value = int.tryParse(normalized.substring(1));
    if (value == null) return const Offset(0.5, 0.5);

    final index = sectors.indexOf(value);
    if (index == -1) return const Offset(0.5, 0.5);

    final angle = startOffset + index * sectorAngle + sectorAngle / 2;

    const boardDiameterMm = 451.0;

    const bullOuter = 15.9 / boardDiameterMm;
    const tripleInner = 99 / boardDiameterMm;
    const tripleOuter = 107 / boardDiameterMm;
    const doubleInner = 162 / boardDiameterMm;
    const doubleOuter = 170 / boardDiameterMm;

    final radius = switch (ring) {
      'T' => (tripleInner + tripleOuter) / 2,
      'D' => (doubleInner + doubleOuter) / 2,
      _ => (tripleOuter + doubleInner) / 2,  // SINGOLO: zona esterna tra triplo e doppio
    };

    // NOTA: radius è già in coordinate centro→bordo (0-0.5), non moltiplicare per 0.5
    return Offset(
      0.5 + math.cos(angle) * radius,
      0.5 + math.sin(angle) * radius,
    );
  }

  double get _averageBiasXmm {
    final valid = throws.where((dart) => !dart.isPass).toList();
    if (valid.isEmpty) return 0;

    const boardMm = 451.0;
    final targetCenter = _targetCenter;
    final avgX = valid.map((dart) => dart.position.dx).reduce((a, b) => a + b) / valid.length;

    return (avgX - targetCenter.dx) * boardMm;
  }

  double get _averageBiasYmm {
    final valid = throws.where((dart) => !dart.isPass).toList();
    if (valid.isEmpty) return 0;

    const boardMm = 451.0;
    final targetCenter = _targetCenter;
    final avgY = valid.map((dart) => dart.position.dy).reduce((a, b) => a + b) / valid.length;

    return (avgY - targetCenter.dy) * boardMm;
  }

  double? _averageSessionValue(int? Function(TrainingSessionStats session) selector) {
    final values = periodSessions
        .map(selector)
        .whereType<int>()
        .map((value) => value.toDouble())
        .toList();

    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<AiCoachSessionSnapshot> get _aiSessionSnapshots {
    final validSessions = periodSessions
        .where((session) => session.totalThrows > 0)
        .toList();

    validSessions.sort((a, b) {
      final byHit = b.hitPercent.compareTo(a.hitPercent);
      if (byHit != 0) return byHit;
      return a.avgDistanceMm.compareTo(b.avgDistanceMm);
    });

    final top = validSessions.take(5).toList(growable: false);
    final worst = validSessions.reversed.take(5).toList(growable: false);

    return [
      ...top.map((session) => _toAiSessionSnapshot(session, 'top')),
      ...worst.map((session) => _toAiSessionSnapshot(session, 'worst')),
    ];
  }

  AiCoachSessionSnapshot _toAiSessionSnapshot(
      TrainingSessionStats session,
      String group,
      ) {
    return AiCoachSessionSnapshot(
      sessionId: session.id,
      label: _formatAiSessionLabel(session.startTime),
      date: session.startTime,
      target: session.target,
      group: group,
      score0to100: session.hitPercent.toDouble(),
      metrics: {
        'hitPercent': session.hitPercent.toDouble(),
        'totalThrows': session.totalThrows.toDouble(),
        'totalTurns': session.totalTurns.toDouble(),
        'hits': session.hits.toDouble(),
        'miss': session.miss.toDouble(),
        'avgDistanceMm': session.avgDistanceMm,
        'bestStreak': session.bestStreak.toDouble(),
        'durationSeconds': session.durationSeconds.toDouble(),
      },
      feedback: {
        if (session.focus != null) 'focusSu10': session.focus!.toDouble(),
        if (session.stress != null) 'stressSu10': session.stress!.toDouble(),
        if (session.energia != null) 'energiaSu10': session.energia!.toDouble(),
        if (session.fiducia != null) 'fiduciaSu10': session.fiducia!.toDouble(),
        if (session.distrazioni != null) 'distrazioniSu10': session.distrazioni!.toDouble(),
      },
    );
  }

  String _formatAiSessionLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$hour:$minute';
  }
}


class _CachedThrowRecord {
  final String trainingId;
  final String trainingTarget;
  final DartThrow dartThrow;

  const _CachedThrowRecord({
    required this.trainingId,
    required this.trainingTarget,
    required this.dartThrow,
  });
}

class TrainingSessionStats {
  final String id;
  final String target;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int totalThrows;
  final int totalTurns;
  final int hits;
  final int miss;
  final int hitPercent;
  final double avgDistanceMm;
  final int bestStreak;
  final int? focus;
  final int? stress;
  final int? energia;
  final int? fiducia;
  final int? distrazioni;
  final String? commento;
  final LocalTrainingSyncStatus? syncStatus;

  const TrainingSessionStats({
    required this.id,
    required this.target,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalThrows,
    required this.totalTurns,
    required this.hits,
    required this.miss,
    required this.hitPercent,
    required this.avgDistanceMm,
    required this.bestStreak,
    this.focus,
    this.stress,
    this.energia,
    this.fiducia,
    this.distrazioni,
    this.commento,
    this.syncStatus,
  });

  factory TrainingSessionStats.fromRecord(LocalTrainingRecord record) {
    final stats = TrainingStats(record.throwsList);
    final hits = stats.targetHits(record.target);

    return TrainingSessionStats(
      id: record.remoteId ?? record.localId,
      target: record.target,
      startTime: record.startTime,
      endTime: record.endTime,
      durationSeconds: record.endTime.difference(record.startTime).inSeconds,
      totalThrows: stats.totalThrows,
      totalTurns: stats.totalTurns,
      hits: hits,
      miss: stats.targetMiss(record.target),
      hitPercent: stats.totalThrows == 0
          ? 0
          : ((hits / stats.totalThrows) * 100).round(),
      avgDistanceMm: stats.averageDistanceMm,
      bestStreak: stats.bestStreak(record.target),
      focus: record.focus,
      stress: record.stress,
      energia: record.energia,
      fiducia: record.fiducia,
      distrazioni: record.distrazioni,
      commento: record.commento,
      syncStatus: record.syncStatus,
    );
  }
}

class PeriodStats {
  final int totalSessions;
  final int totalThrows;
  final int totalTurns;
  final int totalHits;
  final int totalMiss;
  final int hitPercent;
  final double avgDistanceMm;
  final int totalDurationSeconds;
  final int bestStreak;

  const PeriodStats({
    required this.totalSessions,
    required this.totalThrows,
    required this.totalTurns,
    required this.totalHits,
    required this.totalMiss,
    required this.hitPercent,
    required this.avgDistanceMm,
    required this.totalDurationSeconds,
    required this.bestStreak,
  });

  const PeriodStats.empty()
      : totalSessions = 0,
        totalThrows = 0,
        totalTurns = 0,
        totalHits = 0,
        totalMiss = 0,
        hitPercent = 0,
        avgDistanceMm = 0,
        totalDurationSeconds = 0,
        bestStreak = 0;
}
