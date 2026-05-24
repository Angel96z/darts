/// File: x01_stats_screen.dart - IDENTICO alla logica del training

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../app_theme.dart';
import '../../../match_sync/domain/entities/local_match_record.dart';
import '../../../match_sync/data/services/local_match_sync_service.dart';
import '../../../room_v4/domain/models/game_config.dart';
import '../../../room_v4/domain/models/player_turn.dart';
import '../../../room_v4/presentation/room_lobby_page.dart';
import '../../../room_v4/presentation/widgets/current_turn_card.dart';
import '../../x01_dart_extractor.dart';
import '../../shared/stats_filter.dart';
import '../widgets/match_session_stats.dart';
import '../widgets/session_picker_screen.dart';
import '../widgets/stats_filter_bar.dart';
import '../widgets/unified_stats_chart.dart';

// ============================================================
// CACHED MATCH RECORD (come _CachedThrowRecord del training)
// ============================================================

class _CachedMatchRecord {
  final String matchId;
  final DateTime startTime;
  final DateTime endTime;
  final int startingScore;
  final String winnerName;
  final List<PlayerTurn> playerTurns;
  final int totalTurns;
  final int totalDarts;
  final int totalScore;
  final int checkouts;
  final double average;
  final int oneEighties;
  final int oneForties;
  final int oneHundreds;
  final int bestTurn;
  final int bestCheckout;
  final LocalMatchRecord originalRecord;  // ← AGGIUNGI

  const _CachedMatchRecord({
    required this.matchId,
    required this.startTime,
    required this.endTime,
    required this.startingScore,
    required this.winnerName,
    required this.playerTurns,
    required this.totalTurns,
    required this.totalDarts,
    required this.totalScore,
    required this.checkouts,
    required this.average,
    required this.oneEighties,
    required this.oneForties,
    required this.oneHundreds,
    required this.bestTurn,
    required this.bestCheckout,
    required this.originalRecord,

  });
}

// ============================================================
// CONTROLLER (come StatsController del training)
// ============================================================

// x01_stats_screen.dart - X01StatsController corretto

class X01StatsController extends ChangeNotifier {
  List<_CachedMatchRecord> _allMatches = [];
  List<_CachedMatchRecord> _filteredMatches = [];
  _CachedMatchRecord? _selectedMatch;
  bool _loading = true;
  String? _error;

  // ✅ STATO UNIFICATO usando StatsFilterState
  StatsFilterState _filterState = StatsFilterState(
    mode: StatsFilterMode.period,
    periodRange: DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    ),
  );

  List<_CachedMatchRecord> get matches => _filteredMatches;
  _CachedMatchRecord? get selectedMatch => _selectedMatch;
  bool get isLoading => _loading;
  String? get error => _error;
  List<_CachedMatchRecord> get allMatches => _allMatches;
  StatsFilterState get filterState => _filterState;

  // Getters per retrocompatibilità (opzionali, se usati altrove)
  StatsFilterMode get filterMode => _filterState.mode;
  DateTimeRange? get periodRange => _filterState.periodRange;
  _CachedMatchRecord? get selectedSessionMatch {
    if (_filterState.selectedSessionId == null) return null;
    try {
      return _allMatches.firstWhere((m) => m.matchId == _filterState.selectedSessionId);
    } catch (_) {
      return null;
    }
  }

  String get filterLabel => _filterState.displayLabel;
  String get modeLabel => _filterState.modeLabel;

  Future<void> loadMatches() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final allMatches = await LocalMatchSyncService.instance.getAllRecords();
      final x01Matches = allMatches
          .where((m) => m.mode == 'x01' && m.isVisible)
          .toList();

      _allMatches.clear();

      for (final match in x01Matches) {
        final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
        final playerTurns = match.playerTurns[playerId] ?? [];

        if (playerTurns.isEmpty) continue;

        int totalScore = 0;
        int totalDarts = 0;
        int checkouts = 0;
        int oneEighties = 0;
        int oneForties = 0;
        int oneHundreds = 0;
        int bestTurn = 0;
        int bestCheckout = 0;

        for (final turn in playerTurns) {
          totalScore += turn.total;
          totalDarts += turn.throws.length;

          if (turn.isCheckout) {
            checkouts++;
            if (turn.total > bestCheckout) bestCheckout = turn.total;
          }

          if (turn.total == 180) oneEighties++;
          if (turn.total >= 140) oneForties++;
          if (turn.total >= 100 && turn.total < 140) oneHundreds++;
          if (turn.total > bestTurn) bestTurn = turn.total;
        }

        final average = totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;

        _allMatches.add(_CachedMatchRecord(
          matchId: match.remoteId ?? match.localId,
          startTime: match.startTime,
          endTime: match.endTime,
          startingScore: match.gameConfig['startingScore'] ?? 501,
          winnerName: match.winnerName,
          playerTurns: playerTurns,
          totalTurns: playerTurns.length,
          totalDarts: totalDarts,
          totalScore: totalScore,
          checkouts: checkouts,
          average: average,
          oneEighties: oneEighties,
          oneForties: oneForties,
          oneHundreds: oneHundreds,
          bestTurn: bestTurn,
          bestCheckout: bestCheckout,
          originalRecord: match,
        ));
      }

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
      _filteredMatches = _allMatches.where((m) => m.matchId == _filterState.selectedSessionId).toList();
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
      _filteredMatches = _allMatches.where((m) {
        final date = m.startTime;
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(end.add(const Duration(milliseconds: 1)));
      }).toList();
    } else {
      _filteredMatches = List.from(_allMatches);
    }

    notifyListeners();
  }

  // ✅ METODO PER IMPOSTARE PERIODO
  void setPeriodRange(DateTimeRange range) {
    _filterState = StatsFilterState(
      mode: StatsFilterMode.period,
      periodRange: range,
      selectedSessionId: null,
      selectedSessionLabel: null,
    );
    _applyFilter();
  }

  // ✅ METODO PER IMPOSTARE SESSIONE
  void setSession(_CachedMatchRecord match) {
    _filterState = StatsFilterState(
      mode: StatsFilterMode.session,
      selectedSessionId: match.matchId,
      selectedSessionLabel: DateFormat('dd/MM/yyyy HH:mm').format(match.startTime),
      periodRange: null,
    );
    _applyFilter();
  }

  void selectMatch(_CachedMatchRecord match) {
    _selectedMatch = match;
    notifyListeners();
  }

  void clearSelection() {
    _selectedMatch = null;
    notifyListeners();
  }

  // STATISTICHE AGGREGATE
  int get totalMatches => _filteredMatches.length;

  double get overallAverage {
    int totalScore = 0;
    int totalDarts = 0;
    for (final match in _filteredMatches) {
      totalScore += match.totalScore;
      totalDarts += match.totalDarts;
    }
    return totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;
  }

  int get totalOneEighties {
    int count = 0;
    for (final match in _filteredMatches) {
      count += match.oneEighties;
    }
    return count;
  }

  int get totalOneForties {
    int count = 0;
    for (final match in _filteredMatches) {
      count += match.oneForties;
    }
    return count;
  }

  int get totalOneHundreds {
    int count = 0;
    for (final match in _filteredMatches) {
      count += match.oneHundreds;
    }
    return count;
  }

  double get overallCheckoutPercentage {
    int totalAttempts = 0;
    int totalCheckouts = 0;
    for (final match in _filteredMatches) {
      totalAttempts += match.totalTurns;
      totalCheckouts += match.checkouts;
    }
    return totalAttempts > 0 ? (totalCheckouts / totalAttempts) * 100 : 0.0;
  }

  int get bestTurnOverall {
    int best = 0;
    for (final match in _filteredMatches) {
      if (match.bestTurn > best) best = match.bestTurn;
    }
    return best;
  }

  int get bestCheckoutOverall {
    int best = 0;
    for (final match in _filteredMatches) {
      if (match.bestCheckout > best) best = match.bestCheckout;
    }
    return best;
  }
}
// ============================================================
// MAIN WIDGET - IDENTICO ALLA LOGICA DEL TRAINING
// ============================================================

// x01_stats_screen.dart - VERSIONE CORRETTA

class X01StatsWidget extends StatefulWidget {
  final String title;
  final bool showAppBar;

  const X01StatsWidget({super.key, required this.title, this.showAppBar = true});

  @override
  State<X01StatsWidget> createState() => _X01StatsWidgetState();
}

class _X01StatsWidgetState extends State<X01StatsWidget>
    with AutomaticKeepAliveClientMixin {
  late final X01StatsController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = X01StatsController();
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
        // ✅ setState non serve se controller notifica, ma assicuriamoci
      }
    } else {
      _openSessionPicker();
    }
  }

  Future<void> _openSessionPicker() async {
    final deletedSomething = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionPickerScreen<MatchSessionStats>(
          type: SessionType.match,
          filterBy: 'x01',
          highlightedId: _controller.filterState.selectedSessionId,
          onSelect: (session) {
            final match = _controller.allMatches.firstWhere(
                  (m) => m.matchId == session.id,
              orElse: () => _controller.allMatches.first,
            );

            _controller.setSession(match);
          },
        ),
      ),
    );

    if (deletedSomething == true) {
      await _controller.loadMatches();
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
      _openSessionPicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.showAppBar
          ? AppBar(
        title: Text(widget.title, style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.surface,
        elevation: 0,
      )
          : null,
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (ctx, _) {
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
              builder: (ctx, _) {
                if (_controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: t.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _controller.error!,
                          style: TextStyle(color: t.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _controller.loadMatches,
                          child: const Text('RIPROVA'),
                        ),
                      ],
                    ),
                  );
                }

                if (_controller.matches.isEmpty) {
                  return _StateMessage(
                    icon: Icons.sports_score_rounded,
                    title: 'Nessuna partita X01 trovata',
                    subtitle: 'Gioca almeno una partita a X01 per vedere le statistiche.',
                    color: t.textMuted,
                    t: t,
                    action: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoomLobbyPage(
                              initialGameType: GameType.x01,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Gioca a X01'),
                    ),
                  );
                }

                return _StatsPanel(controller: _controller, t: t);
              },
            ),
          ),
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textMuted,
                fontSize: 12,
              ),
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

// ============================================================
// SESSION PICKER SCREEN - IDENTICO AL TRAINING
// ============================================================

class _SessionPickerScreen extends StatefulWidget {
  final List<_CachedMatchRecord> matches;
  final String? highlightedMatchId;

  const _SessionPickerScreen({
    required this.matches,
    this.highlightedMatchId,
  });

