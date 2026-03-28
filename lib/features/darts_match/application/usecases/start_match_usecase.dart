/// File: start_match_usecase.dart. Contiene codice Dart del progetto.

import '../../domain/entities/match.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/value_objects/identifiers.dart';

class StartMatchUseCase {
  const StartMatchUseCase(this._matchRepository);

  final MatchRepository _matchRepository;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> call(Match match) => _matchRepository.saveMatch(match);
}

class ReplayMatchUseCase {
  const ReplayMatchUseCase(this._matchRepository);

  final MatchRepository _matchRepository;

  /// Funzione: descrive in modo semplice questo blocco di logica.
  Future<void> call({required RoomId roomId, required MatchId newMatchId, required Match previousMatch}) async {
    final replay = Match(
      id: newMatchId,
      roomId: roomId,
      config: previousMatch.config,
      roster: previousMatch.roster,
      snapshot: previousMatch.snapshot,
      legs: const [],
      sets: const [],
      result: null,
      createdAt: DateTime.now(),
    );
    await _matchRepository.saveMatch(replay);
  }
}
