// TARGET: Gestione stato risultati match con debounce
// LOGIC GOAL: Coordinare calcolo statistiche, match completo e stato UI
// REACTION: Esporre alla UI statistiche aggregate e gerarchia completa del match
// ERROR STRATEGY: Failure tipizzato e reset pulito di loading/error
// ANTI-REGRESSION: Mantenere debounce, fetch remoto e provider invariato

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/player_info.dart';
import '../../../domain/models/match.dart';
import '../domain/match_result_state.dart';
import '../data/match_result_repository.dart';

class MatchResultNotifier extends StateNotifier<MatchResultState> {
  final MatchResultRepository _repository;
  Timer? _debounce;

  MatchResultNotifier(this._repository) : super(const MatchResultState(matchId: ''));

  Future<void> loadMatchResult({
    required Match match,
    required List<PlayerInfo> players,
    required bool isTeamMode,
    required bool isCricket,
    required Map<String, String> playerToTeam,
  }) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = state.copyWith(
        matchId: match.id,
        match: match,
        isTeamMode: isTeamMode,
        playerToTeam: playerToTeam,
        winnerId: match.winnerId,
        status: AppStatus.loading,
        failure: null,
      );

      try {
        final stats = await _repository.calculateStatistics(
          match,
          players,
          isTeamMode,
          isCricket,
        );

        state = state.copyWith(
          match: match,
          playerStats: stats,
          status: AppStatus.success,
          failure: null,
        );
      } catch (e) {
        state = state.copyWith(
          match: match,
          status: AppStatus.error,
          failure: Failure('Errore nel calcolo statistiche: ${e.toString()}', e),
        );
      }
    });
  }

  Future<Map<String, dynamic>?> fetchRemoteStructure(String remoteMatchId, String playerId) async {
    state = state.copyWith(status: AppStatus.loading, failure: null);
    try {
      final result = await _repository.fetchRemoteMatchStructure(remoteMatchId, playerId);
      state = state.copyWith(status: AppStatus.success, failure: null);
      return result;
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        failure: Failure('Errore nel recupero dati remoti: ${e.toString()}', e),
      );
      return null;
    }
  }

  void reset() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    state = const MatchResultState(matchId: '');
  }
}

final matchResultProvider = StateNotifierProvider<MatchResultNotifier, MatchResultState>((ref) {
  final repository = ref.watch(matchResultRepositoryProvider);
  return MatchResultNotifier(repository);
});