
import '../match_sync/domain/entities/local_match_record.dart';
import '../room_v4/domain/models/dart_throw.dart';
import '../room_v4/domain/models/player_turn.dart';

class X01DartExtractor {
  const X01DartExtractor();

  X01DartDataset extract({
    required List<LocalMatchRecord> records,
    String? playerId,
  }) {
    final darts = <X01DartAtom>[];

    for (final record in records) {
      darts.addAll(_extractRecord(record: record, playerId: playerId));
    }

    darts.sort((a, b) {
      final byTime = a.dartTimestamp.compareTo(b.dartTimestamp);
      if (byTime != 0) return byTime;

      final byMatch = a.matchStartTime.compareTo(b.matchStartTime);
      if (byMatch != 0) return byMatch;

      final bySet = a.setNumber.compareTo(b.setNumber);
      if (bySet != 0) return bySet;

      final byLeg = a.legNumber.compareTo(b.legNumber);
      if (byLeg != 0) return byLeg;

      final byRound = a.roundNumber.compareTo(b.roundNumber);
      if (byRound != 0) return byRound;

      final byTurn = a.turnNumber.compareTo(b.turnNumber);
      if (byTurn != 0) return byTurn;

      return a.dartNumber.compareTo(b.dartNumber);
    });

    return X01DartDataset(darts: darts);
  }

  List<X01DartAtom> _extractRecord({
    required LocalMatchRecord record,
    required String? playerId,
  }) {
    final result = <X01DartAtom>[];

    final matchId = record.remoteId ?? record.localId;
    final startingScore = _int(record.gameConfig['startingScore'], fallback: 501);
    final matchSets = record.matchSets;

    for (int setIndex = 0; setIndex < matchSets.length; setIndex++) {
      final setMap = _asMap(matchSets[setIndex]);
      if (setMap == null) continue;

      final setNumber = _int(setMap['setNumber'], fallback: setIndex + 1);
      final setWinnerId = _stringOrNull(setMap['winnerId']);
      final setStartTime = _date(setMap['startTime']) ?? record.startTime;
      final setEndTime = _date(setMap['endTime']);

      final legs = _asList(setMap['legs']);

      for (int legIndex = 0; legIndex < legs.length; legIndex++) {
        final legMap = _asMap(legs[legIndex]);
        if (legMap == null) continue;

        final legNumber = _int(legMap['legNumber'], fallback: legIndex + 1);
        final legWinnerId = _stringOrNull(legMap['winnerId']);
        final legStartTime = _date(legMap['startTime']) ?? setStartTime;
        final legEndTime = _date(legMap['endTime']);
        final legIsFinished = legWinnerId != null || legEndTime != null;

        final rounds = _asList(legMap['rounds']);
        final turnProgressiveByPlayer = <String, int>{};
        final dartProgressiveByPlayer = <String, int>{};

        for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
          final roundMap = _asMap(rounds[roundIndex]);
          if (roundMap == null) continue;

          final roundNumber = _int(roundMap['roundNumber'], fallback: roundIndex + 1);
          final roundTimestamp = _date(roundMap['timestamp']) ?? legStartTime;
          final turns = _asList(roundMap['turns']);

          for (int turnIndex = 0; turnIndex < turns.length; turnIndex++) {
            final turnMap = _asMap(turns[turnIndex]);
            if (turnMap == null) continue;

            final turnPlayerId = _string(turnMap['playerId']);
            if (playerId != null && turnPlayerId != playerId) continue;

            final turn = PlayerTurn.fromMap(Map<String, dynamic>.from(turnMap));

            final turnProgressiveInLeg =
                (turnProgressiveByPlayer[turn.playerId] ?? 0) + 1;
            turnProgressiveByPlayer[turn.playerId] = turnProgressiveInLeg;

            final legWonByPlayer = legIsFinished && legWinnerId == turn.playerId;
            final legLostByPlayer =
                legIsFinished && legWinnerId != null && legWinnerId != turn.playerId;

            for (int dartIndex = 0; dartIndex < turn.throws.length; dartIndex++) {
              final dart = turn.throws[dartIndex];

              final dartProgressiveInLeg =
                  (dartProgressiveByPlayer[turn.playerId] ?? 0) + 1;
              dartProgressiveByPlayer[turn.playerId] = dartProgressiveInLeg;

              result.add(
                X01DartAtom(
                  matchId: matchId,
                  matchStartTime: record.startTime,
                  matchEndTime: record.endTime,
                  startingScore: startingScore,
                  matchWinnerName: record.winnerName,
                  setNumber: setNumber,
                  setIndex: setIndex,
                  setWinnerId: setWinnerId,
                  setStartTime: setStartTime,
                  setEndTime: setEndTime,
                  legNumber: legNumber,
                  legIndex: legIndex,
                  legWinnerId: legWinnerId,
                  legIsFinished: legIsFinished,
                  legWonByPlayer: legWonByPlayer,
                  legLostByPlayer: legLostByPlayer,
                  legStartTime: legStartTime,
                  legEndTime: legEndTime,
                  roundNumber: roundNumber,
                  roundIndex: roundIndex,
                  roundTimestamp: roundTimestamp,
                  turnNumber: turn.turnNumber,
                  turnIndexInRound: turnIndex,
                  turnProgressiveInLeg: turnProgressiveInLeg,
                  playerId: turn.playerId,
                  turnInitialScore: turn.initialScore,
                  turnScoreAfter: turn.score,
                  turnTotal: turn.total,
                  turnTotalMarks: turn.totalMarks,
                  turnDartsThrown: turn.throws.length,
                  turnIsBust: turn.isBust,
                  turnIsCheckout: turn.isCheckout,
                  turnTimestamp: turn.timestamp,
                  dart: dart,
                  dartIndexInTurn: dartIndex,
                  dartProgressiveInLeg: dartProgressiveInLeg,
                  isCheckoutDart: turn.isCheckout && dartIndex == turn.throws.length - 1,
                ),
              );
            }
          }
        }
      }
    }

