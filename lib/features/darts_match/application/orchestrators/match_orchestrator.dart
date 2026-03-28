/// File: match_orchestrator.dart. Contiene codice Dart del progetto.

import '../../domain/commands/match_command.dart';
import '../../domain/entities/match.dart';
import '../../domain/engines/game_engine.dart';
import '../../domain/events/match_event.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/value_objects/identifiers.dart';
import '../reducers/match_reducer.dart';
import '../validators/command_validator.dart';

class MatchOrchestrator {
  /// Funzione: descrive in modo semplice questo blocco di logica.
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

  Match? _currentMatchCache;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  InputMode matchInputMode(PlayerId playerId) {
    final match = _currentMatchCache;
    if (match == null) return InputMode.totalTurnInput;
    return match.config.inputSnapshot[playerId]?.mode ?? InputMode.totalTurnInput;
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> handleCommand(MatchCommand command) async {
    final room = await _roomRepository.getRoom(command.roomId);
    if (room == null) return;

    final match =
    command.matchId == null ? null : await _matchRepository.getMatch(command.roomId, command.matchId!);

    _currentMatchCache = match;

    if (!_validator.validate(command: command, room: room, match: match)) {
      return;
    }

    if (command is SubmitTurnCommand && match != null) {
      final draft = _extractDraft(command.payload['draft']);
      final playerScore = match.snapshot.scoreboard.playerScores[draft.playerId] ?? match.config.startScore;

      final resolution = _engine.resolveTurn(
        match: match,
        draft: draft,
        currentPlayerScore: playerScore,
        currentTeamScore: 0,
        inActivated: true,
      );

      final payload = <String, dynamic>{
        'playerId': draft.playerId.value,
        'previousScore': playerScore,
        'nextScore': resolution.nextScore,
        'reason': resolution.reason,
        'isBust': resolution.isBust,
        'isCheckout': resolution.isCheckout,
        'draft': {
          'playerId': draft.playerId.value,
          'legNumber': draft.legNumber,
          'turnNumber': draft.turnNumber,
          'inputMode': draft.inputMode.name,
          'inputs': [
            for (final input in draft.inputs)
              {
                'rawValue': input.rawValue,
                'multiplier': input.multiplier,
              },
          ],
        },
      };

      final MatchEvent event = resolution.isCheckout
          ? MatchWonEvent(
        eventId: EventId(command.commandId.value),
        roomId: command.roomId,
        matchId: command.matchId!,
        createdAt: DateTime.now(),
        payload: payload,
      )
          : resolution.isBust
          ? TurnBustEvent(
        eventId: EventId(command.commandId.value),
        roomId: command.roomId,
        matchId: command.matchId!,
        createdAt: DateTime.now(),
        payload: payload,
      )
          : TurnCommittedEvent(
        eventId: EventId(command.commandId.value),
        roomId: command.roomId,
        matchId: command.matchId!,
        createdAt: DateTime.now(),
        payload: payload,
      );

      await _matchRepository.appendEvent(event);
      final updated = _reducer.apply(match, event);
      await _matchRepository.saveMatch(updated);
      return;
    }

    await _commandRepository.enqueue(command);
  }

  /// Funzione: descrive in modo semplice questo blocco di logica.
  TurnDraft _extractDraft(Object? rawDraft) {
    if (rawDraft is TurnDraft) return rawDraft;

    if (rawDraft is Map) {
      final draftMap = Map<String, dynamic>.from(rawDraft);
      final inputs = List<Map<String, dynamic>>.from((draftMap['inputs'] as List?) ?? const [])
          .map(
            (it) => DartInput(
          rawValue: (it['rawValue'] as num?)?.toInt() ?? 0,
          multiplier: (it['multiplier'] as num?)?.toInt() ?? 1,
        ),
      )
          .toList();

      return TurnDraft(
        playerId: PlayerId((draftMap['playerId'] ?? '') as String),
        legNumber: (draftMap['legNumber'] as num?)?.toInt() ?? 1,
        turnNumber: (draftMap['turnNumber'] as num?)?.toInt() ?? 1,
        inputs: inputs,
        inputMode: matchInputMode(PlayerId((draftMap['playerId'] ?? '') as String)),
      );
    }

    throw StateError('Invalid turn draft payload');
  }

  Map<String, dynamic> _serializeDraft(TurnDraft draft) {
    return {
      'playerId': draft.playerId.value,
      'legNumber': draft.legNumber,
      'turnNumber': draft.turnNumber,
      'inputMode': draft.inputMode.name,
      'inputs': [
        for (final input in draft.inputs)
          {
            'rawValue': input.rawValue,
            'multiplier': input.multiplier,
          },
      ],
    };
  }
}
