import '../../../domain/entities/match.dart';
import '../controllers/match_controller.dart';

class MatchVm {
  const MatchVm({
    required this.players,
    required this.currentPlayerId,
    required this.isMyTurn,
    required this.isInputEnabled,
    required this.isMatchStarted,
    required this.inputMode,
    required this.selectedMultiplier,
    required this.currentTurnInputs,
    required this.bufferedTurnTotal,
    required this.displayTurnLabels,
  });

  final List<PlayerVm> players;
  final String currentPlayerId;
  final bool isMyTurn;
  final bool isInputEnabled;
  final bool isMatchStarted;
  final MatchInputMode inputMode;
  final DartMultiplierMode selectedMultiplier;
  final List<DartInput> currentTurnInputs;
  final int bufferedTurnTotal;
  final List<String> displayTurnLabels;

  MatchVm copyWith({
    List<PlayerVm>? players,
    String? currentPlayerId,
    bool? isMyTurn,
    bool? isInputEnabled,
    bool? isMatchStarted,
    MatchInputMode? inputMode,
    DartMultiplierMode? selectedMultiplier,
    List<DartInput>? currentTurnInputs,
    int? bufferedTurnTotal,
    List<String>? displayTurnLabels,
  }) {
    return MatchVm(
      players: players ?? this.players,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      isInputEnabled: isInputEnabled ?? this.isInputEnabled,
      isMatchStarted: isMatchStarted ?? this.isMatchStarted,
      inputMode: inputMode ?? this.inputMode,
      selectedMultiplier: selectedMultiplier ?? this.selectedMultiplier,
      currentTurnInputs: currentTurnInputs ?? this.currentTurnInputs,
      bufferedTurnTotal: bufferedTurnTotal ?? this.bufferedTurnTotal,
      displayTurnLabels: displayTurnLabels ?? this.displayTurnLabels,
    );
  }
}

class PlayerVm {
  final String id;
  final String name;
  final int score;
  final bool isCurrent;

  PlayerVm({
    required this.id,
    required this.name,
    required this.score,
    required this.isCurrent,
  });
}