    return result;
  }

  static Map? _asMap(dynamic value) {
    if (value is Map) return value;
    return null;
  }

  static List _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _string(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class X01DartDataset {
  final List<X01DartAtom> darts;

  const X01DartDataset({
    required this.darts,
  });

  bool get isEmpty => darts.isEmpty;
  bool get isNotEmpty => darts.isNotEmpty;

  int get totalDarts => darts.length;

  List<X01DartAtom> get scoringZoneDarts {
    return darts.where((d) => d.isScoringZone).toList();
  }

  List<X01DartAtom> get checkoutZoneDarts {
    return darts.where((d) => d.isCheckoutZone).toList();
  }

  List<X01DartAtom> get checkoutDarts {
    return darts.where((d) => d.isCheckoutDart).toList();
  }

  List<X01DartAtom> get bustDarts {
    return darts.where((d) => d.turnIsBust).toList();
  }

  List<X01DartAtom> get wonLegDarts {
    return darts.where((d) => d.legWonByPlayer).toList();
  }

  List<X01DartAtom> get lostLegDarts {
    return darts.where((d) => d.legLostByPlayer).toList();
  }

  List<X01LegSlice> get legs {
    final grouped = <String, List<X01DartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.legKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartTimestamp.compareTo(b.dartTimestamp));
      return X01LegSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  List<X01TurnSlice> get turns {
    final grouped = <String, List<X01DartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.turnKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartNumber.compareTo(b.dartNumber));
      return X01TurnSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  Map<int, List<X01DartAtom>> get byStartingScore {
    final grouped = <int, List<X01DartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.startingScore, () => []).add(dart);
    }

    return grouped;
  }
}

class X01DartAtom {
  final String matchId;
  final DateTime matchStartTime;
  final DateTime endTime;
  final int startingScore;
  final String matchWinnerName;

  final int setNumber;
  final int setIndex;
  final String? setWinnerId;
  final DateTime setStartTime;
  final DateTime? setEndTime;

  final int legNumber;
  final int legIndex;
  final String? legWinnerId;
  final bool legIsFinished;
  final bool legWonByPlayer;
  final bool legLostByPlayer;
  final DateTime legStartTime;
  final DateTime? legEndTime;

  final int roundNumber;
  final int roundIndex;
  final DateTime roundTimestamp;

  final int turnNumber;
  final int turnIndexInRound;
  final int turnProgressiveInLeg;
  final String playerId;
  final int turnInitialScore;
  final int turnScoreAfter;
  final int turnTotal;
  final int turnTotalMarks;
  final int turnDartsThrown;
  final bool turnIsBust;
  final bool turnIsCheckout;
  final DateTime turnTimestamp;

  final DartThrow dart;
  final int dartIndexInTurn;
  final int dartProgressiveInLeg;
  final bool isCheckoutDart;

  const X01DartAtom({
    required this.matchId,
    required this.matchStartTime,
    required DateTime matchEndTime,
    required this.startingScore,
    required this.matchWinnerName,
    required this.setNumber,
    required this.setIndex,
    required this.setWinnerId,
    required this.setStartTime,
    required this.setEndTime,
    required this.legNumber,
    required this.legIndex,
    required this.legWinnerId,
    required this.legIsFinished,
    required this.legWonByPlayer,
    required this.legLostByPlayer,
    required this.legStartTime,
    required this.legEndTime,
    required this.roundNumber,
    required this.roundIndex,
    required this.roundTimestamp,
    required this.turnNumber,
    required this.turnIndexInRound,
    required this.turnProgressiveInLeg,
    required this.playerId,
    required this.turnInitialScore,
    required this.turnScoreAfter,
    required this.turnTotal,
    required this.turnTotalMarks,
    required this.turnDartsThrown,
    required this.turnIsBust,
    required this.turnIsCheckout,
    required this.turnTimestamp,
    required this.dart,
    required this.dartIndexInTurn,
    required this.dartProgressiveInLeg,
    required this.isCheckoutDart,
  }) : endTime = matchEndTime;

