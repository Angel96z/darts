// session_picker_screen.dart
/// Widget riutilizzabile per selezionare sessioni (Training o Match)

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app_theme.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../cricket_dart_extractor.dart';
import '../../data/datasources/local_training_sync_service.dart';
import '../../domain/entities/training_stats.dart';
import '../../x01_dart_extractor.dart';
import '../pages/training_stats_screen.dart';
import 'match_session_stats.dart';

enum SessionType { training, match }

enum SessionSort {
  dateDesc,
  dateAsc,
  performanceDesc,
  performanceAsc,
  durationDesc,
  durationAsc,
}

class SessionPickerScreen<T> extends StatefulWidget {
  final SessionType type;
  final String? filterBy; // training: target, match: mode ('x01'/'cricket')
  final String? highlightedId;
  final ValueChanged<T> onSelect;
  final bool allowDelete;

  const SessionPickerScreen({
    super.key,
    required this.type,
    this.filterBy,
    this.highlightedId,
    required this.onSelect,
    this.allowDelete = true,
  });

  @override
  State<SessionPickerScreen<T>> createState() => _SessionPickerScreenState<T>();
}

class _SessionPickerScreenState<T> extends State<SessionPickerScreen<T>> {
  SessionSort _sort = SessionSort.dateDesc;
  late Future<List<T>> _future;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _future = _loadSessions();
    _attachSyncListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _attachSyncListeners() {
    switch (widget.type) {
      case SessionType.training:
        _subscriptions.add(
          LocalTrainingSyncService.instance.onSyncStatusChanged.listen((_) {
            if (!mounted) return;
            _reload();
          }),
        );
        break;

      case SessionType.match:
        _subscriptions.add(
          LocalMatchSyncService.instance.onSyncStatusChanged.listen((_) {
            if (!mounted) return;
            _reload();
          }),
        );
        break;
    }
  }

  Future<List<T>> _loadSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final sessions = <T>[];
    final added = <String>{};

    switch (widget.type) {
      case SessionType.training:
        await _loadTrainingSessions(sessions, added);
        break;
      case SessionType.match:
        await _loadMatchSessions(sessions, added);
        break;
    }

