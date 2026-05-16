/// File: training_stats_screen.dart - Allineato al tema ufficiale AppTokens
/// Contiene logica di presentazione (UI, widget o controller) per questa parte dell'app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide OverlayState;
import 'package:intl/intl.dart';

import '../../../game/domain/entities/dart_models.dart';
import '../../../game/domain/entities/training_mode.dart';
import '../../../game/presentation/widgets/dartboard_widget.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../../shared/stats_filter.dart';
import '../widgets/session_picker_screen.dart';
import '../widgets/stats_filter_bar.dart';
import '../widgets/unified_stats_chart.dart';
import 'training_charts.dart';
import '../../domain/entities/training_stats.dart';
import '../widgets/target_sector_selector.dart';
import '../../../../app_theme.dart';

enum StatsMode { period, session }

enum StatsViewType {
  heatmap,
  accuracy,     // target + radial error
  precision,    // dispersion
  bias,         // punto medio
  directionalBias, // bande direzionali
}

class StatsFilter {
  final int? dartIndex;
  const StatsFilter({this.dartIndex});
}

class StatsController extends ChangeNotifier {
  StatsViewType view = StatsViewType.heatmap;
  StatsFilter filter = const StatsFilter();

  void setView(StatsViewType v) {
    view = v;
    notifyListeners();
  }

  void setFilter(StatsFilter f) {
    filter = f;
    notifyListeners();
  }

  List<DartThrow> applyFilter(List<DartThrow> input) {
    if (filter.dartIndex == null) return input;
    return input.where((t) => t.dartInTurn == filter.dartIndex).toList();
  }
}

enum SessionSort {
  dateDesc,
  dateAsc,
  performanceDesc,
  performanceAsc,
  durationDesc,
  durationAsc,
}

class TrainingStatsScreen extends StatefulWidget {
  final String title;
  final TrainingMode mode;
  final String? initialSessionId;
  final String? initialTarget;
  final bool showAppBar;  // ← NUOVO PARAMETRO

  const TrainingStatsScreen({
    super.key,
    required this.title,
    required this.mode,
    this.initialSessionId,
    this.initialTarget,
    this.showAppBar = false,  // ← DEFAULT FALSE
  });

  @override
  State<TrainingStatsScreen> createState() => _TrainingStatsScreenState();
}

class _TrainingStatsScreenState extends State<TrainingStatsScreen> {
  String _target = 'T20';
  StatsMode _mode = StatsMode.period;
  DateTimeRange? _range;
  TrainingSessionStats? _session;

  final StatsController _statsController = StatsController();
  final PageController _pageController = PageController();

  List<_CachedThrowRecord> _cachedRecords = [];
  bool _loaded = false;
  bool _boardGestureActive = false;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget ?? _target;

    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    _initData();
  }

  Future<void> _initData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final localRecords = await _loadFromLocalCache();
    final remoteRecords = await _loadFromFirestore(localRecords);
    final allRecords = [...localRecords, ...remoteRecords];

    if (!mounted) return;

    TrainingSessionStats? highlighted;
    if (widget.initialSessionId != null) {
      final sessions = await _loadTrainingsForTarget();
      for (final session in sessions) {
        if (session.id == widget.initialSessionId) {
          highlighted = session;
          break;
        }
      }
    }

    setState(() {
      _cachedRecords = allRecords;
      _loaded = true;
      if (highlighted != null) {
        _mode = StatsMode.session;
        _session = highlighted;
      }
    });
  }

  Future<List<_CachedThrowRecord>> _loadFromLocalCache() async {
    final allLocal = await LocalTrainingSyncService.instance.getAllRecords();
    final records = <_CachedThrowRecord>[];

    for (final local in allLocal) {
      if (local.syncStatus != LocalTrainingSyncStatus.synced) {
        for (final t in local.throwsList) {
          records.add(_CachedThrowRecord(
            trainingId: local.remoteId ?? local.localId,
            trainingTarget: local.target,
            dartThrow: t,
          ));
        }
      }
    }

    return records;
  }

  Future<List<_CachedThrowRecord>> _loadFromFirestore(List<_CachedThrowRecord> existing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final existingIds = existing.map((e) => e.trainingId).toSet();

    final trainingsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('status', isEqualTo: 'complete')
        .get();

    final records = <_CachedThrowRecord>[];

    for (final trainingDoc in trainingsSnapshot.docs) {
      final trainingId = trainingDoc.id;

      if (existingIds.contains(trainingId)) continue;

      final trainingData = trainingDoc.data();
      final trainingTarget = (trainingData['target'] ?? '').toString();

      final throwsSnapshot = await trainingDoc.reference
          .collection('throws')
          .orderBy('timestamp')
          .get();

      for (final throwDoc in throwsSnapshot.docs) {
        final data = throwDoc.data();

        records.add(_CachedThrowRecord(
          trainingId: trainingId,
          trainingTarget: trainingTarget,
          dartThrow: DartThrow(
            timestamp: (data['timestamp'] is Timestamp)
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            dartInTurn: _asInt(data['dart']),
            position: Offset(
              _asDouble(data['boardX']),
              _asDouble(data['boardY']),
            ),
            sector: (data['sector'] ?? '').toString(),
            score: _asInt(data['score']),
            distanceMm: _asDouble(data['distanceMm']),
            playerId: (data['playerId'] ?? '').toString(),
            playerName: (data['playerName'] ?? '').toString(),
            teamId: (data['teamId'] ?? '').toString(),
            teamName: (data['teamName'] ?? '').toString(),
            roundNumber: _asInt(data['round']),
            turnNumber: _asInt(data['turn']),
            targetQuadrant: data['quadrant']?.toString(),
            isPass: data['isPass'] == true,
          ),
        ));
      }
    }

    return records;
  }


  String _buildRightLabel() {
    if (_mode == StatsMode.period) {
      if (_range == null) return 'Range';
      return '${DateFormat('dd/MM').format(_range!.start)}-${DateFormat('dd/MM').format(_range!.end)}';
    }

    if (_session == null) return 'Seleziona';
    return DateFormat('dd/MM/yyyy HH:mm').format(_session!.startTime);  // ← SOLO DATA E ORA
  }

