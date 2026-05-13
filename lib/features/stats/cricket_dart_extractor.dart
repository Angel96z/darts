import '../match_sync/domain/entities/local_match_record.dart';
import '../room_v4/domain/game_types/cricket_rules.dart';
import '../room_v4/domain/models/dart_throw.dart';
import '../room_v4/domain/models/player_turn.dart';

class CricketDartExtractor {
  const CricketDartExtractor();

  CricketDartDataset extract({
    required List<LocalMatchRecord> records,
    String? playerId,
  }) {
    final darts = <CricketDartAtom>[];

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

    return CricketDartDataset(darts: darts);
  }

  List<CricketDartAtom> _extractRecord({
    required LocalMatchRecord record,
    required String? playerId,
  }) {
    final result = <CricketDartAtom>[];

    final matchId = record.remoteId ?? record.localId;
    final isCutThroat = _bool(record.gameConfig['cutThroat']);
    final teamSize = record.teamSize;
    final playerToTeam = Map<String, String>.from(record.playerToTeam ?? const <String, String>{});
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
        final allTurnsInLeg = <_ReplayTurn>[];

        for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
          final roundMap = _asMap(rounds[roundIndex]);
          if (roundMap == null) continue;

          final roundNumber = _int(roundMap['roundNumber'], fallback: roundIndex + 1);
          final roundTimestamp = _date(roundMap['timestamp']) ?? legStartTime;
          final turns = _asList(roundMap['turns']);

          for (int turnIndex = 0; turnIndex < turns.length; turnIndex++) {
            final turnMap = _asMap(turns[turnIndex]);
            if (turnMap == null) continue;

            final turn = PlayerTurn.fromMap(Map<String, dynamic>.from(turnMap));

            allTurnsInLeg.add(
              _ReplayTurn(
                turn: turn,
                roundNumber: roundNumber,
                roundIndex: roundIndex,
                roundTimestamp: roundTimestamp,
                turnIndexInRound: turnIndex,
              ),
            );
          }
        }

        final allPlayerIds = _resolvePlayerIds(record: record, turns: allTurnsInLeg);
        final replayMarks = CricketRules.initializeMarks(allPlayerIds);
        final replayPoints = CricketRules.initializePoints(allPlayerIds);
        final turnProgressiveByPlayer = <String, int>{};
        final dartProgressiveByPlayer = <String, int>{};

