import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/orchestrators/match_command_processor.dart';
import '../../../application/orchestrators/match_orchestrator.dart';
import '../../../application/reducers/match_reducer.dart';
import '../../../application/usecases/providers.dart';
import '../../../application/validators/command_validator.dart';
import '../../../domain/commands/match_command.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/engines/x01_engine.dart';
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
  MatchController(this._ref) : super(null);

  final Ref _ref;
  StreamSubscription<Match>? _sub;
  MatchCommandProcessor? _commandProcessor;

  void bind(MatchStateSnapshot snapshot) {}

  Future<void> bindMatch({required Match match, required bool isOnline}) async {
    state = MatchViewModel(match: match, isOnline: isOnline, loading: false);
    if (!isOnline) return;

    _sub?.cancel();
    _sub = _ref.read(matchRepositoryProvider).watchMatch(match.roomId, match.id).listen((updatedMatch) {
      if (state == null) return;
      state = state!.copyWith(match: updatedMatch);
    });

    final orchestrator = MatchOrchestrator(
      roomRepository: _ref.read(roomRepositoryProvider),
      matchRepository: _ref.read(matchRepositoryProvider),
      commandRepository: _ref.read(commandRepositoryProvider),
      validator: const CommandValidator(),
      reducer: const MatchReducer(),
      engine: const X01Engine(),
    );
    _commandProcessor ??= MatchCommandProcessor(
      firestore: FirebaseFirestore.instance,
      orchestrator: orchestrator,
    );
    _commandProcessor!.bindRoom(match.roomId.value);
  }

  Future<void> submitTurn(int points) async {
    final current = state;
    if (current == null || !current.isOnline) return;

    final now = DateTime.now();
    final commandId = FirebaseFirestore.instance.collection('_').doc().id;
    final playerId = current.match.snapshot.scoreboard.currentTurnPlayerId.value;

    final command = SubmitTurnCommand(
      commandId: CommandId(commandId),
      authorId: PlayerId(playerId),
      createdAt: now,
      roomId: current.match.roomId,
      matchId: current.match.id,
      payload: {
        'draft': {
          'playerId': playerId,
          'legNumber': current.match.snapshot.currentLeg,
          'turnNumber': current.match.snapshot.currentTurn,
          'inputs': [
            {'rawValue': points, 'multiplier': 1}
          ],
        },
      },
      idempotencyKey: commandId,
      status: CommandStatus.pending,
    );

    await _ref.read(commandRepositoryProvider).enqueue(command);
  }

  Future<void> undoLastTurn() async {
    final current = state;
    if (current == null || !current.isOnline) return;

    final now = DateTime.now();
    final commandId = FirebaseFirestore.instance.collection('_').doc().id;
    final command = UndoLastTurnRequestCommand(
      commandId: CommandId(commandId),
      authorId: current.match.snapshot.scoreboard.currentTurnPlayerId,
      createdAt: now,
      roomId: current.match.roomId,
      matchId: current.match.id,
      payload: const {},
      idempotencyKey: commandId,
      status: CommandStatus.pending,
    );

    await _ref.read(commandRepositoryProvider).enqueue(command);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _commandProcessor?.dispose();
    super.dispose();
  }
}

final matchControllerProvider = StateNotifierProvider<MatchController, MatchViewModel?>((ref) => MatchController(ref));