  @override
  State<_SessionPickerScreen> createState() => _SessionPickerScreenState();
}

class _SessionPickerScreenState extends State<_SessionPickerScreen> {
  String _sortBy = 'date';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};

  List<_CachedMatchRecord> get _sortedMatches {
    final list = List<_CachedMatchRecord>.from(widget.matches);
    switch (_sortBy) {
      case 'average':
        list.sort((a, b) => b.average.compareTo(a.average));
        break;
      case 'score':
        list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
        break;
      default:
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    return list;
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
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

    final t = AppTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elimina sessioni', style: t.bodyBold(t.textPrimary)),
        content: Text(
          'Sei sicuro di voler eliminare ${_selectedIds.length} sessione${_selectedIds.length > 1 ? '?' : '?'}',
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

    await LocalMatchSyncService.instance.deleteRecords(_selectedIds.toList());

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} selezionate' : 'Sessioni X01',
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
            PopupMenuButton<String>(
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'date', child: Text('Data ↓')),
                PopupMenuItem(value: 'average', child: Text('Media ↓')),
                PopupMenuItem(value: 'score', child: Text('Punteggio ↓')),
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
      body: _sortedMatches.isEmpty
          ? Center(child: Text('Nessuna sessione', style: t.bodySmall(t.textSecondary)))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _sortedMatches.length,
        itemBuilder: (ctx, i) {
          final m = _sortedMatches[i];
          final isHighlighted = widget.highlightedMatchId == m.matchId;
          final isSelected = _selectedIds.contains(m.matchId);

          return Container(
            color: isSelected
                ? t.accent.withOpacity(0.2)
                : (isHighlighted ? t.accent.withOpacity(0.15) : null),
            child: ListTile(
              leading: _isSelectionMode
                  ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(m.matchId),
                activeColor: t.accent,
                checkColor: t.accentFg,
              )
                  : Icon(Icons.sports_score, color: t.accent),
              title: Text(
                DateFormat('dd/MM/yyyy HH:mm').format(m.startTime),
                style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary),
              ),
              subtitle: Text(
                'Media: ${m.average.toStringAsFixed(1)} · ${m.winnerName} vince',
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
              trailing: !_isSelectionMode && isHighlighted
                  ? Icon(Icons.check_circle, color: t.green)
                  : null,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(m.matchId);
                } else {
                  Navigator.pop(context, m);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
// ============================================================
// LISTA MATCH
// ============================================================


class _MatchDetailScreen extends StatelessWidget {
  final _CachedMatchRecord match;
  final AppTokens t;

  const _MatchDetailScreen({required this.match, required this.t});

  @override
  Widget build(BuildContext context) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sets = match.originalRecord.matchSets;  // ← DATI GIÀ STRUTTURATI

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Match ${match.startingScore}', style: TextStyle(color: t.textPrimary)),
        backgroundColor: t.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _InfoRow(label: 'Data', value: DateFormat('dd/MM/yyyy HH:mm').format(match.startTime), t: t),
          _InfoRow(label: 'Media', value: match.average.toStringAsFixed(1), t: t),
          const SizedBox(height: 16),

          // 🔥 ITERA DIRETTAMENTE SU matchSets
          ...sets.map((set) => _SetCard(set: set, playerId: playerId, t: t)),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final Map<String, dynamic> set;
  final String playerId;
  final AppTokens t;

  const _SetCard({required this.set, required this.playerId, required this.t});

  @override
  Widget build(BuildContext context) {
    final legs = set['legs'] as List;
    final legsWithPlayer = legs.where((leg) {
      final rounds = leg['rounds'] as List;
      return rounds.any((round) {
        final turns = round['turns'] as List;
        return turns.any((turn) => turn['playerId'] == playerId);
      });
    }).toList();

    if (legsWithPlayer.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text('SET ${set['setNumber']}', style: t.bodyBold(t.accent)),
        subtitle: Text('${legsWithPlayer.length} leg', style: t.bodySmall(t.textMuted)),
        children: legsWithPlayer.map((leg) => _LegCard(leg: leg, playerId: playerId, t: t)).toList(),
      ),
    );
  }
}

class _LegCard extends StatelessWidget {
  final Map<String, dynamic> leg;
  final String playerId;
  final AppTokens t;

  const _LegCard({required this.leg, required this.playerId, required this.t});

  @override
  Widget build(BuildContext context) {
    final rounds = leg['rounds'] as List;
    final turnsList = <PlayerTurn>[];

    for (final round in rounds) {
      final turns = round['turns'] as List;
      for (final turnMap in turns) {
        if (turnMap['playerId'] == playerId) {
          turnsList.add(PlayerTurn.fromMap(turnMap));
        }
      }
    }

    final isWon = leg['winnerId'] == playerId;
    final startScore = turnsList.isNotEmpty ? turnsList.first.initialScore : 501;
    final rows = turnsList.map((turn) => RowVm.fromTurn(turn)).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWon ? t.green.withOpacity(0.05) : t.surfaceHigh,
        borderRadius: AppTokens.r10,
        border: Border.all(color: isWon ? t.green.withOpacity(0.3) : t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Leg ${leg['legNumber']}', style: t.bodyBold(isWon ? t.green : t.textPrimary)),
              if (isWon) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: t.green, size: 16),
              ],
              const Spacer(),
              Text('${turnsList.length} turni', style: t.bodySmall(t.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          HistoryPanel(startScore: startScore, rows: rows, t: t),
        ],
      ),
    );
  }
}

// ============================================================
// UTILITIES
// ============================================================

class _InfoRow extends StatelessWidget {
  final String label, value;
  final AppTokens t;
  const _InfoRow({required this.label, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: t.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textPrimary)),
        ],
      ),
    );
  }
}
class _SessionMatchCard extends StatelessWidget {
  final _CachedMatchRecord match;
  final AppTokens t;