        for (final replayTurn in allTurnsInLeg) {
          final turn = replayTurn.turn;
          final turnProgressiveInLeg = (turnProgressiveByPlayer[turn.playerId] ?? 0) + 1;
          turnProgressiveByPlayer[turn.playerId] = turnProgressiveInLeg;

          final legWonByPlayer = legIsFinished && legWinnerId == turn.playerId;
          final legLostByPlayer = legIsFinished && legWinnerId != null && legWinnerId != turn.playerId;

          for (int dartIndex = 0; dartIndex < turn.throws.length; dartIndex++) {
            final dart = turn.throws[dartIndex];
            final isMiss = dart.multiplier <= 0 || dart.target == 0;
            final isValidTarget = CricketRules.isValidCricketNumber(dart.target);
            final isTeamMode = teamSize > 1 && playerToTeam.containsKey(turn.playerId);

            final marksBefore = replayMarks[turn.playerId]?[dart.target] ?? 0;
            final wasAlreadyClosed = isValidTarget && marksBefore >= 3;
            final wasDeadNumber = isValidTarget && _isClosedForAll(
              target: dart.target,
              marks: replayMarks,
              playerIds: allPlayerIds,
            );

            int marksAfter = marksBefore;
            int rawMarksAdded = 0;
            int effectiveMarksAdded = 0;
            int pointsPerTarget = 0;
            int pointsGenerated = 0;
            int pointsReceivedByThrower = 0;
            List<String> targetsForPoints = const [];

            if (!isMiss && isValidTarget) {
              rawMarksAdded = dart.multiplier;
              effectiveMarksAdded = (3 - marksBefore).clamp(0, dart.multiplier);

              final calculation = CricketRules.calculateDart(
                currentPlayerMarks: marksBefore,
                multiplier: dart.multiplier,
                target: dart.target,
                allMarks: replayMarks,
                currentPlayerId: turn.playerId,
                allPlayerIds: allPlayerIds,
                isCutThroat: isCutThroat,
                isTeamMode: isTeamMode,
                playerToTeam: playerToTeam,
              );

              marksAfter = calculation.newTotalMarks;
              pointsPerTarget = calculation.pointsToAssign;
              targetsForPoints = calculation.targetsForPoints;
              pointsGenerated = pointsPerTarget * targetsForPoints.length;

              replayMarks[turn.playerId]![dart.target] = marksAfter;

              for (final targetPlayerId in targetsForPoints) {
                replayPoints[targetPlayerId] = (replayPoints[targetPlayerId] ?? 0) + pointsPerTarget;
              }

              if (targetsForPoints.contains(turn.playerId)) {
                pointsReceivedByThrower = pointsPerTarget;
              }
            }

            final dartProgressiveInLeg = (dartProgressiveByPlayer[turn.playerId] ?? 0) + 1;
            dartProgressiveByPlayer[turn.playerId] = dartProgressiveInLeg;

            final closedWithThisDart = isValidTarget && marksBefore < 3 && marksAfter >= 3;

            if (playerId == null || playerId == turn.playerId) {
              result.add(
                CricketDartAtom(
                  matchId: matchId,
                  matchStartTime: record.startTime,
                  matchEndTime: record.endTime,
                  matchWinnerName: record.winnerName,
                  isCutThroat: isCutThroat,
                  teamSize: teamSize,
                  playerToTeam: playerToTeam,
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
                  roundNumber: replayTurn.roundNumber,
                  roundIndex: replayTurn.roundIndex,
                  roundTimestamp: replayTurn.roundTimestamp,
                  turnNumber: turn.turnNumber,
                  turnIndexInRound: replayTurn.turnIndexInRound,
                  turnProgressiveInLeg: turnProgressiveInLeg,
                  playerId: turn.playerId,
                  turnTotalMarks: turn.totalMarks,
                  turnDartsThrown: turn.throws.length,
                  turnIsCheckout: turn.isCheckout,
                  turnTimestamp: turn.timestamp,
                  dart: dart,
                  dartIndexInTurn: dartIndex,
                  dartProgressiveInLeg: dartProgressiveInLeg,
                  marksBefore: marksBefore,
                  marksAfter: marksAfter,
                  rawMarksAdded: rawMarksAdded,
                  effectiveMarksAdded: effectiveMarksAdded,
                  pointsPerTarget: pointsPerTarget,
                  pointsGenerated: pointsGenerated,
                  pointsReceivedByThrower: pointsReceivedByThrower,
                  targetsForPoints: targetsForPoints,
                  cumulativePlayerPoints: replayPoints[turn.playerId] ?? 0,
                  isMiss: isMiss,
                  isValidCricketTarget: isValidTarget,
                  wasAlreadyClosed: wasAlreadyClosed,
                  wasDeadNumber: wasDeadNumber,
                  closedWithThisDart: closedWithThisDart,
                ),
              );
            }
          }
        }
      }
    }

    return result;
  }

  static List<String> _resolvePlayerIds({
    required LocalMatchRecord record,
    required List<_ReplayTurn> turns,
  }) {
    final ids = <String>{};

    for (final id in record.playerIds) {
      ids.add(id);
    }

    for (final turn in turns) {
      ids.add(turn.turn.playerId);
    }

    return ids.toList();
  }

  static bool _isClosedForAll({
    required int target,
    required Map<String, Map<int, int>> marks,
    required List<String> playerIds,
  }) {
    if (playerIds.isEmpty) return false;

    for (final playerId in playerIds) {
      if ((marks[playerId]?[target] ?? 0) < 3) return false;
    }

    return true;
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

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
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

class CricketDartDataset {
  final List<CricketDartAtom> darts;

  const CricketDartDataset({
    required this.darts,
  });

  bool get isEmpty => darts.isEmpty;
  bool get isNotEmpty => darts.isNotEmpty;

  int get totalDarts => darts.length;

  List<CricketDartAtom> get missDarts {
    return darts.where((d) => d.isMiss).toList();
  }

  List<CricketDartAtom> get validTargetDarts {
    return darts.where((d) => d.isValidCricketTarget && !d.isMiss).toList();
  }

  List<CricketDartAtom> get scoringDarts {
    return darts.where((d) => d.pointsGenerated > 0).toList();
  }

  List<CricketDartAtom> get closingDarts {
    return darts.where((d) => d.closedWithThisDart).toList();
  }

  double get missPercentage {
    if (darts.isEmpty) return 0;
    return (missDarts.length / darts.length) * 100;
  }

  int get totalPointsGenerated {
    return darts.fold<int>(0, (sum, dart) => sum + dart.pointsGenerated);
  }

  int get totalMarksHit {
    return validTargetDarts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);
  }

  int get totalEffectiveMarks {
    return validTargetDarts.fold<int>(0, (sum, dart) => sum + dart.effectiveMarksAdded);
  }

  double get rawMultiplierAverage {
    if (validTargetDarts.isEmpty) return 0;
    return totalMarksHit / validTargetDarts.length;
  }

  double get effectiveMultiplierAverage {
    if (validTargetDarts.isEmpty) return 0;
    return totalEffectiveMarks / validTargetDarts.length;
  }

  List<CricketTurnSlice> get turns {
    final grouped = <String, List<CricketDartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.turnKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartNumber.compareTo(b.dartNumber));
      return CricketTurnSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  List<CricketLegSlice> get legs {
    final grouped = <String, List<CricketDartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.legKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartTimestamp.compareTo(b.dartTimestamp));
      return CricketLegSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  Map<int, CricketTargetStats> get targetStats {
    return {
      for (final target in CricketRules.cricketNumbers)
        target: CricketTargetStats(
          target: target,
          darts: darts.where((d) => d.dartTarget == target && !d.isMiss).toList(),
        ),
    };
  }

  CricketTargetStats statsForTarget(int target) {
    return targetStats[target] ?? CricketTargetStats(target: target, darts: const []);
  }
}