// In training_stats_screen.dart, modifica _openSessionPicker:

  void _openSessionPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionPickerScreen<TrainingSessionStats>(
          type: SessionType.training,
          filterBy: _target,
          highlightedId: widget.initialSessionId,
          onSelect: (session) {
            setState(() {
              _mode = StatsMode.session;
              _session = session;
            });
          },
          allowDelete: true,
        ),
      ),
    );
  }

  Widget _viewBtn(String label, StatsViewType type) {
    final t = AppTokens.of(context);
    final selected = _statsController.view == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statsController.setView(type);
          _pageController.jumpToPage(type.index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: AppTokens.r8,
          color: selected ? t.accent : t.surfaceHigh,
          border: Border.all(color: t.border),
        ),
        child: Text(
          label,
          style: t.bodyBold(selected ? t.accentFg : t.textPrimary),
        ),
      ),
    );
  }

  Widget _filterBtn(String label, int? dart) {
    final t = AppTokens.of(context);
    final selected = _statsController.filter.dartIndex == dart;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statsController.setFilter(StatsFilter(dartIndex: dart));
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppTokens.r10,
            color: selected ? t.accent : t.surfaceHigh,
            border: Border.all(color: t.border),
          ),
          child: Text(
            label,
            style: t.bodyBold(selected ? t.accentFg : t.textPrimary),
          ),
        ),
      ),
    );
  }

  Future<List<TrainingSessionStats>> _loadTrainingsForTarget() async {
    final sessions = <TrainingSessionStats>[];
    final added = <String>{};

    final localRecords = await LocalTrainingSyncService.instance.getAllRecords();
    for (final local in localRecords.where((e) => e.target == _target)) {
      final localStats = TrainingStats(local.throwsList);
      final id = local.remoteId ?? local.localId;
      added.add(id);

      sessions.add(
        TrainingSessionStats(
          id: id,
          target: local.target,
          startTime: local.startTime,
          endTime: local.endTime,
          durationSeconds: local.endTime.difference(local.startTime).inSeconds,
          totalThrows: localStats.totalThrows,
          totalTurns: localStats.totalTurns,
          hits: localStats.targetHits(local.target),
          miss: localStats.targetMiss(local.target),
          hitPercent: localStats.totalThrows == 0
              ? 0
              : ((localStats.targetHits(local.target) / localStats.totalThrows) * 100).round(),
          avgDistanceMm: localStats.averageDistanceMm,
          bestStreak: localStats.bestStreak(local.target),
          focus: local.focus,
          stress: local.stress,
          energia: local.energia,
          fiducia: local.fiducia,
          distrazioni: local.distrazioni,
          commento: local.commento,
          syncStatus: local.syncStatus,
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return sessions;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('target', isEqualTo: _target)
        .where('status', isEqualTo: 'complete')
        .get();

    for (final doc in snapshot.docs) {
      if (added.contains(doc.id)) continue;
      final data = doc.data();

      final startTs = data['startTime'];
      final endTs = data['endTime'];

      if (startTs is! Timestamp) {
        continue;
      }

      final stats = (data['stats'] is Map<String, dynamic>)
          ? data['stats'] as Map<String, dynamic>
          : <String, dynamic>{};

      sessions.add(
        TrainingSessionStats(
          id: doc.id,
          target: (data['target'] ?? '').toString(),
          startTime: startTs.toDate(),
          endTime: endTs is Timestamp ? endTs.toDate() : startTs.toDate(),
          durationSeconds: _asInt(data['durationSeconds']),
          totalThrows: _asInt(data['totalThrows']),
          totalTurns: _asInt(data['totalTurns']),
          hits: _asInt(stats['hits']),
          miss: _asInt(stats['miss']),
          hitPercent: _asInt(stats['hitPercent']),
          avgDistanceMm: _asDouble(stats['avgDistanceMm']),
          bestStreak: _asInt(stats['bestStreak']),
          focus: _asNullableInt(data['focus']),
          stress: _asNullableInt(data['stress']),
          energia: _asNullableInt(data['energia']),
          fiducia: _asNullableInt(data['fiducia']),
          distrazioni: _asNullableInt(data['distrazioni']),
          commento: data['commento']?.toString(),
          syncStatus: LocalTrainingSyncStatus.synced,
        ),
      );
    }

    return sessions;
  }

  Future<List<TrainingSessionStats>> _loadSessionsForActivePeriod() async {
    final sessions = await _loadTrainingsForTarget();
    final range = _range;

    if (range == null) {
      return sessions;
    }

    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );

    return sessions.where((session) {
      final date = session.startTime;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  PeriodStats _aggregatePeriodStats(List<TrainingSessionStats> filtered) {
    if (filtered.isEmpty) {
      return const PeriodStats.empty();
    }

    int totalSessions = filtered.length;
    int totalThrows = 0;
    int totalTurns = 0;
    int totalHits = 0;
    int totalMiss = 0;
    int totalDurationSeconds = 0;
    int bestStreak = 0;
    double totalAvgDistance = 0;

    for (final session in filtered) {
      totalThrows += session.totalThrows;
      totalTurns += session.totalTurns;
      totalHits += session.hits;
      totalMiss += session.miss;
      totalDurationSeconds += session.durationSeconds;
      totalAvgDistance += session.avgDistanceMm;

      if (session.bestStreak > bestStreak) {
        bestStreak = session.bestStreak;
      }
    }

    final hitPercent = totalThrows == 0 ? 0 : ((totalHits / totalThrows) * 100).round();
    final avgDistanceMm = totalSessions == 0 ? 0.0 : (totalAvgDistance / totalSessions);

    return PeriodStats(
      totalSessions: totalSessions,
      totalThrows: totalThrows,
      totalTurns: totalTurns,
      totalHits: totalHits,
      totalMiss: totalMiss,
      hitPercent: hitPercent,
      avgDistanceMm: avgDistanceMm.toDouble(),
      totalDurationSeconds: totalDurationSeconds,
      bestStreak: bestStreak,
    );
  }

  List<DartThrow> _getFilteredThrows() {
    Iterable<_CachedThrowRecord> filtered = _cachedRecords;

    filtered = filtered.where((r) => r.trainingTarget == _target);

    if (_mode == StatsMode.period && _range != null) {
      final startDay = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final endDay = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

      filtered = filtered.where((r) {
        final t = r.dartThrow.timestamp;
        return t.isAfter(startDay.subtract(const Duration(milliseconds: 1))) &&
            t.isBefore(endDay.add(const Duration(milliseconds: 1)));
      });
    }

    if (_mode == StatsMode.session && _session != null) {
      filtered = filtered.where((r) => r.trainingId == _session!.id);
    }

    final throws = filtered.map((r) => r.dartThrow).toList();
    return _statsController.applyFilter(throws);
  }

  Widget _buildStats() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final throws = _getFilteredThrows();

    return Column(
      children: [
        Expanded(child: _buildStatsPager(throws)),
        _buildInsight(throws),
      ],
    );
  }

  Widget _statsSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _statsSectionContent(_getFilteredThrows()),
    );
  }
  Widget _buildUnifiedPrecisionTrendChart(List<DartThrow> throws) {
    final sorted = [...throws]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (sorted.isEmpty) {
      return UnifiedStatsChart(
        title: 'Precisione nel tempo',
        subtitle: 'Errore medio dal target per ogni tiro registrato.',
        points: const [],
        xAxisLabel: 'freccetta',
        yAxisLabel: 'mm',
        invertYAxis: true,
        minYValue: 0,
        infoTitle: 'Precisione nel tempo',
        infoText:
        'Questo grafico mostra la distanza in millimetri dal target lungo la sequenza dei tiri. '
            'Più la linea scende, più il tiro si avvicina al bersaglio.',
        advice: const [
          'Linea discendente: precisione in miglioramento.',
          'Linea instabile: gesto o focus non ancora costanti.',
          'Picchi verso l’alto: analizzare postura, ritmo e rilascio.',
        ],
      );
    }

    final points = <UnifiedStatsPoint>[];

    for (int i = 0; i < sorted.length; i++) {
      final dart = sorted[i];
      final mm = dart.distanceMm;
      final label = 'Tiro ${i + 1}';
      final time = DateFormat('dd/MM HH:mm').format(dart.timestamp);
      final sector = dart.sector.isEmpty ? '—' : dart.sector;

      points.add(
        UnifiedStatsPoint(
          x: i + 1.0,
          y: mm,
          label: label,
          detail: 'Data $time • Settore $sector • Distanza ${mm.toStringAsFixed(1)} mm',
        ),
      );
    }

    return UnifiedStatsChart(
      title: 'Precisione nel tempo',
      subtitle: 'Distanza dal target in mm, tiro dopo tiro.',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: 'freccetta',
      yAxisLabel: 'mm',
      invertYAxis: true,
      minYValue: 0,
      infoTitle: 'Come leggere la precisione',
      infoText:
      'L’asse X rappresenta la sequenza dei tiri filtrati. '
          'L’asse Y rappresenta la distanza dal target in millimetri. '
          'Valori più bassi indicano maggiore precisione.',
      advice: const [
        'Obiettivo: linea progressivamente più bassa.',
        'Se i picchi sono frequenti, lavora su routine e rilascio.',
        'Se la linea è piatta ma alta, il gesto è costante ma decentrato.',
        'Se la linea è bassa e stabile, la precisione è solida.',
      ],
    );
  }

  SessionPerformancePoint _toSessionPoint(TrainingSessionStats s) {
    return SessionPerformancePoint(
      id: s.id,
      performance: s.hitPercent.toDouble(),
      sessionDate: s.startTime,
      focus: s.focus,
      stress: s.stress,
      energia: s.energia,
      fiducia: s.fiducia,
      distrazioni: s.distrazioni,
      commento: s.commento,
    );
  }

  Widget _clusterTitle(String title, AppTokens t) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.08),
        borderRadius: AppTokens.r8,
      ),
      child: Text(
        title,
        style: t.bodyBold(t.textPrimary),
      ),
    );
  }

  Widget _statBox(String title) {
    final t = AppTokens.of(context);

    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.bodyBold(t.textPrimary)),
          const SizedBox(height: 8),
          const Expanded(
            child: Center(
              child: Text('placeholder', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(List<DartThrow> throws) {
    final t = AppTokens.of(context);

    if (throws.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Nessun dato', style: t.bodySmall(t.textSecondary)),
      );
    }

    final stats = TrainingStats(throws);
    final hit = stats.targetHits(_target);
    final total = throws.length;
    final percent = total == 0 ? 0 : (hit / total) * 100;

    switch (_statsController.view) {
      case StatsViewType.heatmap:
        return _insightBox(
          'Distribuzione colpi',
          'Mostra dove colpisci più spesso. Cerca concentrazione sul target.',
          t,
        );

      case StatsViewType.accuracy:
        final mm = stats.averageDistanceMm.toStringAsFixed(1);
        return _insightBox(
          'Precisione sul target',
          'Errore medio: $mm mm\n'
              '${percent.toStringAsFixed(0)}% hit\n'
              '${percent > 60 ? 'Buona precisione' : 'Riduci distanza dal target'}',
          t,
        );

      case StatsViewType.precision:
        return _insightBox(
          'Consistenza',
          'Valuta quanto i tiri sono raggruppati.\n'
              'Ellisse stretta = alta precisione.\n'
              'Ellisse larga = gesto instabile.',
          t,
        );

      case StatsViewType.bias:
        return _insightBox(
          'Errore direzionale',
          'Il punto rosso mostra dove tendi a tirare.\n'
              'Correggi nella direzione opposta.',
          t,
        );
      case StatsViewType.directionalBias:
        return _insightBox(
          'Bias direzionale (bande)',
          'Le bande mostrano media e dispersione orizzontale/verticale.\n'
              'Banda più larga = più variabilità su quell\'asse.',
          t,
        );
    }
  }

  Widget _insightBox(String title, String text, AppTokens t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.bodyBold(t.textPrimary)),
          const SizedBox(height: 6),
          Text(text, style: t.bodySmall(t.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildHeatmapView(List<DartThrow> throws) {
    return DartboardWidget(
      throws: throws,
      target: _target,
      overlays: const {
        DartboardOverlayType.heatmap,
      },
    );
  }

  Widget _buildAccuracyView(List<DartThrow> throws) {
    return DartboardWidget(
      throws: throws,
      target: _target,
      overlays: const {
        DartboardOverlayType.targetZone,
        DartboardOverlayType.targetCenter,
        DartboardOverlayType.radialError,
      },
    );
  }

  Widget _buildPrecisionView(List<DartThrow> throws) {
    return DartboardWidget(
      throws: throws,
      target: _target,
      overlays: const {
        DartboardOverlayType.dispersion,
      },
    );
  }

  Widget _buildBiasView(List<DartThrow> throws) {
    return DartboardWidget(
      throws: throws,
      target: _target,
      overlays: const {
        DartboardOverlayType.targetCenter,
        DartboardOverlayType.bias,
      },
    );
  }

  Widget _buildDirectionalBiasView(List<DartThrow> throws) {
    return DartboardWidget(
      throws: throws,
      target: _target,
      overlays: const {
        DartboardOverlayType.targetCenter,
        DartboardOverlayType.directionalBias,
      },
    );
  }

  Widget _buildDistanceView(List<DartThrow> throws) {
    final t = AppTokens.of(context);

    if (throws.isEmpty) {
      return Center(child: Text('Nessun dato', style: t.bodySmall(t.textSecondary)));
    }

    final stats = TrainingStats(throws);

    return Center(
      child: Text(
        '${stats.averageDistanceMm.toStringAsFixed(1)} mm',
        style: t.numericMedium(t.textPrimary),
      ),
    );
  }

  Widget _buildHitRateView(List<DartThrow> throws) {
    final t = AppTokens.of(context);

    if (throws.isEmpty) {
      return Center(child: Text('Nessun dato', style: t.bodySmall(t.textSecondary)));
    }

    final stats = TrainingStats(throws);
    final hits = stats.targetHits(_target);

    return Center(
      child: Text(
        '${((hits / throws.length) * 100).round()}%',
        style: t.numericMedium(t.accent),
      ),
    );
  }

  Widget _buildStatsPager(List<DartThrow> throws) {
    return SizedBox.expand(
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          _statsController.setView(StatsViewType.values[index]);
        },
        children: [
          _buildHeatmapView(throws),
          _buildAccuracyView(throws),
          _buildPrecisionView(throws),
          _buildBiasView(throws),
          _buildDirectionalBiasView(throws),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  Future<void> _handleModeTap() async {
    final mode = await showStatsModeDialog(context);
    if (mode == null) return;

    if (mode == StatsFilterMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _range,
      );
      if (range != null) {
        setState(() {
          _mode = StatsMode.period;
          _range = range;
          _session = null;
        });
      }
    } else {
      _openSessionPicker();
    }
  }


  Future<void> _handleSelectorTap() async {
    if (_mode == StatsMode.period) {
      final range = await showPeriodPickerDialog(
        context,
        initialRange: _range,
      );
      if (range != null) {
        setState(() {
          _range = range;
          _session = null;
        });
      }
    } else {
      _openSessionPicker();
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    // Converte _mode (StatsMode) in StatsFilterMode
    final filterMode = _mode == StatsMode.period
        ? StatsFilterMode.period
        : StatsFilterMode.session;

    final filterState = StatsFilterState(
      mode: _mode == StatsMode.period ? StatsFilterMode.period : StatsFilterMode.session,
      periodRange: _range,
      selectedSessionId: _session?.id,
      selectedSessionLabel: _session != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(_session!.startTime)
          : null,
    );
    final statsWidget = RepaintBoundary(
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.showAppBar
          ? AppBar(
        title: Text('Statistiche - ${widget.title}', style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.surface,
        elevation: 0,
      )
          : null,
      body: Column(
        children: [
          StatsFilterBar(
            state: filterState,
            onModeTap: _handleModeTap,
            onSelectorTap: _handleSelectorTap,  // ← usa questo unico callback
            leadingChild: TargetSectorSelector(
              currentTarget: _target,
              onSelected: (value) {
                setState(() {
                  _target = value;
                  _session = null;
                });
              },
            ),
          ),
          Divider(color: t.divider, height: 1),
          Expanded(
            child: statsWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final throws = _getFilteredThrows();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // COLONNA SINISTRA - BOARD (45% larghezza, min 400, max 600)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.65,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildStats(),
                  ),
                  Positioned(
                    left: 20,
                    top: 40,
                    child: Column(
                      children: [
                        _viewBtn('H', StatsViewType.heatmap),
                        const SizedBox(height: 8),
                        _viewBtn('A', StatsViewType.accuracy),
                        const SizedBox(height: 8),
                        _viewBtn('P', StatsViewType.precision),
                        const SizedBox(height: 8),
                        _viewBtn('B', StatsViewType.bias),
                        const SizedBox(height: 8),
                        _viewBtn('DB', StatsViewType.directionalBias),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 40,
                    child: Column(
                      children: [
                        _filterBtn('T', null),
                        const SizedBox(height: 8),
                        _filterBtn('1', 1),
                        const SizedBox(height: 8),
                        _filterBtn('2', 2),
                        const SizedBox(height: 8),
                        _filterBtn('3', 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // COLONNA DESTRA - STATISTICHE SCROLLABILI (resto della larghezza)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // RIUTILIZZA TUTTO QUELLO CHE GIÀ ESISTE IN _statsSection()
                _statsSectionContent(throws),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Aggiungi QUESTO metodo (estraiamo il contenuto da _statsSection)
  Widget _statsSectionContent(List<DartThrow> throws) {
    final t = AppTokens.of(context);

    return Column(
      children: [
        _clusterTitle('PRECISIONE', t),
        _buildUnifiedPrecisionTrendChart(throws),
        TrainingCharts.distanceAnalysis(throws, _target),
        TrainingCharts.directionalBias(throws),

        _clusterTitle('PERFORMANCE', t),
        TrainingCharts.hitTrend(throws, _target),
        TrainingCharts.dartBreakdown(throws, _target),
        TrainingCharts.streak(throws, _target),

        _clusterTitle('CONTROLLO', t),
        TrainingCharts.consistencyTrend(throws, _target),
        TrainingCharts.relationalPerformance(throws, _target, showSessionTime: _mode == StatsMode.period),

        _clusterTitle('RIEPILOGO', t),
        TrainingCharts.performanceScore(throws, _target),
        TrainingCharts.ringDistribution(throws, _target),

        _clusterTitle('SESSIONI', t),
        FutureBuilder<List<TrainingSessionStats>>(
          future: _loadSessionsForActivePeriod(),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? const <TrainingSessionStats>[];
            final points = sessions.map(_toSessionPoint).toList();
            return Column(
              children: [
                TrainingCharts.topSessions(points),
                TrainingCharts.worstSessions(points),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: _boardGestureActive
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  if (_boardGestureActive) return;
                  setState(() => _boardGestureActive = true);
                },
                onPointerUp: (_) {
                  if (!_boardGestureActive) return;
                  setState(() => _boardGestureActive = false);
                },
                onPointerCancel: (_) {
                  if (!_boardGestureActive) return;
                  setState(() => _boardGestureActive = false);
                },
                child: SizedBox(
                  height: 420,
                  child: Stack(
                    children: [
                      _buildStats(),
                      Positioned(
                        left: 8,
                        top: 40,
                        child: Column(
                          children: [
                            _viewBtn('H', StatsViewType.heatmap),
                            const SizedBox(height: 8),
                            _viewBtn('A', StatsViewType.accuracy),
                            const SizedBox(height: 8),
                            _viewBtn('P', StatsViewType.precision),
                            const SizedBox(height: 8),
                            _viewBtn('B', StatsViewType.bias),
                            const SizedBox(height: 8),
                            _viewBtn('DB', StatsViewType.directionalBias),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 40,
                        child: Column(
                          children: [
                            _filterBtn('T', null),
                            const SizedBox(height: 8),
                            _filterBtn('1', 1),
                            const SizedBox(height: 8),
                            _filterBtn('2', 2),
                            const SizedBox(height: 8),
                            _filterBtn('3', 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _statsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionPickerScreen extends StatefulWidget {
  final String target;
  final String? highlightedSessionId;
  final ValueChanged<TrainingSessionStats> onSelect;

  const _SessionPickerScreen({
    required this.target,
    required this.highlightedSessionId,
    required this.onSelect,
  });

  @override
  State<_SessionPickerScreen> createState() => _SessionPickerScreenState();
}

class _SessionPickerScreenState extends State<_SessionPickerScreen> {
  SessionSort _sort = SessionSort.dateDesc;
  late Future<List<TrainingSessionStats>> _future;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadSessions();
  }

  Future<List<TrainingSessionStats>> _loadSessions() async {
    final sessions = <TrainingSessionStats>[];
    final added = <String>{};

    final localRecords = await LocalTrainingSyncService.instance.getAllRecords();
    for (final local in localRecords.where((e) => e.target == widget.target)) {
      final localStats = TrainingStats(local.throwsList);
      final id = local.remoteId ?? local.localId;
      added.add(id);

      sessions.add(
        TrainingSessionStats(
          id: id,
          target: local.target,
          startTime: local.startTime,
          endTime: local.endTime,
          durationSeconds: local.endTime.difference(local.startTime).inSeconds,
          totalThrows: localStats.totalThrows,
          totalTurns: localStats.totalTurns,
          hits: localStats.targetHits(local.target),
          miss: localStats.targetMiss(local.target),
          hitPercent: localStats.totalThrows == 0
              ? 0
              : ((localStats.targetHits(local.target) / localStats.totalThrows) * 100).round(),
          avgDistanceMm: localStats.averageDistanceMm,
          bestStreak: localStats.bestStreak(local.target),
          focus: local.focus,
          stress: local.stress,
          energia: local.energia,
          fiducia: local.fiducia,
          distrazioni: local.distrazioni,
          commento: local.commento,
          syncStatus: local.syncStatus,
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _sortSessions(sessions);
      return sessions;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('target', isEqualTo: widget.target)
        .where('status', isEqualTo: 'complete')
        .get();

    for (final doc in snapshot.docs) {
      if (added.contains(doc.id)) continue;
      final data = doc.data();

      final startTs = data['startTime'];
      final endTs = data['endTime'];

      if (startTs is! Timestamp) {
        continue;
      }

      final stats = (data['stats'] is Map<String, dynamic>)
          ? data['stats'] as Map<String, dynamic>
          : <String, dynamic>{};

      sessions.add(
        TrainingSessionStats(
          id: doc.id,
          target: (data['target'] ?? '').toString(),
          startTime: startTs.toDate(),
          endTime: endTs is Timestamp ? endTs.toDate() : startTs.toDate(),
          durationSeconds: _asInt(data['durationSeconds']),
          totalThrows: _asInt(data['totalThrows']),
          totalTurns: _asInt(data['totalTurns']),
          hits: _asInt(stats['hits']),
          miss: _asInt(stats['miss']),
          hitPercent: _asInt(stats['hitPercent']),
          avgDistanceMm: _asDouble(stats['avgDistanceMm']),
          bestStreak: _asInt(stats['bestStreak']),
          focus: _asNullableInt(data['focus']),
          stress: _asNullableInt(data['stress']),
          energia: _asNullableInt(data['energia']),
          fiducia: _asNullableInt(data['fiducia']),
          distrazioni: _asNullableInt(data['distrazioni']),
          commento: data['commento']?.toString(),
          syncStatus: LocalTrainingSyncStatus.synced,
        ),
      );
    }

    _sortSessions(sessions);
    return sessions;
  }

  void _sortSessions(List<TrainingSessionStats> sessions) {
    switch (_sort) {
      case SessionSort.dateDesc:
        sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case SessionSort.dateAsc:
        sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case SessionSort.performanceDesc:
        sessions.sort((a, b) => b.hitPercent.compareTo(a.hitPercent));
        break;
      case SessionSort.performanceAsc:
        sessions.sort((a, b) => a.hitPercent.compareTo(b.hitPercent));
        break;
      case SessionSort.durationDesc:
        sessions.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
        break;
      case SessionSort.durationAsc:
        sessions.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
        break;
    }
  }

  void _reload() {
    setState(() {
      _future = _loadSessions();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final idsToDelete = _selectedIds.toList();
    final t = AppTokens.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elimina sessioni', style: t.bodyBold(t.textPrimary)),
        content: Text(
          'Sei sicuro di voler eliminare ${idsToDelete.length} sessione${idsToDelete.length > 1 ? '?' : '?'}',
          style: t.bodySmall(t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla', style: t.bodyBold(t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Elimina', style: t.bodyBold(t.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSelectionMode = false;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final db = FirebaseFirestore.instance;

      for (final id in idsToDelete) {
        final trainingRef = db
            .collection('users')
            .doc(user.uid)
            .collection('trainings')
            .doc(id);

        final throwsSnapshot = await trainingRef.collection('throws').get();

        final batch = db.batch();
        for (final throwDoc in throwsSnapshot.docs) {
          batch.delete(throwDoc.reference);
        }
        batch.delete(trainingRef);
        await batch.commit();
      }
    }

    await LocalTrainingSyncService.instance.deleteRecords(idsToDelete);

    if (!mounted) return;

    _selectedIds.clear();
    _reload();
  }
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} selezionate' : 'Sessioni',
          style: TextStyle(color: t.textPrimary),
        ),
        backgroundColor: t.surface,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
          icon: Icon(Icons.close, color: t.textPrimary),
          onPressed: _toggleSelectionMode,
        )
            : null,
        actions: [
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete, color: t.red),
              onPressed: _deleteSelected,
            ),
          if (!_isSelectionMode)
            PopupMenuButton<SessionSort>(
              onSelected: (value) {
                _sort = value;
                _reload();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: SessionSort.dateDesc, child: Text('Data ↓')),
                PopupMenuItem(value: SessionSort.dateAsc, child: Text('Data ↑')),
                PopupMenuItem(value: SessionSort.performanceDesc, child: Text('Performance ↓')),
                PopupMenuItem(value: SessionSort.performanceAsc, child: Text('Performance ↑')),
                PopupMenuItem(value: SessionSort.durationDesc, child: Text('Durata ↓')),
                PopupMenuItem(value: SessionSort.durationAsc, child: Text('Durata ↑')),
              ],
            ),
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(Icons.select_all, color: t.textSecondary),
              onPressed: _toggleSelectionMode,
              tooltip: 'Seleziona sessioni',
            ),
        ],
      ),
      body: FutureBuilder<List<TrainingSessionStats>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Errore caricamento sessioni: ${snapshot.error}',
                    style: t.bodySmall(t.red)),
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Text('Nessuna sessione', style: t.bodySmall(t.textSecondary)),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];
              final isHighlighted = widget.highlightedSessionId == s.id;
              final isSelected = _selectedIds.contains(s.id);
              final status = s.syncStatus;
              IconData? icon;
              Color? iconColor;

              switch (status) {
                case LocalTrainingSyncStatus.synced:
                  icon = Icons.cloud_done;
                  iconColor = t.green;
                  break;
                case LocalTrainingSyncStatus.pending:
                  icon = Icons.cloud_upload;
                  iconColor = t.orange;
                  break;
                case LocalTrainingSyncStatus.syncing:
                  icon = Icons.cloud_sync;
                  iconColor = t.accent;
                  break;
                case LocalTrainingSyncStatus.failed:
                  icon = Icons.cloud_off;
                  iconColor = t.red;
                  break;
                case null:
                  break;
              }

              return Container(
                color: isSelected
                    ? t.accent.withOpacity(0.2)
                    : (isHighlighted ? t.accent.withOpacity(0.15) : null),
                child: ListTile(
                  leading: _isSelectionMode
                      ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(s.id),
                    activeColor: t.accent,
                    checkColor: t.accentFg,
                  )
                      : (icon != null ? Icon(icon, color: iconColor) : null),
                  title: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(s.startTime),
                    style: t.bodyBold(t.textPrimary),
                  ),
                  subtitle: Text(
                    '${s.hitPercent}% • ${s.totalThrows} tiri • ${_formatDuration(s.durationSeconds)}',
                    style: t.bodySmall(t.textSecondary),
                  ),
                  trailing: !_isSelectionMode && status == LocalTrainingSyncStatus.failed
                      ? IconButton(
                    icon: Icon(Icons.refresh, color: t.accent),
                    onPressed: () async {
                      await LocalTrainingSyncService.instance.syncAll();
                      _reload();
                    },
                  )
                      : null,
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(s.id);
                    } else {
                      widget.onSelect(s);
                      Navigator.pop(context);
                    }
                  },
                ),
              );
              },
          );
        },
      ),
    );
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
  // Aggiungi in training_stats_screen.dart, dentro la classe TrainingSessionStats
  factory TrainingSessionStats.fromRecord(LocalTrainingRecord record) {
    final stats = TrainingStats(record.throwsList);
    return TrainingSessionStats(
      id: record.remoteId ?? record.localId,
      target: record.target,
      startTime: record.startTime,
      endTime: record.endTime,
      durationSeconds: record.endTime.difference(record.startTime).inSeconds,
      totalThrows: stats.totalThrows,
      totalTurns: stats.totalTurns,
      hits: stats.targetHits(record.target),
      miss: stats.targetMiss(record.target),
      hitPercent: stats.totalThrows == 0
          ? 0
          : ((stats.targetHits(record.target) / stats.totalThrows) * 100).round(),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppTokens.r10,
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.bodySmall(t.textSecondary)),
          Text(value, style: t.bodyBold(t.textPrimary)),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Box(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: AppTokens.r10,
        border: Border.all(color: t.border),
        color: t.surfaceHigh,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: t.bodyBold(t.textPrimary)),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, color: t.textSecondary, size: 18),
          ],
        ],
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _formatDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  }

  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }

  return '${seconds}s';
}

