import '../../domain/commands/match_command.dart';
import '../../domain/entities/match.dart';
import '../../domain/engines/game_engine.dart';
import '../../domain/events/match_event.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/value_objects/identifiers.dart';
import '../reducers/match_reducer.dart';
import '../validators/command_validator.dart';

class MatchOrchestrator {
  MatchOrchestrator({
    required RoomRepository roomRepository,
    required MatchRepository matchRepository,
    required CommandRepository commandRepository,
    required CommandValidator validator,
    required MatchReducer reducer,
    required GameEngine engine,
  })  : _roomRepository = roomRepository,
        _matchRepository = matchRepository,
        _commandRepository = commandRepository,
        _validator = validator,
        _reducer = reducer,
        _engine = engine;

  final RoomRepository _roomRepository;
  final MatchRepository _matchRepository;
  final CommandRepository _commandRepository;
  final CommandValidator _validator;
  final MatchReducer _reducer;
  final GameEngine _engine;

  Future<void> handleCommand(MatchCommand command) async {
    final room = await _roomRepository.getRoom(command.roomId);
    if (room == null) return;

    final match = command.matchId == null ? null : await _matchRepository.getMatch(command.roomId, command.matchId!);
    if (!_validator.validate(command: command, room: room, match: match)) return;

    if (command is SubmitTurnCommand && match != null) {
      final draft = command.payload['draft'] as TurnDraft;
      final playerScore = match.snapshot.scoreboard.playerScores[draft.playerId] ?? match.config.startScore;
      final resolution = _engine.resolveTurn(
        match: match,
        draft: draft,
        currentPlayerScore: playerScore,
        currentTeamScore: 0,
        inActivated: true,
      );

      final MatchEvent event;
      if (resolution.isBust) {
        event = TurnBustEvent(
          eventId: EventId(command.commandId.value),
          roomId: command.roomId,
          matchId: command.matchId!,
          createdAt: DateTime.now(),
          payload: {'nextScore': playerScore, 'reason': resolution.reason},
        );
      } else {
        event = TurnCommittedEvent(
          eventId: EventId(command.commandId.value),
          roomId: command.roomId,
          matchId: command.matchId!,
          createdAt: DateTime.now(),
          payload: {'nextScore': resolution.nextScore, 'reason': resolution.reason},
        );
      }

      await _matchRepository.appendEvent(event);
      final updated = _reducer.apply(match, event);
      await _matchRepository.saveMatch(updated);
      return;
    }

    await _commandRepository.enqueue(command);
  }
}