class CricketDartAtom {
  final String matchId;
  final DateTime matchStartTime;
  final DateTime endTime;
  final String matchWinnerName;
  final bool isCutThroat;
  final int teamSize;
  final Map<String, String> playerToTeam;

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
  final int turnTotalMarks;
  final int turnDartsThrown;
  final bool turnIsCheckout;
  final DateTime turnTimestamp;

  final DartThrow dart;
  final int dartIndexInTurn;
  final int dartProgressiveInLeg;

  final int marksBefore;
  final int marksAfter;
  final int rawMarksAdded;
  final int effectiveMarksAdded;
  final int pointsPerTarget;
  final int pointsGenerated;
  final int pointsReceivedByThrower;
  final List<String> targetsForPoints;
  final int cumulativePlayerPoints;

  final bool isMiss;
  final bool isValidCricketTarget;
  final bool wasAlreadyClosed;
  final bool wasDeadNumber;
  final bool closedWithThisDart;

  const CricketDartAtom({
    required this.matchId,
    required this.matchStartTime,
    required DateTime matchEndTime,
    required this.matchWinnerName,
    required this.isCutThroat,
    required this.teamSize,
    required this.playerToTeam,
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
    required this.turnTotalMarks,
    required this.turnDartsThrown,
    required this.turnIsCheckout,
    required this.turnTimestamp,
    required this.dart,
    required this.dartIndexInTurn,
    required this.dartProgressiveInLeg,
    required this.marksBefore,
    required this.marksAfter,
    required this.rawMarksAdded,
    required this.effectiveMarksAdded,
    required this.pointsPerTarget,
    required this.pointsGenerated,
    required this.pointsReceivedByThrower,
    required this.targetsForPoints,
    required this.cumulativePlayerPoints,
    required this.isMiss,
    required this.isValidCricketTarget,
    required this.wasAlreadyClosed,
    required this.wasDeadNumber,
    required this.closedWithThisDart,
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

  bool get isSingle => dart.multiplier == 1;
  bool get isDouble => dart.multiplier == 2;
  bool get isTriple => dart.multiplier == 3;
  bool get isBull => dart.target == 25;
  bool get isTeamMode => teamSize > 1;
  bool get scoredForSelf => pointsReceivedByThrower > 0;
  bool get generatedPointsForOpponents => pointsGenerated > 0 && pointsReceivedByThrower == 0;

  String? get teamId => playerToTeam[playerId];

  String get matchKey => matchId;
  String get setKey => '$matchId/S$setNumber';
  String get legKey => '$matchId/S$setNumber/L$legNumber';
  String get roundKey => '$matchId/S$setNumber/L$legNumber/R$roundNumber';
  String get turnKey => '$matchId/S$setNumber/L$legNumber/R$roundNumber/T$turnNumber/$playerId';
}

class CricketTargetStats {
  final int target;
  final List<CricketDartAtom> darts;

  const CricketTargetStats({
    required this.target,
    required this.darts,
  });

  int get totalDarts => darts.length;

  int get marksHit {
    return darts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);
  }

  int get effectiveMarks {
    return darts.fold<int>(0, (sum, dart) => sum + dart.effectiveMarksAdded);
  }

  int get pointsGenerated {
    return darts.fold<int>(0, (sum, dart) => sum + dart.pointsGenerated);
  }

  int get scoringDartsCount {
    return darts.where((dart) => dart.pointsGenerated > 0).length;
  }

  bool get isClosed {
    return darts.any((dart) => dart.marksAfter >= 3);
  }

  int get dartsToClose {
    final index = darts.indexWhere((dart) => dart.closedWithThisDart);
    return index < 0 ? 0 : index + 1;
  }

  double get rawMultiplierAverage {
    if (darts.isEmpty) return 0;
    return marksHit / darts.length;
  }

  double get effectiveCloseMultiplierAverage {
    if (dartsToClose == 0) return 0;
    return 3 / dartsToClose;
  }

  double get rawCloseMultiplierAverage {
    if (dartsToClose == 0) return 0;
    final closeDarts = darts.take(dartsToClose).toList();
    final marks = closeDarts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);
    return marks / dartsToClose;
  }