    _sortSessions(sessions);
    return sessions;
  }

  Future<void> _loadTrainingSessions(List<T> sessions, Set<String> added) async {
    final localRecords = await LocalTrainingSyncService.instance.getAllRecords();

    for (final local in localRecords.where((e) => e.target == widget.filterBy)) {
      final localStats = TrainingStats(local.throwsList);
      final id = local.remoteId ?? local.localId;
      added.add(id);

      sessions.add(TrainingSessionStats(
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
      ) as T);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trainings')
        .where('target', isEqualTo: widget.filterBy)
        .where('status', isEqualTo: 'complete')
        .get();

    for (final doc in snapshot.docs) {
      if (added.contains(doc.id)) continue;
      final data = doc.data();

      final startTs = data['startTime'];
      final endTs = data['endTime'];

      if (startTs is! Timestamp) continue;

      final stats = (data['stats'] is Map<String, dynamic>)
          ? data['stats'] as Map<String, dynamic>
          : <String, dynamic>{};

      sessions.add(TrainingSessionStats(
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
      ) as T);
    }
  }

  Future<void> _loadMatchSessions(List<T> sessions, Set<String> added) async {
    final allMatches = await LocalMatchSyncService.instance.getAllRecords();

    final filteredMatches = widget.filterBy != null
        ? allMatches.where((m) => m.mode == widget.filterBy).toList()
        : allMatches;

    for (final match in filteredMatches) {
      final id = match.remoteId ?? match.localId;
      if (added.contains(id)) continue;
      added.add(id);

      final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

      int totalTurns = 0;
      int totalDarts = 0;
      int totalScore = 0;
      int checkouts = 0;
      double average = 0.0;

      if (match.mode == 'x01' && playerId.isNotEmpty) {
        final dataset = const X01DartExtractor().extract(
          records: [match],
          playerId: playerId,
        );

        final x01Turns = dataset.turns;

        totalTurns = x01Turns.length;
        totalDarts = x01Turns.fold<int>(0, (sum, turn) => sum + turn.dartsThrown);
        totalScore = x01Turns.fold<int>(0, (sum, turn) => sum + turn.total);
        checkouts = x01Turns.where((turn) => turn.isCheckout).length;
        average = totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;
      } else if (match.mode == 'cricket') {
        final dataset = const CricketDartExtractor().extract(
          records: [match],
          playerId: playerId.isEmpty ? null : playerId,
        );

        totalTurns = dataset.turns.length;
        totalDarts = dataset.totalDarts;
        totalScore = dataset.totalMarksHit;
        checkouts = dataset.closingDarts.length;
        average = dataset.rawMultiplierAverage;
      } else {
        final playerTurns = playerId.isEmpty
            ? <dynamic>[]
            : (match.playerTurns[playerId] ?? []);

        totalTurns = playerTurns.length;
        totalDarts = playerTurns.fold<int>(0, (sum, turn) => sum + (turn.throws.length as int));
        totalScore = playerTurns.fold<int>(0, (sum, turn) => sum + (turn.total as int));
        checkouts = playerTurns.where((turn) => turn.isCheckout == true).length;
        average = totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;
      }

      sessions.add(MatchSessionStats(
        id: id,
        mode: match.mode,
        startTime: match.startTime,
        endTime: match.endTime,
        durationSeconds: match.endTime.difference(match.startTime).inSeconds,
        totalTurns: totalTurns,
        totalDarts: totalDarts,
        average: average,
        checkouts: checkouts,
        hitPercent: 0,
        syncStatus: match.syncStatus,
        matchRecord: match,
      ) as T);
    }
  }
  void _sortSessions(List<T> sessions) {
    switch (_sort) {
      case SessionSort.dateDesc:
        sessions.sort((a, b) => _getStartTime(b).compareTo(_getStartTime(a)));
        break;
      case SessionSort.dateAsc:
        sessions.sort((a, b) => _getStartTime(a).compareTo(_getStartTime(b)));
        break;
      case SessionSort.performanceDesc:
        sessions.sort((a, b) => _getPerformance(b).compareTo(_getPerformance(a)));
        break;
      case SessionSort.performanceAsc:
        sessions.sort((a, b) => _getPerformance(a).compareTo(_getPerformance(b)));
        break;
      case SessionSort.durationDesc:
        sessions.sort((a, b) => _getDuration(b).compareTo(_getDuration(a)));
        break;
      case SessionSort.durationAsc:
        sessions.sort((a, b) => _getDuration(a).compareTo(_getDuration(b)));
        break;
    }
  }

  DateTime _getStartTime(T session) {
    if (session is TrainingSessionStats) return session.startTime;
    if (session is MatchSessionStats) return session.startTime;
    return DateTime.now();
  }

  int _getPerformance(T session) {
    if (session is TrainingSessionStats) return session.hitPercent;
    if (session is MatchSessionStats) return session.average.round();
    return 0;
  }

  int _getDuration(T session) {
    if (session is TrainingSessionStats) return session.durationSeconds;
    if (session is MatchSessionStats) return session.durationSeconds;
    return 0;
  }
  String _getMatchRulesLabel(MatchSessionStats session) {
    final match = session.matchRecord;
    final gameConfig = match.gameConfig;

    if (session.mode == 'cricket') {
      final cutThroat = gameConfig['cutThroat'] == true;
      return cutThroat ? 'CRICKET · CUT THROAT' : 'CRICKET';
    }

    final startingScore = gameConfig['startingScore'] ?? '';
    final doubleIn = gameConfig['doubleIn'] == true;
    final doubleOut = gameConfig['doubleOut'] == true;
    final tripleOut = gameConfig['tripleOut'] == true;

    final inLabel = doubleIn ? 'D-IN' : 'S-IN';
    final outLabel = tripleOut ? 'T-OUT' : (doubleOut ? 'D-OUT' : 'S-OUT');

    return '$startingScore · $inLabel · $outLabel';
  }

  bool _isCurrentPlayerWinner(MatchSessionStats session) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (playerId.isEmpty) return false;

    if (session.mode == 'x01') {
      final dataset = const X01DartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return false;

      final wonLegs = finishedLegs.where((leg) => leg.isWon).length;
      final lostLegs = finishedLegs.where((leg) => leg.isLost).length;

      return wonLegs > lostLegs;
    }

    if (session.mode == 'cricket') {
      final dataset = const CricketDartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return false;

      final wonLegs = finishedLegs.where((leg) => leg.isWon).length;
      final lostLegs = finishedLegs.where((leg) => leg.isLost).length;

      return wonLegs > lostLegs;
    }

    return false;
  }

  String _getSubtitle(T session) {
    if (session is TrainingSessionStats) {
      return '${session.hitPercent}% • ${session.totalThrows} tiri • ${_formatDuration(session.durationSeconds)}';
    }

    if (session is MatchSessionStats) {
      final avgTurns = _getAverageTurnsPerLeg(session);
      final avgLabel = session.mode == 'cricket' ? 'Avg marker' : 'Avg';

      return '${_getVictoryTargetLabel(session)} • $avgLabel: ${session.average.toStringAsFixed(1)} • ${avgTurns.toStringAsFixed(1)} turni/leg • ${_formatDuration(session.durationSeconds)}';
    }

    return '';
  }
  String _getVictoryTargetLabel(MatchSessionStats session) {
    final config = session.matchRecord.matchConfig;

    final mode = (config['mode'] ?? '').toString().toLowerCase();
    final setCount = _asInt(config['setCount']);
    final legCount = _asInt(config['legCount']);

    final setsToWin = mode.contains('best')
        ? (setCount ~/ 2) + 1
        : setCount;

    final legsToWin = mode.contains('best')
        ? (legCount ~/ 2) + 1
        : legCount;

    return 'S$setsToWin/L$legsToWin';
  }

  double _getAverageTurnsPerLeg(MatchSessionStats session) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (playerId.isEmpty) return 0;

    if (session.mode == 'x01') {
      final dataset = const X01DartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return 0;

      final totalTurns = finishedLegs.fold<int>(
        0,
            (sum, leg) => sum + leg.turns.length,
      );

      return totalTurns / finishedLegs.length;
    }

    if (session.mode == 'cricket') {
      final dataset = const CricketDartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return 0;

      final totalTurns = finishedLegs.fold<int>(
        0,
            (sum, leg) => sum + leg.turns.length,
      );

      return totalTurns / finishedLegs.length;
    }

    return 0;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final t = AppTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elimina sessioni', style: t.bodyBold(t.textPrimary)),
        content: Text(
          'Sei sicuro di voler eliminare ${_selectedIds.length} sessione${_selectedIds.length > 1 ? 'i' : ''}?',
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

    final idsToDelete = Set<String>.from(_selectedIds);

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    try {
      switch (widget.type) {
        case SessionType.training:
          for (final id in idsToDelete) {
            await LocalTrainingSyncService.instance.deleteRecord(id);
          }
          break;

        case SessionType.match:
          for (final id in idsToDelete) {
            await LocalMatchSyncService.instance.deleteRecord(id);
          }
          break;
      }

      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore eliminazione sessioni: $e'),
        ),
      );
      _reload();
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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} selezionate'
              : 'Sessioni — PICKER UFFICIALE',
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
              onPressed: widget.allowDelete ? _deleteSelected : null,
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
          if (!_isSelectionMode && widget.allowDelete)
            IconButton(
              icon: Icon(Icons.select_all, color: t.textSecondary),
              onPressed: _toggleSelectionMode,
              tooltip: 'Seleziona sessioni',
            ),
        ],
      ),
      body: FutureBuilder<List<T>>(
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
              final session = sessions[index];
              final id = _getId(session);
              final isHighlighted = widget.highlightedId == id;
              final isSelected = _selectedIds.contains(id);
              final syncStatus = _getSyncStatus(session);

              IconData? icon;
              Color? iconColor;

              switch (syncStatus) {
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
                default:
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
                    onChanged: (_) => _toggleSelection(id),
                    activeColor: t.accent,
                    checkColor: t.accentFg,
                  )
                      : (icon != null ? Icon(icon, color: iconColor) : null),
                  title: _SessionPickerTitle(
                    session: session,
                    dateText: DateFormat('dd/MM/yyyy HH:mm').format(_getStartTime(session)),
                    t: t,
                  ),
                  subtitle: Text(
                    _getSubtitle(session),
                    style: t.bodySmall(t.textSecondary),
                  ),
                  trailing: !_isSelectionMode && syncStatus == LocalTrainingSyncStatus.failed
                      ? IconButton(
                    icon: Icon(Icons.refresh, color: t.accent),
                    onPressed: () async {
                      if (widget.type == SessionType.training) {
                        await LocalTrainingSyncService.instance.syncAll();
                      } else {
                        await LocalMatchSyncService.instance.syncAll();
                      }
                      _reload();
                    },
                  )
                      : null,
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(id);
                    } else {
                      widget.onSelect(session);
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

  String _getId(T session) {
    if (session is TrainingSessionStats) return session.id;
    if (session is MatchSessionStats) return session.id;
    return '';
  }

  LocalTrainingSyncStatus? _getSyncStatus(T session) {
    if (session is TrainingSessionStats) return session.syncStatus;
    if (session is MatchSessionStats) {
      // Mappa LocalMatchSyncStatus a LocalTrainingSyncStatus
      final matchStatus = session.syncStatus;
      if (matchStatus == null) return null;
      switch (matchStatus) {
        case LocalMatchSyncStatus.synced:
          return LocalTrainingSyncStatus.synced;
        case LocalMatchSyncStatus.pending:
        case LocalMatchSyncStatus.pendingDelete:
          return LocalTrainingSyncStatus.pending;
        case LocalMatchSyncStatus.syncing:
          return LocalTrainingSyncStatus.syncing;
        case LocalMatchSyncStatus.failed:
        case LocalMatchSyncStatus.failedDelete:
          return LocalTrainingSyncStatus.failed;
      }
    }
    return null;
  }
}
class _SessionPickerTitle extends StatelessWidget {
  final dynamic session;
  final String dateText;
  final AppTokens t;