  DateTime get matchEndTime => endTime;

  int get dartNumber => dart.dartNumber;
  int get dartTarget => dart.target;
  int get dartMultiplier => dart.multiplier;
  int get dartScore => dart.score;
  String get dartLabel => dart.label;
  DateTime get dartTimestamp => dart.timestamp;

  bool get isFirstDart => dartIndexInTurn == 0;
  bool get isSecondDart => dartIndexInTurn == 1;
  bool get isThirdDart => dartIndexInTurn == 2;

  bool get isMiss => dart.multiplier == 0 || dart.score == 0;
  bool get isSingle => dart.multiplier == 1;
  bool get isDouble => dart.multiplier == 2;
  bool get isTriple => dart.multiplier == 3;
  bool get isBull => dart.target == 25;
  bool get isScoringZone => turnInitialScore > 170;
  bool get isCheckoutZone => turnInitialScore <= 170;

  String get matchKey => matchId;
  String get setKey => '$matchId/S$setNumber';
  String get legKey => '$matchId/S$setNumber/L$legNumber';
  String get roundKey => '$matchId/S$setNumber/L$legNumber/R$roundNumber';
  String get turnKey => '$matchId/S$setNumber/L$legNumber/R$roundNumber/T$turnNumber/$playerId';
}

class X01TurnSlice {
  final List<X01DartAtom> darts;

  const X01TurnSlice({
    required this.darts,
  });

  X01DartAtom get first => darts.first;

  String get key => first.turnKey;
  String get playerId => first.playerId;
  DateTime get timestamp => first.turnTimestamp;

  int get startingScore => first.startingScore;
  int get initialScore => first.turnInitialScore;
  int get scoreAfter => first.turnScoreAfter;
  int get total {
    if (isBust) return 0;

    final scored = initialScore - scoreAfter;
    return scored > 0 ? scored : 0;
  }

  int get rawTotal => first.turnTotal;
  int get dartsThrown => darts.length;

  bool get isBust => first.turnIsBust;
  bool get isCheckout => first.turnIsCheckout;
  bool get isScoringZone => first.isScoringZone;
  bool get isCheckoutZone => first.isCheckoutZone;

  double get average {
    if (darts.isEmpty) return 0;

    // Usa la stessa logica del game state
    if (first.turnIsBust) return 0;

    final actualScore = first.turnInitialScore - first.turnScoreAfter;
    if (actualScore <= 0) return 0;

    return (actualScore / darts.length) * 3;
  }
}

class X01LegSlice {
  final List<X01DartAtom> darts;

  const X01LegSlice({
    required this.darts,
  });

  X01DartAtom get first => darts.first;

  String get key => first.legKey;
  String get playerId => first.playerId;
  DateTime get startTime => first.legStartTime;
  DateTime? get endTime => first.legEndTime;

  int get startingScore => first.startingScore;
  int get setNumber => first.setNumber;
  int get legNumber => first.legNumber;

  bool get isFinished => first.legIsFinished;
  bool get isWon => first.legWonByPlayer;
  bool get isLost => first.legLostByPlayer;

  List<X01TurnSlice> get turns {
    final grouped = <String, List<X01DartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.turnKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartNumber.compareTo(b.dartNumber));
      return X01TurnSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  List<X01TurnSlice> get scoringTurns {
    return turns.where((turn) => turn.isScoringZone).toList();
  }

  List<X01TurnSlice> get checkoutTurns {
    return turns.where((turn) => turn.isCheckoutZone).toList();
  }

  bool get hasCheckout {
    return turns.any((turn) => turn.isCheckout);
  }

  double get scoringAverage {
    final zoneDarts = darts.where((dart) => dart.isScoringZone).toList();
    if (zoneDarts.isEmpty) return 0;
    final totalScore = zoneDarts.fold<int>(0, (sum, dart) => sum + dart.dartScore);
    return (totalScore / zoneDarts.length) * 3;
  }

  double get checkoutAverage {
    final zoneDarts = darts.where((dart) => dart.isCheckoutZone).toList();
    if (zoneDarts.isEmpty) return 0;
    final totalScore = zoneDarts.fold<int>(0, (sum, dart) => sum + dart.dartScore);
    return (totalScore / zoneDarts.length) * 3;
  }
}