import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/match.dart';
import '../../../domain/value_objects/identifiers.dart';

class MatchViewModel {
  const MatchViewModel({required this.match, required this.isOnline, required this.loading});

  final Match match;
  final bool isOnline;
  final bool loading;

  MatchViewModel copyWith({Match? match, bool? isOnline, bool? loading}) {
    return MatchViewModel(
      match: match ?? this.match,
      isOnline: isOnline ?? this.isOnline,
      loading: loading ?? this.loading,
    );
  }
}

class MatchController extends StateNotifier<MatchViewModel?> {
  MatchController() : super(null);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void bind(MatchStateSnapshot snapshot) {}

  Future<void> bindMatch({required Match match, required bool isOnline}) async {
    state = MatchViewModel(match: match, isOnline: isOnline, loading: false);
    if (isOnline) {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(match.roomId.value)
          .collection('matches')
          .doc(match.id.value)
          .snapshots()
          .listen((doc) {
        final data = doc.data();
        if (data == null || state == null) return;
        final rawScores = Map<String, dynamic>.from((data['scoreboard']?['playerScores'] as Map?) ?? const {});
        final newScores = rawScores.map((k, v) => MapEntry(PlayerId(k), (v as num).toInt()));
        final currentPlayerId = PlayerId((data['currentTurnPlayerId'] as String?) ?? state!.match.snapshot.scoreboard.currentTurnPlayerId.value);
        final updated = _patchMatch(
          state!.match,
          scores: newScores,
          currentTurnPlayer: currentPlayerId,
          currentTurn: (data['currentTurn'] as num?)?.toInt() ?? state!.match.snapshot.currentTurn,
        );
        state = state!.copyWith(match: updated);
      });
    }
  }

  Future<void> submitTurn(int points) async {
    if (state == null) return;
    final current = state!;
    final playerId = current.match.snapshot.scoreboard.currentTurnPlayerId;
    final oldScore = current.match.snapshot.scoreboard.playerScores[playerId] ?? current.match.config.startScore;
    final nextScore = (oldScore - points).clamp(0, 999999);
    final order = current.match.roster.players;
    final currentIndex = order.indexWhere((e) => e.playerId == playerId);
    final nextPlayer = order[(currentIndex + 1) % order.length].playerId;

    final next = _patchMatch(
      current.match,
      scores: {...current.match.snapshot.scoreboard.playerScores, playerId: nextScore},
      currentTurnPlayer: nextPlayer,
      currentTurn: current.match.snapshot.currentTurn + 1,
    );

    state = current.copyWith(match: next, loading: false);
    await _sync();
  }

  Future<void> undoLastTurn() async {
    if (state == null) return;
    final current = state!;
    final turn = current.match.snapshot.currentTurn;
    if (turn <= 1) return;
    final order = current.match.roster.players;
    final currentIndex = order.indexWhere((e) => e.playerId == current.match.snapshot.scoreboard.currentTurnPlayerId);
    final prevPlayer = order[(currentIndex - 1 + order.length) % order.length].playerId;
    final prevScore = current.match.config.startScore;
    final next = _patchMatch(
      current.match,
      scores: {...current.match.snapshot.scoreboard.playerScores, prevPlayer: prevScore},
      currentTurnPlayer: prevPlayer,
      currentTurn: turn - 1,
    );
    state = current.copyWith(match: next);
    await _sync();
  }

  Match _patchMatch(
    Match match, {
    required Map<PlayerId, int> scores,
    required PlayerId currentTurnPlayer,
    required int currentTurn,
  }) {
    return Match(
      id: match.id,
      roomId: match.roomId,
      config: match.config,
      roster: match.roster,
      legs: match.legs,
      sets: match.sets,
      result: match.result,
      createdAt: match.createdAt,
      snapshot: MatchStateSnapshot(
        matchState: match.snapshot.matchState,
        status: match.snapshot.status,
        currentSet: match.snapshot.currentSet,
        currentLeg: match.snapshot.currentLeg,
        currentTurn: currentTurn,
        scoreboard: Scoreboard(
          playerScores: scores,
          teamScores: match.snapshot.scoreboard.teamScores,
          currentTurnPlayerId: currentTurnPlayer,
        ),
        lastTurns: match.snapshot.lastTurns,
      ),
    );
  }

  Future<void> _sync() async {
    final current = state;
    if (current == null || !current.isOnline) return;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(current.match.roomId.value)
        .collection('matches')
        .doc(current.match.id.value)
        .set({
      'currentTurn': current.match.snapshot.currentTurn,
      'currentTurnPlayerId': current.match.snapshot.scoreboard.currentTurnPlayerId.value,
      'scoreboard': {
        'playerScores': current.match.snapshot.scoreboard.playerScores.map((k, v) => MapEntry(k.value, v)),
      },
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final matchControllerProvider = StateNotifierProvider<MatchController, MatchViewModel?>((ref) => MatchController());