  double get closeEfficiency {
    if (dartsToClose == 0) return 0;
    return 3 / (dartsToClose * 3);
  }
}

class CricketTurnSlice {
  final List<CricketDartAtom> darts;

  const CricketTurnSlice({
    required this.darts,
  });

  CricketDartAtom get first => darts.first;

  String get key => first.turnKey;
  String get playerId => first.playerId;
  DateTime get timestamp => first.turnTimestamp;

  int get dartsThrown => darts.length;
  int get marksHit => darts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);
  int get effectiveMarks => darts.fold<int>(0, (sum, dart) => sum + dart.effectiveMarksAdded);
  int get pointsGenerated => darts.fold<int>(0, (sum, dart) => sum + dart.pointsGenerated);
  int get pointsReceivedByThrower => darts.fold<int>(0, (sum, dart) => sum + dart.pointsReceivedByThrower);
  int get missCount => darts.where((dart) => dart.isMiss).length;

  bool get isCheckout => first.turnIsCheckout;

  double get missPercentage {
    if (darts.isEmpty) return 0;
    return (missCount / darts.length) * 100;
  }
}

class CricketLegSlice {
  final List<CricketDartAtom> darts;

  const CricketLegSlice({
    required this.darts,
  });

  CricketDartAtom get first => darts.first;

  String get key => first.legKey;
  String get playerId => first.playerId;
  DateTime get startTime => first.legStartTime;
  DateTime? get endTime => first.legEndTime;

  int get setNumber => first.setNumber;
  int get legNumber => first.legNumber;

  bool get isFinished => first.legIsFinished;
  bool get isWon => first.legWonByPlayer;
  bool get isLost => first.legLostByPlayer;

  int get totalDarts => darts.length;
  int get missCount => darts.where((dart) => dart.isMiss).length;
  int get marksHit => darts.fold<int>(0, (sum, dart) => sum + dart.rawMarksAdded);
  int get effectiveMarks => darts.fold<int>(0, (sum, dart) => sum + dart.effectiveMarksAdded);
  int get pointsGenerated => darts.fold<int>(0, (sum, dart) => sum + dart.pointsGenerated);

  double get missPercentage {
    if (darts.isEmpty) return 0;
    return (missCount / darts.length) * 100;
  }

  List<CricketTurnSlice> get turns {
    final grouped = <String, List<CricketDartAtom>>{};

    for (final dart in darts) {
      grouped.putIfAbsent(dart.turnKey, () => []).add(dart);
    }

    final result = grouped.values.map((items) {
      items.sort((a, b) => a.dartNumber.compareTo(b.dartNumber));
      return CricketTurnSlice(darts: items);
    }).toList();

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }
}

class _ReplayTurn {
  final PlayerTurn turn;
  final int roundNumber;
  final int roundIndex;
  final DateTime roundTimestamp;
  final int turnIndexInRound;

  const _ReplayTurn({
    required this.turn,
    required this.roundNumber,
    required this.roundIndex,
    required this.roundTimestamp,
    required this.turnIndexInRound,
  });
}