  const _SessionPickerTitle({
    required this.session,
    required this.dateText,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    if (session is! MatchSessionStats) {
      return Text(
        dateText,
        style: t.bodyBold(t.textPrimary),
      );
    }

    final matchSession = session as MatchSessionStats;
    final rulesLabel = _buildRulesLabel(matchSession);
    final isWinner = _isWinner(matchSession);

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          dateText,
          style: t.bodyBold(t.textPrimary),
        ),
        _SmallSessionBadge(label: rulesLabel, t: t),
        if (isWinner)
          Icon(
            Icons.emoji_events_rounded,
            color: t.accent,
            size: 17,
          ),
      ],
    );
  }

  String _buildRulesLabel(MatchSessionStats session) {
    final gameConfig = session.matchRecord.gameConfig;

    if (session.mode == 'cricket') {
      final cutThroat = gameConfig['cutThroat'] == true;
      return cutThroat ? 'CRICKET · CUT THROAT' : 'CRICKET';
    }

    final startingScore = gameConfig['startingScore'] ?? '';
    final doubleIn = gameConfig['doubleIn'] == true;
    final doubleOut = gameConfig['doubleOut'] == true;
    final tripleOut = gameConfig['tripleOut'] == true;

    final inLabel = doubleIn ? 'D-IN' : 'S-IN';
    final outLabel = tripleOut ? 'T-OUT' : (doubleOut ? 'D-OUT' : 'S-OUT');

    return '$startingScore · $inLabel · $outLabel';
  }

  bool _isWinner(MatchSessionStats session) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (playerId.isEmpty) return false;

    if (session.mode == 'x01') {
      final dataset = const X01DartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return false;

      final wonLegs = finishedLegs.where((leg) => leg.isWon).length;
      final lostLegs = finishedLegs.where((leg) => leg.isLost).length;

      return wonLegs > lostLegs;
    }

    if (session.mode == 'cricket') {
      final dataset = const CricketDartExtractor().extract(
        records: [session.matchRecord],
        playerId: playerId,
      );

      final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
      if (finishedLegs.isEmpty) return false;

      final wonLegs = finishedLegs.where((leg) => leg.isWon).length;
      final lostLegs = finishedLegs.where((leg) => leg.isLost).length;

      return wonLegs > lostLegs;
    }

    return false;
  }
}

class _SmallSessionBadge extends StatelessWidget {
  final String label;
  final AppTokens t;

  const _SmallSessionBadge({
    required this.label,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.10),
        borderRadius: AppTokens.r6,
        border: Border.all(color: t.accent.withOpacity(0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: t.accent,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// Helper functions
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
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}