  const _SessionMatchCard({
    required this.match,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final dataset = playerId.isEmpty
        ? const X01DartDataset(darts: [])
        : const X01DartExtractor().extract(
      records: [match.originalRecord],
      playerId: playerId,
    );

    final turns = dataset.turns;
    final totalTurns = turns.length;
    final totalDarts = turns.fold<int>(0, (sum, turn) => sum + turn.dartsThrown);
    final totalScore = turns.fold<int>(0, (sum, turn) => sum + turn.total);
    final average = totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.r12,
        side: BorderSide(color: t.border),
      ),
      child: InkWell(
        borderRadius: AppTokens.r12,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _MatchDetailScreen(match: match, t: t),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.12),
                  borderRadius: AppTokens.r10,
                ),
                child: Icon(Icons.sports_score, color: t.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(match.startTime),
                      style: t.bodyBold(t.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vincitore: ${match.winnerName} · Media: ${average.toStringAsFixed(1)} · $totalTurns turni',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall(t.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}


class _ScorePhaseMetrics {
  final int startingScore;
  final int visits;
  final int totalScore;
  final int totalDarts;
  final int oneEighties;
  final int oneForties;
  final int oneHundreds;

  const _ScorePhaseMetrics({
    required this.startingScore,
    required this.visits,
    required this.totalScore,
    required this.totalDarts,
    required this.oneEighties,
    required this.oneForties,
    required this.oneHundreds,
  });

  double get average => totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0;

  static List<_ScorePhaseMetrics> fromMatches(List<_CachedMatchRecord> matches) {
    final grouped = <int, _MutableScorePhaseMetrics>{};

    for (final match in matches) {
      final bucket = grouped.putIfAbsent(
        match.startingScore,
            () => _MutableScorePhaseMetrics(match.startingScore),
      );

      for (final turn in match.playerTurns) {
        if (turn.initialScore <= 170) continue;

        bucket.visits++;
        bucket.totalScore += turn.total;
        bucket.totalDarts += turn.throws.length;

        if (turn.total == 180) bucket.oneEighties++;
        if (turn.total >= 140) bucket.oneForties++;
        if (turn.total >= 100 && turn.total < 140) bucket.oneHundreds++;
      }
    }

    final rows = grouped.values
        .where((m) => m.visits > 0)
        .map((m) => m.freeze())
        .toList();

    rows.sort((a, b) => a.startingScore.compareTo(b.startingScore));
    return rows;
  }
}

class _MutableScorePhaseMetrics {
  final int startingScore;
  int visits = 0;
  int totalScore = 0;
  int totalDarts = 0;
  int oneEighties = 0;
  int oneForties = 0;
  int oneHundreds = 0;

  _MutableScorePhaseMetrics(this.startingScore);

  _ScorePhaseMetrics freeze() {
    return _ScorePhaseMetrics(
      startingScore: startingScore,
      visits: visits,
      totalScore: totalScore,
      totalDarts: totalDarts,
      oneEighties: oneEighties,
      oneForties: oneForties,
      oneHundreds: oneHundreds,
    );
  }
}

class _CheckoutPhaseMetrics {
  final int startingScore;
  final int visits;
  final int totalScore;
  final int totalDarts;
  final int checkouts;
  final int bestCheckout;

  const _CheckoutPhaseMetrics({
    required this.startingScore,
    required this.visits,
    required this.totalScore,
    required this.totalDarts,
    required this.checkouts,
    required this.bestCheckout,
  });

  double get average => totalDarts > 0 ? (totalScore / totalDarts) * 3 : 0;
  double get checkoutRate => visits > 0 ? (checkouts / visits) * 100 : 0;

  static List<_CheckoutPhaseMetrics> fromMatches(List<_CachedMatchRecord> matches) {
    final grouped = <int, _MutableCheckoutPhaseMetrics>{};

    for (final match in matches) {
      final bucket = grouped.putIfAbsent(
        match.startingScore,
            () => _MutableCheckoutPhaseMetrics(match.startingScore),
      );

      for (final turn in match.playerTurns) {
        if (turn.initialScore > 170) continue;

        bucket.visits++;
        bucket.totalScore += turn.total;
        bucket.totalDarts += turn.throws.length;

        if (turn.isCheckout) {
          bucket.checkouts++;
          if (turn.total > bucket.bestCheckout) {
            bucket.bestCheckout = turn.total;
          }
        }
      }
    }

    final rows = grouped.values
        .where((m) => m.visits > 0)
        .map((m) => m.freeze())
        .toList();

    rows.sort((a, b) => a.startingScore.compareTo(b.startingScore));
    return rows;
  }
}

class _MutableCheckoutPhaseMetrics {
  final int startingScore;
  int visits = 0;
  int totalScore = 0;
  int totalDarts = 0;
  int checkouts = 0;
  int bestCheckout = 0;

  _MutableCheckoutPhaseMetrics(this.startingScore);

  _CheckoutPhaseMetrics freeze() {
    return _CheckoutPhaseMetrics(
      startingScore: startingScore,
      visits: visits,
      totalScore: totalScore,
      totalDarts: totalDarts,
      checkouts: checkouts,
      bestCheckout: bestCheckout,
    );
  }
}




// ============================================================
// PANNELLO STATISTICHE
// ============================================================

class _StatsPanel extends StatelessWidget {
  final X01StatsController controller;
  final AppTokens t;

  const _StatsPanel({required this.controller, required this.t});

  @override
  Widget build(BuildContext context) {
    final sessionMatch = controller.filterState.mode == StatsFilterMode.session
        ? controller.selectedSessionMatch
        : null;

    return CustomScrollView(
      cacheExtent: 2500,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                if (sessionMatch != null)
                  RepaintBoundary(
                    child: _SessionMatchCard(match: sessionMatch, t: t),
                  ),

                RepaintBoundary(
                  child: X01SummaryTable(matches: controller.matches),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _TurnScoreDistributionTable(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 24),

                RepaintBoundary(
                  child: _LegTurnsByGameTowerChart(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 24),

                RepaintBoundary(
                  child: _ScoringVisitDartAverageTable(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _buildScoringVisitTrendChart(controller.matches),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _buildScoringDartTrendChart(
                    matches: controller.matches,
                    dartIndex: 0,
                    title: 'ANDAMENTO 1ª FRECCETTA',
                    yAxisLabel: 'punti 1ª freccetta',
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _buildScoringDartTrendChart(
                    matches: controller.matches,
                    dartIndex: 1,
                    title: 'ANDAMENTO 2ª FRECCETTA',
                    yAxisLabel: 'punti 2ª freccetta',
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _buildScoringDartTrendChart(
                    matches: controller.matches,
                    dartIndex: 2,
                    title: 'ANDAMENTO 3ª FRECCETTA',
                    yAxisLabel: 'punti 3ª freccetta',
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _CheckoutVisitDartAverageTable(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _CheckoutScoreTowerChart(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _CheckoutSectorTowerChart(
                    matches: controller.matches,
                    t: t,
                  ),
                ),

                const SizedBox(height: 12),

                RepaintBoundary(
                  child: _CheckoutOpportunityBySectorTable(
                    matches: controller.matches,
                    t: t,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoringVisitTrendChart(List<_CachedMatchRecord> matches) {
    final source = _ScoringVisitAveragePoint.fromMatches(matches);

    if (source.isEmpty) return const SizedBox.shrink();

    final points = source
        .map(
          (point) => UnifiedStatsPoint(
        x: point.visitProgressive.toDouble(),
        y: point.average,
        label: 'Visit ${point.visitProgressive}',
        detail: 'Visit ${point.visitProgressive}: ${point.average.toStringAsFixed(1)} punti',
      ),
    )
        .toList();

    return UnifiedStatsChart(
      title: 'ANDAMENTO TURNI SCORING',
      subtitle: 'Punti dei turni in fase scoring.',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: 'turno',
      yAxisLabel: 'punti turno',
      minYValue: 0,
      height: 320,
      infoTitle:
      'Come leggere l’andamento dello scoring.',
      infoText:
      'Il grafico mostra l’andamento dei turni giocati durante la fase di scoring del leg.\n\n'

          'La linea aiuta a capire continuità, stabilità e cali di ritmo durante la costruzione del leg.\n\n',

      footerText:
      'Osserva come costruisci il leg nel tempo: continuità, cali di ritmo e qualità dello scoring determinano velocità, pressione e ingresso in checkout.',

      advice: [
        'Una linea stabile indica continuità di scoring e buona costruzione del leg.',

        'Forti oscillazioni tra turni alti e bassi indicano instabilità nel ritmo di scoring.',

        'Se il grafico parte forte ma cala rapidamente, probabilmente perdi qualità man mano che il leg avanza.',

        'Se migliori nei turni finali della discesa, entri progressivamente nel ritmo partita dopo le prime visite.',

        'Turni molto bassi ripetuti rallentano l’ingresso in checkout e aumentano pressione sulla fase finale.',

        'Confronta questo grafico con i turni zona checkout: una buona discesa dovrebbe ridurre il numero di turni necessari per entrare in chiusura.',

        'Quando la discesa è lenta ma il checkout resta efficiente, il problema principale è nella produzione punti iniziale e non nella chiusura.',
      ],
    );
  }

  Widget _buildScoringDartTrendChart({
    required List<_CachedMatchRecord> matches,
    required int dartIndex,
    required String title,
    required String yAxisLabel,
  }) {
    final source = _ScoringDartAveragePoint.fromMatches(
      matches: matches,
      dartIndex: dartIndex,
    );

    if (source.isEmpty) return const SizedBox.shrink();

    final points = source
        .map(
          (point) => UnifiedStatsPoint(
        x: point.visitProgressive.toDouble(),
        y: point.value,
        label: 'Turno ${point.visitProgressive}',
        detail: 'Turno ${point.visitProgressive}: ${point.value.toStringAsFixed(0)} punti',
      ),
    )
        .toList();

    return UnifiedStatsChart(
      title: title,
      subtitle: 'Andamento per singola freccetta nei turni di scoring.',
      points: points,
      mode: UnifiedStatsChartMode.lineAndPoints,
      xAxisLabel: 'visit',
      yAxisLabel: yAxisLabel,
      minYValue: 0,
      maxYValue: 60,
      height: 320,
      infoTitle: 'Come leggere il grafico',
      infoText: 'Mostra la stabilità della singola freccetta nei turni di scoring.',
      advice: const [
        'Punti alti e ravvicinati indicano continuità.',
        'Cadute frequenti indicano perdita di controllo su quella freccetta.',
        'Confronta 1ª, 2ª e 3ª freccetta per capire dove cala o aumenta la precisione.',
      ],
    );
  }
}

class _TurnScoreDistributionRow {
  final int score;
  final int count;
  final int totalTurns;
  final int totalLegs;
  final int legsWithScore;

  const _TurnScoreDistributionRow({
    required this.score,
    required this.count,
    required this.totalTurns,
    required this.totalLegs,
    required this.legsWithScore,
  });

  double get turnsPerHit => count > 0 ? (totalTurns / count) : 0;
  double get avgPerLeg => totalLegs > 0 ? (count / totalLegs) : 0;

  static List<_TurnScoreDistributionRow> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final finishedLegs = dataset.legs.where((leg) => leg.isFinished).toList();
    final turns = dataset.turns;

    if (turns.isEmpty || finishedLegs.isEmpty) return const [];

    final scoreCounts = <int, int>{};
    final legScorePresence = <int, Set<String>>{};

    for (final turn in turns) {
      if (turn.total <= 0) continue;

      scoreCounts[turn.total] = (scoreCounts[turn.total] ?? 0) + 1;
    }

    for (final leg in finishedLegs) {
      final legKey = leg.key;
      final scoresInLeg = <int>{};

      for (final turn in leg.turns) {
        if (turn.total <= 0) continue;
        scoresInLeg.add(turn.total);
      }

      for (final score in scoresInLeg) {
        legScorePresence.putIfAbsent(score, () => <String>{}).add(legKey);
      }
    }

    final rows = scoreCounts.entries.map((entry) {
      return _TurnScoreDistributionRow(
        score: entry.key,
        count: entry.value,
        totalTurns: turns.length,
        totalLegs: finishedLegs.length,
        legsWithScore: legScorePresence[entry.key]?.length ?? 0,
      );
    }).toList();

    rows.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.count.compareTo(a.count);
    });

    return rows;
  }
}

class _TurnScoreDistributionTable extends StatefulWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _TurnScoreDistributionTable({
    required this.matches,
    required this.t,
  });

  @override
  State<_TurnScoreDistributionTable> createState() => _TurnScoreDistributionTableState();
}

class _TurnScoreDistributionTableState extends State<_TurnScoreDistributionTable> {
  int _sortColumnIndex = 0;
  bool _sortDescending = true;

  @override
  Widget build(BuildContext context) {
    final rows = _sortedRows(_TurnScoreDistributionRow.fromMatches(widget.matches));

    if (rows.isEmpty) return const SizedBox.shrink();

    return UnifiedStatsCard(
      title: 'DISTRIBUZIONE PUNTEGGI TURNO',
      subtitle: 'Analizza i punteggi che produci più spesso.',
      info: const UnifiedStatsInfoData(
        title: 'Come leggere la tabella',
        text:
        'Ogni riga rappresenta un punteggio ottenuto in partita.\n\n'
            'La tabella serve a capire quali punteggi fanno davvero parte del tuo gioco reale, quanto sono stabili e quanto spesso riesci a ripeterli sotto pressione.\n\n'
            'Tot → quante volte realizzi quel punteggio.\n\n'
            '1 ogni X turni → frequenza reale del punteggio nelle partite.\n\n'
            'AVG/Leg → quanto spesso quel punteggio compare mediamente in un leg.\n\n'
            'I punteggi molto frequenti rappresentano le tue abitudini reali di scoring: possono essere punti forti da sfruttare oppure errori ricorrenti da correggere.',

        advice: [
          'I punteggi più frequenti rappresentano il tuo livello reale sotto pressione partita, non il tuo massimo teorico.',

          'Se i punteggi medi dominano la tabella ma i punteggi alti compaiono raramente, il tuo scoring è stabile ma poco aggressivo.',

          'Se compaiono spesso punteggi sporchi come 26, 41 o 45, abbassa il rischio: cerca prima stabilità sul 20 singolo, poi torna a forzare il triplo.',

          'I punteggi che riesci a ripetere spesso sono quelli su cui puoi costruire il tuo ritmo partita senza forzare.',

          'Se un punteggio alto compare raramente, non dovrebbe ancora diventare il centro del tuo gioco sotto pressione.',

          'Ordina "1 ogni X turni": più il numero è basso, più quel punteggio appartiene davvero al tuo scoring abituale.',

          'Usa la tabella per capire quali numeri puoi aspettarti realisticamente durante un leg, e quali invece richiedono ancora troppo sforzo o precisione.',
        ],

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: widget.t.surfaceHigh,
              border: Border(
                top: BorderSide(color: widget.t.divider),
                bottom: BorderSide(color: widget.t.divider),
              ),
            ),
            child: _buildSortableTable(rows),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.table_chart_rounded, color: widget.t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ordina le colonne per individuare rapidamente i punteggi che definiscono il tuo ritmo di scoring.',
                    style: widget.t.bodySmall(widget.t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TurnScoreDistributionRow> _sortedRows(List<_TurnScoreDistributionRow> rows) {
    final sorted = List<_TurnScoreDistributionRow>.from(rows);

    sorted.sort((a, b) {
      final comparison = _compareRows(a, b, _sortColumnIndex);
      return _sortDescending ? -comparison : comparison;
    });

    return sorted;
  }

  int _compareRows(
      _TurnScoreDistributionRow a,
      _TurnScoreDistributionRow b,
      int columnIndex,
      ) {
    switch (columnIndex) {
      case 0:
        return a.score.compareTo(b.score);
      case 1:
        return a.count.compareTo(b.count);
      case 2:
        return a.turnsPerHit.compareTo(b.turnsPerHit);
      case 3:
        return a.avgPerLeg.compareTo(b.avgPerLeg);
      default:
        return a.score.compareTo(b.score);
    }
  }

  void _setSortColumn(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortDescending = true;
      }
    });
  }

  Widget _buildSortableTable(List<_TurnScoreDistributionRow> rows) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: Column(
        children: [
          _buildHeaderRow(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: rows.map(_buildDataRow).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: widget.t.accent.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: widget.t.divider)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Score', 0),
          _buildHeaderCell('Tot', 1),
          _buildHeaderCell('1 ogni X turni', 2),
          _buildHeaderCell('AVG/Leg', 3),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int columnIndex) {
    final active = _sortColumnIndex == columnIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _setSortColumn(columnIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: widget.t.divider)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: widget.t.labelCaps(active ? widget.t.accent : widget.t.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                active
                    ? (_sortDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: active ? widget.t.accent : widget.t.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(_TurnScoreDistributionRow row) {
    return Row(
      children: [
        _buildDataCell('${row.score}', highlight: true),
        _buildDataCell('${row.count}'),
        _buildDataCell(row.count == 0 ? '-' : row.turnsPerHit.toStringAsFixed(2)),
        _buildDataCell(row.avgPerLeg.toStringAsFixed(2)),
      ],
    );
  }

  Widget _buildDataCell(String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: widget.t.divider),
            bottom: BorderSide(color: widget.t.divider),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: widget.t.bodySmall(highlight ? widget.t.accent : widget.t.textPrimary),
        ),
      ),
    );
  }
}

class _ScoringVisitDartAverageTable extends StatelessWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _ScoringVisitDartAverageTable({
    required this.matches,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _ScoringVisitDartAverageMetrics.fromMatches(matches);

    return UnifiedStatsCard(
      title: 'FASE SCORING',
      subtitle: 'AVG Turni e freccette, per arrivare in zona checkout.',
      info: const UnifiedStatsInfoData(
        title: 'Come leggere la fase di scoring',
        text:
            'Turni/leg → quanti turni di scoring ti servono mediamente prima di arrivare in zona checkout.\n\n'
                'Punti/turno → punteggio medio delle 3 freccette nei turni.\n\n'
                '1ª, 2ª e 3ª freccetta → mostrano come cambia la qualità di ogni freccetta.',
        advice: [
          'Se Turni/leg è alto, impieghi troppo tempo per arrivare in zona checkout: il problema è nella costruzione del leg.',
          'Se la 1ª freccetta è buona ma la 2ª e la 3ª calano, perdi continuità dopo il primo lancio.',
          'Se la 1ª freccetta è bassa ma migliori con 2ª e 3ª, parti posizionato male e tendi poi a correggerti durante il turno.',
          'Se tutte e tre le freccette sono basse, il problema non è una singola freccetta: è il ritmo generale di scoring.',
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
                    _MetricCell(label: 'Turni/leg', value: metrics.scoringVisitsPerLegText, t: t),
                    _MetricCell(label: 'Punti/turno', value: metrics.visitAverageText, t: t),
                  ],
                ),
                Row(
                  children: [
                    _MetricCell(label: '1ª freccetta', value: metrics.firstDartAverageText, t: t),
                    _MetricCell(label: '2ª freccetta', value: metrics.secondDartAverageText, t: t),
                    _MetricCell(label: '3ª freccetta', value: metrics.thirdDartAverageText, t: t),
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
                Icon(Icons.stacked_line_chart_rounded, color: t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leggi lo scoring come fase di costruzione: quanti turni ti servono e quale freccetta sostiene o rompe il ritmo.',
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
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;

  const _MetricCell({
    required this.label,
    required this.value,
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
            top: BorderSide(color: t.divider),
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
                color: t.textPrimary,
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

class _ScoringVisitDartAverageMetrics {
  final double scoringVisitsPerLeg;
  final double visitAverage;
  final double firstDartAverage;
  final double secondDartAverage;
  final double thirdDartAverage;

  const _ScoringVisitDartAverageMetrics({
    required this.scoringVisitsPerLeg,
    required this.visitAverage,
    required this.firstDartAverage,
    required this.secondDartAverage,
    required this.thirdDartAverage,
  });

  String get scoringVisitsPerLegText => scoringVisitsPerLeg.toStringAsFixed(2);
  String get visitAverageText => visitAverage.toStringAsFixed(1);
  String get firstDartAverageText => firstDartAverage.toStringAsFixed(1);
  String get secondDartAverageText => secondDartAverage.toStringAsFixed(1);
  String get thirdDartAverageText => thirdDartAverage.toStringAsFixed(1);

  static _ScoringVisitDartAverageMetrics fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) {
      return const _ScoringVisitDartAverageMetrics(
        scoringVisitsPerLeg: 0,
        visitAverage: 0,
        firstDartAverage: 0,
        secondDartAverage: 0,
        thirdDartAverage: 0,
      );
    }

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final scoringLegs = dataset.legs
        .where((leg) => leg.isFinished && leg.startingScore > 170)
        .toList();

    final scoringTurns = scoringLegs
        .expand((leg) => leg.scoringTurns)
        .toList();

    final scoringDarts = scoringTurns
        .expand((turn) => turn.darts)
        .toList();

    final scoringVisitsPerLeg = scoringLegs.isEmpty
        ? 0.0
        : scoringLegs.fold<int>(
      0,
          (sum, leg) => sum + leg.scoringTurns.length,
    ) /
        scoringLegs.length;

    final firstDarts = scoringDarts.where((dart) => dart.isFirstDart).toList();
    final secondDarts = scoringDarts.where((dart) => dart.isSecondDart).toList();
    final thirdDarts = scoringDarts.where((dart) => dart.isThirdDart).toList();

    return _ScoringVisitDartAverageMetrics(
      scoringVisitsPerLeg: scoringVisitsPerLeg,
      visitAverage: _averageTurns(scoringTurns),
      firstDartAverage: _averageDarts(firstDarts),
      secondDartAverage: _averageDarts(secondDarts),
      thirdDartAverage: _averageDarts(thirdDarts),
    );
  }

  static double _averageTurns(List<X01TurnSlice> turns) {
    if (turns.isEmpty) return 0;
    final total = turns.fold<int>(0, (sum, turn) => sum + turn.total);
    return total / turns.length;
  }

  static double _averageDarts(List<X01DartAtom> darts) {
    if (darts.isEmpty) return 0;
    final total = darts.fold<int>(0, (sum, dart) => sum + dart.dartScore);
    return total / darts.length;
  }
}

class _ScoringVisitAveragePoint {
  final int visitProgressive;
  final double average;

  const _ScoringVisitAveragePoint({
    required this.visitProgressive,
    required this.average,
  });

  static List<_ScoringVisitAveragePoint> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final turns = dataset.turns.where((turn) => turn.isScoringZone).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return List<_ScoringVisitAveragePoint>.generate(turns.length, (index) {
      final turn = turns[index];

      return _ScoringVisitAveragePoint(
        visitProgressive: index + 1,
        average: turn.total.toDouble(),
      );
    });
  }
}



class _ScoringDartAveragePoint {
  final int visitProgressive;
  final double value;

  const _ScoringDartAveragePoint({
    required this.visitProgressive,
    required this.value,
  });

  static List<_ScoringDartAveragePoint> fromMatches({
    required List<_CachedMatchRecord> matches,
    required int dartIndex,
  }) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final turns = dataset.turns.where((turn) => turn.isScoringZone).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final points = <_ScoringDartAveragePoint>[];

    for (int i = 0; i < turns.length; i++) {
      final turn = turns[i];

      if (turn.darts.length <= dartIndex) continue;

      points.add(
        _ScoringDartAveragePoint(
          visitProgressive: i + 1,
          value: turn.darts[dartIndex].dartScore.toDouble(),
        ),
      );
    }

    return points;
  }
}




class _CheckoutVisitDartAverageTable extends StatelessWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _CheckoutVisitDartAverageTable({
    required this.matches,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _CheckoutVisitDartAverageMetrics.fromMatches(matches);

    return UnifiedStatsCard(
      title: 'FASE CHIUSURA',
      subtitle: 'Punteggio in fase di checkout e % della freccetta che chiude.',
      footerIcon: Icons.check_circle_outline_rounded,
      footerText:
      'Osserva come gestisci il finale del leg: qualità del checkout, numero di turni necessari e freccetta con cui riesci davvero a chiudere.',

      info: const UnifiedStatsInfoData(
        title: 'Come leggere la fase di chiusura',
        text:
            'Turno medio → punteggio medio prodotto nei turni di chiusura.\n\n'
            'AVG turni close → quanti turni servono mediamente per completare la fase di checkout e chiudere.\n\n'
            '1ª, 2ª e 3ª freccetta punti → rendimento medio delle singole freccette in zona checkout.\n\n'
            'Close 1ª, 2ª e 3ª → con quale freccetta chiudi più spesso.',
        advice: [
          'Se AVG turni close è alto, arrivi in checkout ma impieghi troppi turni per chiudere.',
          'Se i punti delle freccette sono bassi, la zona checkout non sta creando abbastanza pressione.',
          'Se una freccetta ha una percentuale close molto più alta, probabilmente è quella con cui sei più lucido o più stabile sul doppio.',
          'Se chiudi poco con la 3ª freccetta, potresti perdere qualità dopo i primi errori del turno.',
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
                    _MetricCell(label: 'Turni/leg', value: metrics.avgVisitsToCloseText, t: t),
                    _MetricCell(label: 'Punti/turno', value: metrics.visitAverageText, t: t),
                  ],
                ),
                Row(
                  children: [
                    _MetricCell(label: 'Punti 1ª', value: metrics.firstDartAverageText, t: t),
                    _MetricCell(label: 'Punti 2ª', value: metrics.secondDartAverageText, t: t),
                    _MetricCell(label: 'Punti 3ª', value: metrics.thirdDartAverageText, t: t),
                  ],
                ),
                Row(
                  children: [
                    _MetricCell(label: 'Close 1ª', value: metrics.firstDartCheckoutRateText, t: t),
                    _MetricCell(label: 'Close 2ª', value: metrics.secondDartCheckoutRateText, t: t),
                    _MetricCell(label: 'Close 3ª', value: metrics.thirdDartCheckoutRateText, t: t),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _CheckoutVisitDartAverageMetrics {
  final double avgVisitsToClose;
  final double visitAverage;
  final double firstDartAverage;
  final double secondDartAverage;
  final double thirdDartAverage;
  final double firstDartCheckoutRate;
  final double secondDartCheckoutRate;
  final double thirdDartCheckoutRate;

  const _CheckoutVisitDartAverageMetrics({
    required this.avgVisitsToClose,
    required this.visitAverage,
    required this.firstDartAverage,
    required this.secondDartAverage,
    required this.thirdDartAverage,
    required this.firstDartCheckoutRate,
    required this.secondDartCheckoutRate,
    required this.thirdDartCheckoutRate,
  });

  String get avgVisitsToCloseText => avgVisitsToClose.toStringAsFixed(1);
  String get visitAverageText => visitAverage.toStringAsFixed(1);
  String get firstDartAverageText => firstDartAverage.toStringAsFixed(1);
  String get secondDartAverageText => secondDartAverage.toStringAsFixed(1);
  String get thirdDartAverageText => thirdDartAverage.toStringAsFixed(1);
  String get firstDartCheckoutRateText => '${firstDartCheckoutRate.toStringAsFixed(0)}%';
  String get secondDartCheckoutRateText => '${secondDartCheckoutRate.toStringAsFixed(0)}%';
  String get thirdDartCheckoutRateText => '${thirdDartCheckoutRate.toStringAsFixed(0)}%';

  static _CheckoutVisitDartAverageMetrics fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) {
      return const _CheckoutVisitDartAverageMetrics(
        avgVisitsToClose: 0,
        visitAverage: 0,
        firstDartAverage: 0,
        secondDartAverage: 0,
        thirdDartAverage: 0,
        firstDartCheckoutRate: 0,
        secondDartCheckoutRate: 0,
        thirdDartCheckoutRate: 0,
      );
    }

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final checkoutTurns = dataset.turns.where((turn) => turn.isCheckoutZone).toList();
    final checkoutDarts = dataset.checkoutZoneDarts;

    final closedLegs = dataset.legs
        .where((leg) => leg.isFinished && leg.isWon)
        .toList();

    final totalCheckoutVisits = closedLegs.fold<int>(
      0,
          (sum, leg) => sum + leg.checkoutTurns.length,
    );

    final firstDarts = checkoutDarts.where((dart) => dart.isFirstDart).toList();
    final secondDarts = checkoutDarts.where((dart) => dart.isSecondDart).toList();
    final thirdDarts = checkoutDarts.where((dart) => dart.isThirdDart).toList();

    final checkoutFinishDarts = checkoutDarts.where((dart) => dart.isCheckoutDart).toList();
    final checkoutFinishCount = checkoutFinishDarts.length;

    final firstCloseCount = checkoutFinishDarts.where((dart) => dart.isFirstDart).length;
    final secondCloseCount = checkoutFinishDarts.where((dart) => dart.isSecondDart).length;
    final thirdCloseCount = checkoutFinishDarts.where((dart) => dart.isThirdDart).length;

    return _CheckoutVisitDartAverageMetrics(
      avgVisitsToClose: closedLegs.isNotEmpty ? totalCheckoutVisits / closedLegs.length : 0,
      visitAverage: _averageTurns(checkoutTurns),
      firstDartAverage: _averageDarts(firstDarts),
      secondDartAverage: _averageDarts(secondDarts),
      thirdDartAverage: _averageDarts(thirdDarts),
      firstDartCheckoutRate: _percentage(firstCloseCount, checkoutFinishCount),
      secondDartCheckoutRate: _percentage(secondCloseCount, checkoutFinishCount),
      thirdDartCheckoutRate: _percentage(thirdCloseCount, checkoutFinishCount),
    );
  }

  static double _averageTurns(List<X01TurnSlice> turns) {
    if (turns.isEmpty) return 0;
    final total = turns.fold<int>(0, (sum, turn) => sum + turn.total);
    return total / turns.length;
  }

  static double _averageDarts(List<X01DartAtom> darts) {
    if (darts.isEmpty) return 0;
    final total = darts.fold<int>(0, (sum, dart) => sum + dart.dartScore);
    return total / darts.length;
  }

  static double _percentage(int value, int total) {
    if (total <= 0) return 0;
    return (value / total) * 100;
  }
}


class _CheckoutScoreTowerChart extends StatelessWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _CheckoutScoreTowerChart({
    required this.matches,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final bars = _CheckoutScoreTowerBar.fromMatches(matches);

    if (bars.isEmpty) return const SizedBox.shrink();

    final orderedBars = List<_CheckoutScoreTowerBar>.from(bars)
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return b.score.compareTo(a.score);
      });

    return UnifiedStatsTowerChart(
      title: 'PUNTEGGI CHIUSI',
      subtitle: 'Distribuzione dei checkout completati.',
      yAxisLabel: 'chiusure',
      height: 320,
      showTargetLines: false,
      footerText:
      'Osserva quali checkout chiudi maggiormente e con più successo: i punteggi ricorrenti mostrano abitudini, stabilità, sicurezza.',
      infoTitle: 'Come leggere i punteggi chiusi',
      infoText:
      'Ogni torre rappresenta un punteggio chiuso.\n\n'
          'Più alta è la torre, più spesso hai chiuso con quel punteggio.\n\n'
          'Il grafico serve a capire quali punteggi chiudi con continuità e con piu efficacia.',
      advice: const [
        'Le torri più alte indicano i checkout che trasformi con maggiore naturalezza.',
        'I punteggi assenti o bassi mostrano chiusure poco allenate, poco raggiunte o poco convertite.',
        'Se chiudi sempre gli stessi punteggi, costruisci routine solide.',
        'Usa questo dato per programmarti in partita un checkout strategico.',
      ],
      groups: orderedBars
          .map(
            (bar) => UnifiedStatsTowerGroup(
          xLabel: '${bar.score}',
          values: [
            UnifiedStatsTowerValue(
              label: 'checkout',
              value: bar.count.toDouble(),
              topLabel: '${bar.count}',
              color: t.accent,
            ),
          ],
        ),
      )
          .toList(),
    );
  }
}


class _CheckoutScoreTowerBar {
  final int score;
  final int count;

  const _CheckoutScoreTowerBar({
    required this.score,
    required this.count,
  });

  static List<_CheckoutScoreTowerBar> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final counts = <int, int>{};

    for (final turn in dataset.turns) {
      if (!turn.isCheckout) continue;

      final score = turn.initialScore;
      if (score < 1 || score > 180) continue;

      counts[score] = (counts[score] ?? 0) + 1;
    }

    final bars = counts.entries
        .map((entry) => _CheckoutScoreTowerBar(score: entry.key, count: entry.value))
        .toList();

    bars.sort((a, b) => a.score.compareTo(b.score));
    return bars;
  }
}


class _CheckoutSectorTowerChart extends StatelessWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _CheckoutSectorTowerChart({
    required this.matches,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final bars = _CheckoutSectorTowerBar.fromMatches(matches);

    if (bars.isEmpty) return const SizedBox.shrink();

    final orderedBars = List<_CheckoutSectorTowerBar>.from(bars)
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.label.compareTo(b.label);
      });

    return UnifiedStatsTowerChart(
      title: 'SETTORI DI CHIUSURA',
      subtitle: 'Distribuzione dei settori usati per chiudere.',
      yAxisLabel: 'chiusure',
      height: 320,
      showTargetLines: false,
      footerText:
      'Osserva quali settori usi davvero per chiudere: le torri più alte mostrano i settori con cui chiudi maggiormente.',
      infoTitle: 'Come leggere i settori di chiusura',
      infoText:
      'Ogni torre rappresenta un settore con cui hai chiuso un leg.\n\n'
          'Più alta è la torre, più quel settore è stato utilizzato.\n\n'
          'Il grafico serve a capire quali settori sono più naturali per te e quali invece compaiono poco.',
      advice: const [
        'Le torri più alte indicano i settori di chiusura più affidabili nel tuo stile di gioco.',
        'I settori assenti o bassi possono indicare doppi poco raggiunti, poco allenati o poco convertiti.',
        'Se dipendi sempre dagli stessi doppi, costruisci fiducia, ma rischi di soffrire checkout alternativi.',
        'Usa questo dato per allenare prima i settori che incontri davvero più spesso in partita.',
        'Se sono settori piccoli, allenati sui settori strategici di chiusura (D20, S16, D8) per chiudere in meno turni.',
      ],
      groups: orderedBars
          .map(
            (bar) => UnifiedStatsTowerGroup(
          xLabel: bar.label,
          values: [
            UnifiedStatsTowerValue(
              label: 'checkout',
              value: bar.count.toDouble(),
              topLabel: '${bar.count}',
              color: t.accent,
            ),
          ],
        ),
      )
          .toList(),
    );
  }
}


class _CheckoutSectorTowerBar {
  final String label;
  final int count;

  const _CheckoutSectorTowerBar({
    required this.label,
    required this.count,
  });

  static List<_CheckoutSectorTowerBar> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final counts = <String, int>{};

    for (final dart in dataset.checkoutDarts) {
      counts[dart.dartLabel] = (counts[dart.dartLabel] ?? 0) + 1;
    }

    final bars = counts.entries
        .map((entry) => _CheckoutSectorTowerBar(label: entry.key, count: entry.value))
        .toList();

    bars.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.compareTo(b.label);
    });

    return bars;
  }
}

class _LegTurnsByGameTowerChart extends StatelessWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _LegTurnsByGameTowerChart({
    required this.matches,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _LegTurnsByGameGroup.fromMatches(matches);

    if (groups.isEmpty) return const SizedBox.shrink();

    return UnifiedStatsTowerChart(
      title: 'TURNI PER LEG',
      subtitle:
      'Confronta come costruisci e chiudi i leg vinti e persi.',
      yAxisLabel: 'turni',
      height: 260,
      showTargetLines: true,
      customLegend: [
        ('Vinti', t.green),
        ('Persi', t.red),
        ('Scoring', t.textMuted.withOpacity(0.9)),
        ('Checkout', t.textMuted.withOpacity(0.38)),
      ],
      footerText:
      'Confronta i ritmi tra leg vinti e persi, tra scoring e checkout.',
      infoTitle:
      'Come leggere i turni per leg',
      infoText:
      'Ogni torre rappresenta il ritmo medio di un leg.\n\n'

          'La parte scura mostra i turni di discesa necessari per arrivare in zona checkout.\n\n'

          'La parte chiara mostra invece i turni giocati in checkout prima della chiusura o della sconfitta del leg.\n\n'

          'Le torri verdi rappresentano i leg vinti, le rosse i leg persi.\n\n'

          'Il numero sopra la torre indica i turni medi totali del leg, mentre sotto viene mostrata la media punti.\n\n'

          'Confrontando vinti e persi puoi capire se il leg viene perso soprattutto nella fase di scoring oppure nella conversione finale del checkout.',

      advice: [
        'Se nei leg persi la parte scura è molto più alta, il problema principale è la discesa: perdi terreno prima ancora di entrare realmente in checkout.',

        'Se le parti scure sono simili tra vinti e persi, ma la parte checkout cresce molto nei persi, il problema è soprattutto nella chiusura finale.',

        'Checkout molto lunghi nei leg persi spesso indicano blocchi sui doppi, setup poco efficienti o difficoltà sotto pressione.',

        'Quando arrivi in checkout con lo stesso ritmo dei leg vinti ma perdi comunque il leg, probabilmente stai lasciando troppi turni extra in chiusura.',

        'Torri basse con AVG alta indicano leg puliti, ritmo forte e buona continuità di scoring.',

        'Torri molto alte sia nei vinti che nei persi indicano partite lente e tanti turni sprecati durante il leg.',

        'Confronta i livelli 15, 18, 21 e 24 dart: aiutano a capire il ritmo reale del tuo gioco sui diversi X01.',

        'Se i leg persi terminano spesso vicino ai tuoi tempi medi vincenti, le partite sono equilibrate e la differenza è nei dettagli finali.',
      ],

      groups: groups
          .map(
            (group) => UnifiedStatsTowerGroup(
          xLabel: '${group.startingScore}',
          values: [
            if (group.wonLegs > 0)
              UnifiedStatsTowerValue(
                label: 'vinti',
                value: group.wonTurnsAverage,
                topLabel: '${group.wonTurnsAverage.toStringAsFixed(1)} T',
                subTopLabel: '${group.wonScoreAverage.toStringAsFixed(1)} AVG',
                color: t.green,
                segments: [
                  UnifiedStatsTowerSegment(
                    label: 'discesa',
                    value: group.wonScoringTurnsAverage,
                    color: t.green,
                  ),
                  UnifiedStatsTowerSegment(
                    label: 'checkout',
                    value: group.wonCheckoutTurnsAverage,
                    color: t.green.withOpacity(0.38),
                  ),
                ],
              ),
            if (group.lostLegs > 0)
              UnifiedStatsTowerValue(
                label: 'persi',
                value: group.lostTurnsAverage,
                topLabel: '${group.lostTurnsAverage.toStringAsFixed(1)} T',
                subTopLabel: '${group.lostScoreAverage.toStringAsFixed(1)} AVG',
                color: t.red,
                segments: [
                  UnifiedStatsTowerSegment(
                    label: 'discesa',
                    value: group.lostScoringTurnsAverage,
                    color: t.red,
                  ),
                  UnifiedStatsTowerSegment(
                    label: 'checkout',
                    value: group.lostCheckoutTurnsAverage,
                    color: t.red.withOpacity(0.38),
                  ),
                ],
              ),
          ],
        ),
      )
          .toList(),
    );
  }
}

class _LegTurnsByGameGroup {
  final int startingScore;
  final double wonTurnsAverage;
  final double lostTurnsAverage;
  final double wonScoringTurnsAverage;
  final double wonCheckoutTurnsAverage;
  final double lostScoringTurnsAverage;
  final double lostCheckoutTurnsAverage;
  final double wonScoreAverage;
  final double lostScoreAverage;
  final int wonLegs;
  final int lostLegs;

  const _LegTurnsByGameGroup({
    required this.startingScore,
    required this.wonTurnsAverage,
    required this.lostTurnsAverage,
    required this.wonScoringTurnsAverage,
    required this.wonCheckoutTurnsAverage,
    required this.lostScoringTurnsAverage,
    required this.lostCheckoutTurnsAverage,
    required this.wonScoreAverage,
    required this.lostScoreAverage,
    required this.wonLegs,
    required this.lostLegs,
  });

  static List<_LegTurnsByGameGroup> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final grouped = <int, _MutableLegTurnsByGameGroup>{};

    for (final leg in dataset.legs) {
      if (!leg.isFinished) continue;

      final bucket = grouped.putIfAbsent(
        leg.startingScore,
            () => _MutableLegTurnsByGameGroup(leg.startingScore),
      );

      final turns = leg.turns;
      final turnsCount = turns.length;
      final scoringTurnsCount = leg.scoringTurns.length;
      final checkoutTurnsCount = leg.checkoutTurns.length;
      final turnScoreTotal = turns.fold<int>(0, (sum, turn) => sum + turn.total);

      if (leg.isWon) {
        bucket.wonLegs++;
        bucket.wonTurnsTotal += turnsCount;
        bucket.wonScoringTurnsTotal += scoringTurnsCount;
        bucket.wonCheckoutTurnsTotal += checkoutTurnsCount;
        bucket.wonTurnScoreTotal += turnScoreTotal;
        bucket.wonTurnCount += turnsCount;
      } else if (leg.isLost) {
        bucket.lostLegs++;
        bucket.lostTurnsTotal += turnsCount;
        bucket.lostScoringTurnsTotal += scoringTurnsCount;
        bucket.lostCheckoutTurnsTotal += checkoutTurnsCount;
        bucket.lostTurnScoreTotal += turnScoreTotal;
        bucket.lostTurnCount += turnsCount;
      }
    }

    final result = grouped.values
        .map((m) => m.freeze())
        .where((m) => m.wonLegs > 0 || m.lostLegs > 0)
        .toList();

    result.sort((a, b) => a.startingScore.compareTo(b.startingScore));
    return result;
  }
}

class _MutableLegTurnsByGameGroup {
  final int startingScore;
  int wonLegs = 0;
  int lostLegs = 0;

  int wonTurnsTotal = 0;
  int lostTurnsTotal = 0;

  int wonScoringTurnsTotal = 0;
  int wonCheckoutTurnsTotal = 0;
  int lostScoringTurnsTotal = 0;
  int lostCheckoutTurnsTotal = 0;

  int wonTurnScoreTotal = 0;
  int lostTurnScoreTotal = 0;
  int wonTurnCount = 0;
  int lostTurnCount = 0;

  _MutableLegTurnsByGameGroup(this.startingScore);

  _LegTurnsByGameGroup freeze() {
    return _LegTurnsByGameGroup(
      startingScore: startingScore,
      wonTurnsAverage: wonLegs > 0 ? wonTurnsTotal / wonLegs : 0,
      lostTurnsAverage: lostLegs > 0 ? lostTurnsTotal / lostLegs : 0,
      wonScoringTurnsAverage: wonLegs > 0 ? wonScoringTurnsTotal / wonLegs : 0,
      wonCheckoutTurnsAverage: wonLegs > 0 ? wonCheckoutTurnsTotal / wonLegs : 0,
      lostScoringTurnsAverage: lostLegs > 0 ? lostScoringTurnsTotal / lostLegs : 0,
      lostCheckoutTurnsAverage: lostLegs > 0 ? lostCheckoutTurnsTotal / lostLegs : 0,
      wonScoreAverage: wonTurnCount > 0 ? wonTurnScoreTotal / wonTurnCount : 0,
      lostScoreAverage: lostTurnCount > 0 ? lostTurnScoreTotal / lostTurnCount : 0,
      wonLegs: wonLegs,
      lostLegs: lostLegs,
    );
  }
}

class _CheckoutOpportunityBySectorTable extends StatefulWidget {
  final List<_CachedMatchRecord> matches;
  final AppTokens t;

  const _CheckoutOpportunityBySectorTable({
    required this.matches,
    required this.t,
  });

  @override
  State<_CheckoutOpportunityBySectorTable> createState() => _CheckoutOpportunityBySectorTableState();
}

class _CheckoutOpportunityBySectorTableState extends State<_CheckoutOpportunityBySectorTable> {
  int _sortColumnIndex = 4;
  bool _sortDescending = true;

  @override
  Widget build(BuildContext context) {
    final rows = _sortedRows(_CheckoutOpportunityBySectorRow.fromMatches(widget.matches));

    if (rows.isEmpty) return const SizedBox.shrink();

    return UnifiedStatsCard(
      title: 'OPPORTUNITÀ CHECKOUT',
      subtitle: 'Checkout reali: target incontrati, percentuale di hit e occasioni mancate',
      footerIcon: Icons.ads_click_rounded,
      footerText:
      'Usa questa tabella per capire quali checkout incontri davvero, quali trasformi e quali ti costano più occasioni reali.',
      info: const UnifiedStatsInfoData(
        title: 'Come leggere la tabella',
        text:
        'Ogni riga mostra un checkout incontrato durante un leg.\n\n'
            'Score → punteggio rimasto.\n\n'
            'Target → settore incontrato per chiudere.\n\n'
            'Opport. → quante volte hai avuto quella possibilità.\n\n'
            '% → quante volte l’hai convertita.\n\n'
            'Mancate → quante occasioni non sono diventate checkout.',

        advice: [
          'Ordina Opport. per trovare i checkout che incontri più spesso.',
          'Ordina % per vedere i target che trasformi meglio o peggio.',
          'Ordina Mancate per capire dove perdi più occasioni reali.',
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: widget.t.surfaceHigh,
              border: Border(
                top: BorderSide(color: widget.t.divider),
                bottom: BorderSide(color: widget.t.divider),
              ),
            ),
            child: _buildSortableTable(rows),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.ads_click_rounded, color: widget.t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tabella ordinabile: tocca una colonna per ordinare dal valore più alto o più basso.',
                    style: widget.t.bodySmall(widget.t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_CheckoutOpportunityBySectorRow> _sortedRows(
      List<_CheckoutOpportunityBySectorRow> rows,
      ) {
    final sorted = List<_CheckoutOpportunityBySectorRow>.from(rows);

    sorted.sort((a, b) {
      final comparison = _compareRows(a, b, _sortColumnIndex);
      return _sortDescending ? -comparison : comparison;
    });

    return sorted;
  }

  int _compareRows(
      _CheckoutOpportunityBySectorRow a,
      _CheckoutOpportunityBySectorRow b,
      int columnIndex,
      ) {
    switch (columnIndex) {
      case 0:
        return a.remainingScore.compareTo(b.remainingScore);
      case 1:
        return a.targetLabel.compareTo(b.targetLabel);
      case 2:
        return a.opportunities.compareTo(b.opportunities);
      case 3:
        return a.closeRate.compareTo(b.closeRate);
      case 4:
        return a.missed.compareTo(b.missed);
      default:
        return a.closeRate.compareTo(b.closeRate);
    }
  }

  void _setSortColumn(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortDescending = true;
      }
    });
  }

  Widget _buildSortableTable(List<_CheckoutOpportunityBySectorRow> rows) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: Column(
        children: [
          _buildHeaderRow(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: rows.map(_buildDataRow).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: widget.t.accent.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: widget.t.divider)),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Score', 0),
          _buildHeaderCell('Target', 1),
          _buildHeaderCell('Opport.', 2),
          _buildHeaderCell('%', 3),
          _buildHeaderCell('Mancate', 4),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int columnIndex) {
    final active = _sortColumnIndex == columnIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _setSortColumn(columnIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: widget.t.divider)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: widget.t.labelCaps(active ? widget.t.accent : widget.t.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                active
                    ? (_sortDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)
                    : Icons.unfold_more_rounded,
                size: 14,
                color: active ? widget.t.accent : widget.t.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(_CheckoutOpportunityBySectorRow row) {
    return Row(
      children: [
        _buildDataCell('${row.remainingScore}'),
        _buildDataCell(row.targetLabel, highlight: true),
        _buildDataCell('${row.opportunities}'),
        _buildDataCell('${row.closeRate.toStringAsFixed(0)}%', highlight: true),
        _buildDataCell('${row.missed}'),
      ],
    );
  }

  Widget _buildDataCell(String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: widget.t.divider),
            bottom: BorderSide(color: widget.t.divider),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: widget.t.bodySmall(highlight ? widget.t.accent : widget.t.textPrimary),
        ),
      ),
    );
  }
}

class _CheckoutOpportunityBySectorRow {
  final int remainingScore;
  final String targetLabel;
  final int opportunities;
  final int closed;

  const _CheckoutOpportunityBySectorRow({
    required this.remainingScore,
    required this.targetLabel,
    required this.opportunities,
    required this.closed,
  });

  int get missed => opportunities - closed;
  double get closeRate => opportunities > 0 ? (closed / opportunities) * 100 : 0;

  static List<_CheckoutOpportunityBySectorRow> fromMatches(List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) return const [];

    final buckets = <String, _MutableCheckoutOpportunityBySectorRow>{};

    for (final match in matches) {
      final mode = _CheckoutMode.fromGameConfig(match.originalRecord.gameConfig);

      final dataset = const X01DartExtractor().extract(
        records: [match.originalRecord],
        playerId: playerId,
      );

      final turns = dataset.turns
          .where((turn) => turn.isCheckoutZone)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final turn in turns) {
        int cumulativeScore = 0;

        for (int dartIndex = 0; dartIndex < turn.darts.length; dartIndex++) {
          final remainingBeforeDart = turn.initialScore - cumulativeScore;
          final targetLabels = mode.targetsForScore(remainingBeforeDart);

          if (targetLabels.isNotEmpty) {
            final dart = turn.darts[dartIndex];

            for (final targetLabel in targetLabels) {
              final key = '$remainingBeforeDart|$targetLabel';
              final bucket = buckets.putIfAbsent(
                key,
                    () => _MutableCheckoutOpportunityBySectorRow(
                  remainingScore: remainingBeforeDart,
                  targetLabel: targetLabel,
                ),
              );

              bucket.opportunities++;

              if (dart.dartLabel == targetLabel && dart.isCheckoutDart) {
                bucket.closed++;
              }
            }

          }

          cumulativeScore += turn.darts[dartIndex].dartScore;
        }
      }
    }

    final rows = buckets.values.map((bucket) => bucket.freeze()).toList();

    rows.sort((a, b) {
      final byRate = b.closeRate.compareTo(a.closeRate);
      if (byRate != 0) return byRate;

      final byOpportunities = b.opportunities.compareTo(a.opportunities);
      if (byOpportunities != 0) return byOpportunities;

      return a.remainingScore.compareTo(b.remainingScore);
    });

    return rows;
  }
}

class _MutableCheckoutOpportunityBySectorRow {
  final int remainingScore;
  final String targetLabel;
  int opportunities = 0;
  int closed = 0;

  _MutableCheckoutOpportunityBySectorRow({
    required this.remainingScore,
    required this.targetLabel,
  });

  _CheckoutOpportunityBySectorRow freeze() {
    return _CheckoutOpportunityBySectorRow(
      remainingScore: remainingScore,
      targetLabel: targetLabel,
      opportunities: opportunities,
      closed: closed,
    );
  }
}

enum _CheckoutModeType {
  single,
  double,
  triple,
}

class _CheckoutMode {
  final _CheckoutModeType type;

  const _CheckoutMode(this.type);

  factory _CheckoutMode.fromGameConfig(Map<String, dynamic> gameConfig) {
    final doubleOut = gameConfig['doubleOut'] == true;
    final tripleOut = gameConfig['tripleOut'] == true;

    if (doubleOut) return const _CheckoutMode(_CheckoutModeType.double);
    if (tripleOut) return const _CheckoutMode(_CheckoutModeType.triple);
    return const _CheckoutMode(_CheckoutModeType.single);
  }

  List<String> targetsForScore(int score) {
    if (score <= 0 || score > 180) return const [];

    final targets = <String>[];

    final allowSingles = type == _CheckoutModeType.single;
    final allowDoubles = type == _CheckoutModeType.single ||
        type == _CheckoutModeType.double ||
        type == _CheckoutModeType.triple;
    final allowTriples = type == _CheckoutModeType.single ||
        type == _CheckoutModeType.triple;

    if (allowSingles) {
      if (score >= 1 && score <= 20) {
        targets.add('S$score');
      }
      if (score == 25) {
        targets.add('S25');
      }
    }

    if (allowDoubles) {
      if (score.isEven && score >= 2 && score <= 40) {
        targets.add('D${score ~/ 2}');
      }
      if (score == 50) {
        targets.add('D25');
      }
    }

    if (allowTriples) {
      if (score % 3 == 0) {
        final target = score ~/ 3;
        if (target >= 1 && target <= 20) {
          targets.add('T$target');
        }
      }
    }

    return targets;
  }
}

class X01SummaryTable extends StatelessWidget {
  final List<_CachedMatchRecord> matches;

  const X01SummaryTable({super.key, required this.matches});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final grouped = <int, List<_CachedMatchRecord>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.startingScore, () => []).add(match);
    }

    final scores = grouped.keys.toList()..sort();

    if (scores.isEmpty) return const SizedBox.shrink();

    final metricsList = <_X01Metrics>[];
    for (final score in scores) {
      metricsList.add(_calculateMetrics(score, grouped[score]!));
    }

    final minWidth = (178 + scores.length * 92).clamp(540, 9000).toDouble();

    return UnifiedStatsCard(
      title: 'PARTITE X01',
      subtitle: 'Statistiche generali.',
      info: const UnifiedStatsInfoData(
        title: 'Come interpretare la tabella?',
        text:
        'AVG partita → media reale dei punti su tutti i turni giocati.\n\n'

            'Avg turni nei leg vinti → quanti turni ti servono mediamente per chiudere un leg vinto.\n\n'

            'Avg turni nei leg persi → quanti turni giochi mediamente prima che l’avversario chiuda il leg.\n\n'

            'Gap vinti/persi → confronta il tuo ritmo medio vincente con i turni disponibili quando perdi.\n\n'

            'Tempo medio leg → durata media dei leg giocati.\n\n'

            'Turni zona checkout vinti → quanti turni di scoring ti servono mediamente per entrare in checkout nei leg vinti.\n\n'

            'Turni zona checkout persi → quanti turni impieghi per arrivare in checkout nei leg persi in cui riesci ad entrarci.\n\n'

            'Turni checkout vinti → quanti turni impieghi mediamente per chiudere una volta entrato in checkout.\n\n'

            'Turni checkout persi → quanti turni resti mediamente in checkout prima di perdere il leg.\n\n'

            'Punti rimasti nei leg persi → punteggio medio rimasto quando perdi il leg.\n\n'

            '% leg persi → percentuale totale dei leg persi.\n\n',

        advice: [
          'Confronta sempre i dati vinti e persi: la differenza mostra dove il leg viene realmente perso.',

          'Se nei leg persi impieghi molti più turni per arrivare in checkout, il problema principale è nella discesa e nello scoring iniziale.',

          'Se arrivi in checkout con tempi simili sia nei vinti che nei persi, ma perdi molti più turni in checkout, il problema è soprattutto nella chiusura finale.',

          'Checkout persi molto lunghi spesso indicano blocchi sui doppi, setup scomodi o difficoltà a chiudere sotto pressione.',

          'Se sia la discesa che il checkout peggiorano nei leg persi, probabilmente il livello medio degli avversari è superiore oppure il tuo ritmo è ancora troppo instabile.',

          'Gap vinti/persi positivo → gli avversari ti chiudono prima del tuo ritmo medio vincente. Probabilmente stai affrontando giocatori più rapidi o più forti.',

          'Gap vinti/persi vicino allo 0 → i leg sono equilibrati: qui fanno la differenza dettagli come checkout, gestione pressione e settore preferito.',

          'Gap vinti/persi negativo → hai abbastanza turni per vincere il leg, ma non riesci a convertirlo. Il problema è più nella chiusura che nel ritmo.',

          'Confronta il tempo medio dei leg vinti e persi per capire se rendi meglio con ritmo veloce o con costruzione più lenta e controllata.',

          'Quando trovi avversari con un ritmo molto diverso dal tuo, evita di cambiare completamente timing e routine di lancio.',

          'Punti rimasti nei leg persi bassi → stai perdendo leg combattuti su settori piccoli.',

          'Punti rimasti nei leg persi alti → spesso il leg viene perso ancora lontano dal checkout. Controlla la qualità dei turni.',
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: minWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(scores, t),
                    _buildMetricRow(
                      'Avg partite',
                      metricsList.map((m) => m.avgMatchAverage.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Avg turni nei leg vinti',
                      metricsList.map((m) => m.avgVisitsWhenWon.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Avg turni nei leg persi',
                      metricsList.map((m) => m.avgVisitsWhenLost.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Gap vinti/persi',
                      metricsList
                          .map(
                            (m) => (m.avgVisitsWhenLost - m.avgVisitsWhenWon)
                            .toStringAsFixed(1),
                      )
                          .toList(),
                      t,
                      highlightIf: (value) {
                        final gap = double.tryParse(value) ?? 0;
                        return gap >= 3;
                      },
                    ),
                    _buildMetricRow(
                      'Tempo medio leg vinti',
                      metricsList.map((m) => _formatDuration(m.avgWonLegDurationSeconds.toInt())).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Tempo medio leg persi',
                      metricsList.map((m) => _formatDuration(m.avgLostLegDurationSeconds.toInt())).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Turni zona checkout vinti',
                      metricsList.map((m) => m.avgVisitsToReachCloseWhenWon.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Turni zona checkout persi',
                      metricsList.map((m) => m.avgVisitsToReachCloseWhenLost.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Turni x checkout',
                      metricsList.map((m) => m.avgVisitsToCloseWhenWon.toStringAsFixed(1)).toList(),
                      t,
                    ),
                    _buildMetricRow(
                      'Turni checkout persi',
                      metricsList.map((m) => m.avgVisitsToCloseWhenLost.toStringAsFixed(1)).toList(),
                      t,
                    ),

                    _buildMetricRow(
                      'Punti rimasti nei leg persi',
                      metricsList
                          .map((m) => m.avgRemainingScoreWhenLost.toStringAsFixed(0))
                          .toList(),                      t,
                    ),
                    _buildMetricRow(
                      '% leg persi',
                      metricsList.map((m) => '${m.percentLost.toStringAsFixed(0)}%').toList(),
                      t,
                      highlightIf: (value) {
                        final percent = double.tryParse(value.replaceAll('%', '')) ?? 0;
                        return percent > 50;
                      },
                    ),
                  ],
                ),
              ),
            ),
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
                    'Analizza come vinci e come perdi: velocità di gioco, arrivo in checkout, gestione finale del leg e qualità delle sconfitte.',
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

  Widget _buildHeaderRow(List<int> scores, AppTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text('METRICA', style: t.labelCaps(t.accent)),
            ),
          ),
          ...scores.map(
                (score) => SizedBox(
              width: 92,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  score.toString(),
                  style: t.labelCaps(t.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      String label,
      List<String> values,
      AppTokens t, {
        bool Function(String value)? highlightIf,
      }) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: t.divider),
                bottom: BorderSide(color: t.divider),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall(t.textSecondary),
            ),
          ),
        ),
        ...values.map((value) {
          final isHighlighted = highlightIf?.call(value) ?? false;

          return SizedBox(
            width: 92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: t.divider),
                  bottom: BorderSide(color: t.divider),
                ),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.bodySmall(isHighlighted ? t.red : t.textPrimary),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '-';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) return '${minutes}m ${remainingSeconds}s';
    return '${seconds}s';
  }

  int _legDurationSeconds(X01LegSlice leg) {
    if (leg.endTime != null) {
      final seconds = leg.endTime!.difference(leg.startTime).inSeconds;
      if (seconds > 0) return seconds;
    }

    if (leg.turns.length < 2) return 0;

    final sortedTurns = List<X01TurnSlice>.from(leg.turns)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final seconds = sortedTurns.last.timestamp
        .difference(sortedTurns.first.timestamp)
        .inSeconds;

    return seconds > 0 ? seconds : 0;
  }

  _X01Metrics _calculateMetrics(int score, List<_CachedMatchRecord> matches) {
    final playerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (playerId.isEmpty || matches.isEmpty) {
      return const _X01Metrics(
        avgMatchAverage: 0,
        avgVisitsWhenWon: 0,
        avgVisitsWhenLost: 0,
        avgWonLegDurationSeconds: 0,
        avgLostLegDurationSeconds: 0,
        avgVisitsToReachCloseWhenWon: 0,
        avgVisitsToReachCloseWhenLost: 0,
        avgVisitsToCloseWhenWon: 0,
        avgVisitsToCloseWhenLost: 0,
        percentLost: 0,
        avgRemainingScoreWhenLost: 0,
      );
    }

    final totalMatchScore = matches.fold<int>(0, (sum, match) => sum + match.totalScore);
    final totalMatchDarts = matches.fold<int>(0, (sum, match) => sum + match.totalDarts);
    final avgMatchAverage = totalMatchDarts > 0 ? (totalMatchScore / totalMatchDarts) * 3 : 0.0;

    final dataset = const X01DartExtractor().extract(
      records: matches.map((m) => m.originalRecord).toList(),
      playerId: playerId,
    );

    final legs = dataset.legs.where((leg) => leg.startingScore == score).toList();

    if (legs.isEmpty) {
      return const _X01Metrics(
        avgMatchAverage: 0,
        avgVisitsWhenWon: 0,
        avgVisitsWhenLost: 0,
        avgWonLegDurationSeconds: 0,
        avgLostLegDurationSeconds: 0,
        avgVisitsToReachCloseWhenWon: 0,
        avgVisitsToReachCloseWhenLost: 0,
        avgVisitsToCloseWhenWon: 0,
        avgVisitsToCloseWhenLost: 0,
        percentLost: 0,
        avgRemainingScoreWhenLost: 0,
      );
    }

    final finishedLegs = legs.where((leg) => leg.isFinished).toList();
    final wonLegs = finishedLegs.where((leg) => leg.isWon).toList();
    final lostLegs = finishedLegs.where((leg) => leg.isLost).toList();

    int totalVisitsWhenWon = 0;
    int totalVisitsWhenLost = 0;

    int totalVisitsToReachCloseWhenWon = 0;
    int visitsToReachCloseWhenWonCount = 0;

    int totalVisitsToReachCloseWhenLost = 0;
    int visitsToReachCloseWhenLostCount = 0;

    int totalVisitsToCloseWhenWon = 0;
    int visitsToCloseWhenWonCount = 0;

    int totalVisitsToCloseWhenLost = 0;
    int visitsToCloseWhenLostCount = 0;

    int totalRemainingScoreWhenLost = 0;
    int remainingScoreCount = 0;

    int totalWonLegDurationSeconds = 0;
    int wonLegDurationCount = 0;

    int totalLostLegDurationSeconds = 0;
    int lostLegDurationCount = 0;

    for (final leg in wonLegs) {
      totalVisitsWhenWon += leg.turns.length;

      totalVisitsToReachCloseWhenWon += leg.scoringTurns.length;
      visitsToReachCloseWhenWonCount++;

      totalVisitsToCloseWhenWon += leg.checkoutTurns.length;
      visitsToCloseWhenWonCount++;

      final durationSeconds = _legDurationSeconds(leg);
      if (durationSeconds > 0) {
        totalWonLegDurationSeconds += durationSeconds;
        wonLegDurationCount++;
      }
    }

    for (final leg in lostLegs) {
      totalVisitsWhenLost += leg.turns.length;

      if (leg.checkoutTurns.isNotEmpty) {
        totalVisitsToReachCloseWhenLost += leg.scoringTurns.length;
        visitsToReachCloseWhenLostCount++;

        totalVisitsToCloseWhenLost += leg.checkoutTurns.length;
        visitsToCloseWhenLostCount++;
      }

      if (leg.turns.isNotEmpty) {
        final lastTurn = leg.turns.last;
        final remainingScore = lastTurn.initialScore - lastTurn.total;

        totalRemainingScoreWhenLost += remainingScore.clamp(0, leg.startingScore).toInt();
        remainingScoreCount++;
      }

      final durationSeconds = _legDurationSeconds(leg);
      if (durationSeconds > 0) {
        totalLostLegDurationSeconds += durationSeconds;
        lostLegDurationCount++;
      }
    }

    return _X01Metrics(
      avgMatchAverage: avgMatchAverage,
      avgVisitsWhenWon: wonLegs.isNotEmpty ? totalVisitsWhenWon / wonLegs.length : 0,
      avgVisitsWhenLost: lostLegs.isNotEmpty ? totalVisitsWhenLost / lostLegs.length : 0,
      avgWonLegDurationSeconds: wonLegDurationCount > 0 ? totalWonLegDurationSeconds / wonLegDurationCount : 0,
      avgLostLegDurationSeconds: lostLegDurationCount > 0 ? totalLostLegDurationSeconds / lostLegDurationCount : 0,
      avgVisitsToReachCloseWhenWon: visitsToReachCloseWhenWonCount > 0
          ? totalVisitsToReachCloseWhenWon / visitsToReachCloseWhenWonCount
          : 0,
      avgVisitsToReachCloseWhenLost: visitsToReachCloseWhenLostCount > 0
          ? totalVisitsToReachCloseWhenLost / visitsToReachCloseWhenLostCount
          : 0,
      avgVisitsToCloseWhenWon:
      visitsToCloseWhenWonCount > 0
          ? totalVisitsToCloseWhenWon / visitsToCloseWhenWonCount
          : 0,

      avgVisitsToCloseWhenLost:
      visitsToCloseWhenLostCount > 0
          ? totalVisitsToCloseWhenLost / visitsToCloseWhenLostCount
          : 0,
      percentLost: finishedLegs.isNotEmpty ? (lostLegs.length / finishedLegs.length) * 100 : 0,
      avgRemainingScoreWhenLost: remainingScoreCount > 0 ? totalRemainingScoreWhenLost / remainingScoreCount : 0,
    );
  }}


class _X01Metrics {
  final double avgMatchAverage;
  final double avgVisitsWhenWon;
  final double avgVisitsWhenLost;
  final double avgWonLegDurationSeconds;
  final double avgLostLegDurationSeconds;
  final double avgVisitsToReachCloseWhenWon;
  final double avgVisitsToReachCloseWhenLost;
  final double avgVisitsToCloseWhenWon;
  final double avgVisitsToCloseWhenLost;
  final double percentLost;
  final double avgRemainingScoreWhenLost;

  const _X01Metrics({
    required this.avgMatchAverage,
    required this.avgVisitsWhenWon,
    required this.avgVisitsWhenLost,
    required this.avgWonLegDurationSeconds,
    required this.avgLostLegDurationSeconds,
    required this.avgVisitsToReachCloseWhenWon,
    required this.avgVisitsToReachCloseWhenLost,
    required this.avgVisitsToCloseWhenWon,
    required this.avgVisitsToCloseWhenLost,
    required this.percentLost,
    required this.avgRemainingScoreWhenLost,
  });
}
