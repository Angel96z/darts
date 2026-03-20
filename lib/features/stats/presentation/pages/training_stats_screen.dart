import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../game/domain/entities/dart_models.dart';
import '../../../game/domain/entities/training_mode.dart';
import '../../../game/presentation/widgets/dartboard_widget.dart';
import '../../data/datasources/local_training_sync_service.dart';
import 'training_charts.dart';
import '../../domain/entities/training_stats.dart';
import '../widgets/target_sector_selector.dart';

enum StatsMode { period, session }

enum StatsViewType {
  heatmap,
  accuracy,     // target + radial error
  precision,    // dispersion
  bias,         // punto medio
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

  const TrainingStatsScreen({
    super.key,
    required this.title,
    required this.mode,
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

  @override
  void initState() {
    super.initState();

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

// 🔥 PRIMO: Carica da cache locale
    final localRecords = await _loadFromLocalCache();

// 🔥 SECONDO: Carica da Firestore (solo quelli non in locale)
    final remoteRecords = await _loadFromFirestore(localRecords);

    final allRecords = [...localRecords, ...remoteRecords];

    if (!mounted) return;

    setState(() {
      _cachedRecords = allRecords;
      _loaded = true;
    });
  }

  Future<List<_CachedThrowRecord>> _loadFromLocalCache() async {
    final allLocal = await LocalTrainingSyncService.instance.getAllRecords();
    final records = <_CachedThrowRecord>[];

    for (final local in allLocal) {
      if (local.syncStatus != LocalTrainingSyncStatus.synced) {
// Includi anche quelli non ancora sincronizzati
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

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('throws')
        .get();

    final records = <_CachedThrowRecord>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final trainingId = (data['trainingId'] ?? '').toString();

// Salta se già presente in locale
      if (existingIds.contains(trainingId)) continue;

      records.add(_CachedThrowRecord(
        trainingId: trainingId,
        trainingTarget: (data['trainingTarget'] ?? '').toString(),
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

    return records;
  }
  String _buildRightLabel() {
    if (_mode == StatsMode.period) {
      if (_range == null) return 'Range';
      return '${DateFormat('dd/MM').format(_range!.start)}-${DateFormat('dd/MM').format(_range!.end)}';
    }

    if (_session == null) return 'Seleziona';
    return '${DateFormat('dd/MM').format(_session!.startTime)} • ${_session!.id}';
  }

  Future<void> _openPeriod() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (result == null) return;

    setState(() {
      _mode = StatsMode.period;
      _range = result;
      _session = null;
    });
  }

  void _openSessionPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SessionPickerScreen(
          target: _target,
          onSelect: (session) {
            setState(() {
              _mode = StatsMode.session;
              _session = session;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TargetSectorSelector(
            currentTarget: _target,
            onSelected: (value) {
              setState(() {
                _target = value;
                _session = null;
              });
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton<StatsMode>(
            onSelected: (mode) {
              setState(() {
                _mode = mode;
              });

              if (mode == StatsMode.period) {
                _openPeriod();
              } else {
                _openSessionPicker();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: StatsMode.period,
                child: Text('Periodo'),
              ),
              PopupMenuItem(
                value: StatsMode.session,
                child: Text('Sessione'),
              ),
            ],
            child: _Box(_mode == StatsMode.period ? 'Periodo' : 'Sessione'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (_mode == StatsMode.period) {
                _openPeriod();
              } else {
                _openSessionPicker();
              }
            },
            child: _Box(_buildRightLabel()),
          ),
        ],
      ),
    );
  }


  Widget _viewBtn(String label, StatsViewType type) {
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
          borderRadius: BorderRadius.circular(8),
          color: selected ? Colors.blue : Colors.black.withOpacity(0.4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _filterBtn(String label, int? dart) {
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
            borderRadius: BorderRadius.circular(10),
            color: selected ? Colors.blue : Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Future<List<TrainingSessionStats>> _loadTrainingsForTarget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('target', isEqualTo: _target)
        .where('status', isEqualTo: 'complete')
        .get();

    final sessions = <TrainingSessionStats>[];

    for (final doc in snapshot.docs) {
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

    final hitPercent =
    totalThrows == 0 ? 0 : ((totalHits / totalThrows) * 100).round();

    final avgDistanceMm =
    totalSessions == 0 ? 0.0 : (totalAvgDistance / totalSessions);

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

    // Filtra per target
    filtered = filtered.where((r) => r.trainingTarget == _target);

    // Filtra per periodo - CORRETTO!
    if (_mode == StatsMode.period && _range != null) {
      final startDay = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
      final endDay = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);

      filtered = filtered.where((r) {
        final t = r.dartThrow.timestamp;
        return t.isAfter(startDay.subtract(Duration(milliseconds: 1))) &&
            t.isBefore(endDay.add(Duration(milliseconds: 1)));
      });
    }

    // Filtra per sessione
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
    final throws = _getFilteredThrows();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TrainingCharts.dartBreakdown(throws, _target),
          TrainingCharts.distanceAnalysis(throws, _target),
          TrainingCharts.hitTrend(throws, _target),
          TrainingCharts.mmTrend(throws, _target),
          TrainingCharts.streak(throws, _target),
          TrainingCharts.performanceScore(throws, _target),
          TrainingCharts.ringDistribution(throws, _target),
        ],
      ),
    );
  }
  Widget _statBox(String title) {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: Center(
              child: Text(
                'placeholder',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInsight(List<DartThrow> throws) {
    if (throws.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Nessun dato'),
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
        );

      case StatsViewType.accuracy:
        final mm = stats.averageDistanceMm.toStringAsFixed(1);

        return _insightBox(
          'Precisione sul target',
          'Errore medio: $mm mm\n'
              '${percent.toStringAsFixed(0)}% hit\n'
              '${percent > 60 ? 'Buona precisione' : 'Riduci distanza dal target'}',
        );

      case StatsViewType.precision:
        return _insightBox(
          'Consistenza',
          'Valuta quanto i tiri sono raggruppati.\n'
              'Ellisse stretta = alta precisione.\n'
              'Ellisse larga = gesto instabile.',
        );

      case StatsViewType.bias:
        return _insightBox(
          'Errore direzionale',
          'Il punto rosso mostra dove tendi a tirare.\n'
              'Correggi nella direzione opposta.',
        );
    }
  }
  Widget _insightBox(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(text),
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
  Widget _buildDistanceView(List<DartThrow> throws) {
    if (throws.isEmpty) {
      return const Center(child: Text('Nessun dato'));
    }

    // USA TrainingStats!
    final stats = TrainingStats(throws);

    return Center(
      child: Text(
        '${stats.averageDistanceMm.toStringAsFixed(1)} mm',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHitRateView(List<DartThrow> throws) {
    if (throws.isEmpty) {
      return const Center(child: Text('Nessun dato'));
    }

    // USA TrainingStats!
    final stats = TrainingStats(throws);
    final hits = stats.targetHits(_target); // o qualsiasi altra logica

    return Center(
      child: Text(
        '${((hits / throws.length) * 100).round()}%',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiche - ${widget.title}'),
      ),
      body: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1),
          Expanded(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
    );

  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Center(
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
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: _statsSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              SizedBox(
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
  final ValueChanged<TrainingSessionStats> onSelect;

  const _SessionPickerScreen({
    required this.target,
    required this.onSelect,
  });

  @override
  State<_SessionPickerScreen> createState() => _SessionPickerScreenState();
}

class _SessionPickerScreenState extends State<_SessionPickerScreen> {
  SessionSort _sort = SessionSort.dateDesc;
  late Future<List<TrainingSessionStats>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSessions();
  }

  Future<List<TrainingSessionStats>> _loadSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('target', isEqualTo: widget.target)
        .where('status', isEqualTo: 'complete')
        .get();

    final sessions = <TrainingSessionStats>[];

    for (final doc in snapshot.docs) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessioni'),
        actions: [
          PopupMenuButton<SessionSort>(
            onSelected: (value) {
              _sort = value;
              _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: SessionSort.dateDesc,
                child: Text('Data ↓'),
              ),
              PopupMenuItem(
                value: SessionSort.dateAsc,
                child: Text('Data ↑'),
              ),
              PopupMenuItem(
                value: SessionSort.performanceDesc,
                child: Text('Performance ↓'),
              ),
              PopupMenuItem(
                value: SessionSort.performanceAsc,
                child: Text('Performance ↑'),
              ),
              PopupMenuItem(
                value: SessionSort.durationDesc,
                child: Text('Durata ↓'),
              ),
              PopupMenuItem(
                value: SessionSort.durationAsc,
                child: Text('Durata ↑'),
              ),
            ],
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
                child: Text('Errore caricamento sessioni: ${snapshot.error}'),
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Text('Nessuna sessione'),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];

              return FutureBuilder<LocalTrainingRecord?>(
                future: LocalTrainingSyncService.instance.getById(s.id),
                builder: (context, snapshot) {
                  Color? iconColor;
                  IconData? icon;

                  if (snapshot.hasData) {
                    final record = snapshot.data;
                    if (record != null) {
                      switch (record.syncStatus) {
                        case LocalTrainingSyncStatus.synced:
                          iconColor = Colors.green;
                          icon = Icons.cloud_done;
                          break;
                        case LocalTrainingSyncStatus.pending:
                          iconColor = Colors.orange;
                          icon = Icons.cloud_upload;
                          break;
                        case LocalTrainingSyncStatus.syncing:
                          iconColor = Colors.blue;
                          icon = Icons.cloud_sync;
                          break;
                        case LocalTrainingSyncStatus.failed:
                          iconColor = Colors.red;
                          icon = Icons.cloud_off;
                          break;
                      }
                    }
                  }

                  return ListTile(
                    leading: icon != null
                        ? Icon(icon, color: iconColor)
                        : null,
                    title: Text(
                      '${DateFormat('dd/MM/yyyy').format(s.startTime)} • ${s.id}',
                    ),
                    subtitle: Text(
                      '${s.hitPercent}% • ${s.totalThrows} tiri • ${_formatDuration(s.durationSeconds)}',
                    ),
                    trailing: snapshot.hasData && snapshot.data?.syncStatus == LocalTrainingSyncStatus.failed
                        ? IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await LocalTrainingSyncService.instance.syncAll();
                        setState(() {});
                      },
                    )
                        : null,
                    onTap: () {
                      widget.onSelect(s);
                      Navigator.pop(context);
                    },
                  );
                },
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
  });
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String text;

  const _Box(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
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