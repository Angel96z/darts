class CheckoutSuggestion {
  static List<String> getSuggestions({
    required int score,
    required int dartsLeft,
    required String outMode,
  }) {
    if (score <= 0 || dartsLeft <= 0) return [];

    final int safeDartsLeft = dartsLeft.clamp(1, 3).toInt();

    final bool doubleOut = outMode == 'double';
    final bool tripleOut = outMode == 'triple';
    final bool singleOut = outMode == 'single';

    final route = _findBestCheckoutRoute(
      score: score,
      dartsLeft: safeDartsLeft,
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    );

    if (route != null) {
      return route.map((d) => d.label).toList();
    }

    final setup = _findSetupDart(
      score: score,
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    );

    if (setup != null) return [setup.label];

    return [];
  }

  static List<_Dart>? _findBestCheckoutRoute({
    required int score,
    required int dartsLeft,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (score <= 0 || dartsLeft <= 0) return null;

    final maxScore = _maxReachableScore(
      dartsLeft: dartsLeft,
      doubleOut: doubleOut,
    );

    if (score > maxScore) return null;
    if (doubleOut) {
      final strategicRoute = _findStrategicDoubleOutRoute(
        score: score,
        dartsLeft: dartsLeft,
      );

      if (strategicRoute != null) return strategicRoute;
    }
    _RouteCandidate? best;

    for (int len = 1; len <= dartsLeft; len++) {
      _collectRoutes(
        score: score,
        dartsLeft: len,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
        current: const [],
        onRoute: (route) {
          final rank = _routeRank(
            route: route,
            doubleOut: doubleOut,
            tripleOut: tripleOut,
            singleOut: singleOut,
          );

          if (best == null || rank < best!.rank) {
            best = _RouteCandidate(route, rank);
          }
        },
      );

      if (best != null) return best!.route;
    }

    return null;
  }
  static List<_Dart>? _findStrategicDoubleOutRoute({
    required int score,
    required int dartsLeft,
  }) {
    final labels = _strategicDoubleOutRoutes[score];
    if (labels == null) return null;
    if (labels.length > dartsLeft) return null;

    return labels.map(_dartFromLabel).toList();
  }

  static int _maxReachableScore({
    required int dartsLeft,
    required bool doubleOut,
  }) {
    if (dartsLeft <= 0) return 0;

    if (doubleOut) {
      if (dartsLeft == 1) return 50;
      if (dartsLeft == 2) return 110;
      return 170;
    }

    return dartsLeft * 60;
  }

  static void _collectRoutes({
    required int score,
    required int dartsLeft,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
    required List<_Dart> current,
    required void Function(List<_Dart> route) onRoute,
  }) {
    if (dartsLeft <= 0) return;

    if (dartsLeft == 1) {
      for (final dart in _getFinishingDarts(
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      )) {
        if (dart.value == score) {
          onRoute([...current, dart]);
        }
      }
      return;
    }

    for (final dart in _getScoringDarts()) {
      if (dart.value >= score) continue;

      final remaining = score - dart.value;
      if (remaining <= 1) continue;

      _collectRoutes(
        score: remaining,
        dartsLeft: dartsLeft - 1,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
        current: [...current, dart],
        onRoute: onRoute,
      );
    }
  }

  static int _routeRank({
    required List<_Dart> route,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (route.isEmpty) return 999999;

    int rank = route.length * 10000;

    final finish = route.last;

    if (doubleOut) {
      rank += _doubleFinishRank(finish.label) * 100;
    } else if (tripleOut) {
      rank += _tripleFinishRank(finish.label) * 100;
    } else {
      rank += _singleFinishRank(finish.label) * 100;
    }

    for (int i = 0; i < route.length - 1; i++) {
      rank += _setupThrowRank(route[i], i);
    }

    return rank;
  }

  static int _doubleFinishRank(String label) {
    const preferred = [
      'D20',
      'D16',
      'D18',
      'D12',
      'D10',
      'D8',
      'D4',
      'D2',
      'D1',
      'D25',
      'D14',
      'D6',
      'D15',
      'D13',
      'D11',
      'D9',
      'D7',
      'D5',
      'D3',
      'D17',
      'D19',
    ];

    final index = preferred.indexOf(label);
    return index == -1 ? 999 : index;
  }

  static int _tripleFinishRank(String label) {
    const preferred = [
      'T20',
      'T19',
      'T18',
      'T17',
      'T16',
      'T15',
      'T14',
      'T13',
      'T12',
      'T11',
      'T10',
      'T9',
      'T8',
      'T7',
      'T6',
      'T5',
      'T4',
      'T3',
      'T2',
      'T1',
    ];

    final index = preferred.indexOf(label);
    return index == -1 ? 999 : index;
  }

  static int _singleFinishRank(String label) {
    const preferred = [
      'D25',
      'T20',
      'T19',
      'T18',
      'T17',
      'T16',
      'T15',
      'D20',
      'D16',
      'S25',
      'S20',
      'S19',
      'S18',
      'S17',
      'S16',
      'S15',
    ];

    final index = preferred.indexOf(label);
    return index == -1 ? 500 + _labelValue(label) : index;
  }

  static int _setupThrowRank(_Dart dart, int position) {
    const preferred = [
      'T20',
      'T19',
      'T18',
      'T17',
      'T16',
      'T15',
      'T14',
      'T13',
      'T12',
      'T11',
      'T10',
      'S20',
      'S19',
      'S18',
      'S17',
      'S16',
      'S15',
      'S14',
      'S13',
      'S12',
      'S11',
      'S10',
      'S9',
      'S8',
      'S7',
      'S6',
      'S5',
      'S4',
      'S3',
      'S2',
      'S1',
      'S25',
      'D25',
    ];

    final index = preferred.indexOf(dart.label);
    if (index != -1) return position * 100 + index;

    if (dart.label.startsWith('D')) return 700 + _labelValue(dart.label);
    return 900 + _labelValue(dart.label);
  }

  static _Dart? _findSetupDart({
    required int score,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    _Dart? best;
    int bestRank = 999999;

    for (final dart in _getSetupDarts()) {
      if (dart.value >= score) continue;

      final remaining = score - dart.value;
      if (remaining <= 1) continue;

      final rank = _leaveRank(
        remaining: remaining,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      );

      if (rank < bestRank) {
        best = dart;
        bestRank = rank;
      }
    }

    return best;
  }

  static int _leaveRank({
    required int remaining,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    final preferred = _preferredLeaves(
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    );

    final index = preferred.indexOf(remaining);
    if (index != -1) return index;

    final canCheckout = _findBestCheckoutRoute(
      score: remaining,
      dartsLeft: 3,
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    ) !=
        null;

    if (canCheckout) return 1000 + remaining;

    return 999999;
  }

  static List<int> _preferredLeaves({
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (tripleOut) {
      return const [
        60,
        57,
        54,
        51,
        48,
        45,
        42,
        39,
        36,
        33,
        30,
        27,
        24,
        21,
        18,
        15,
        12,
        9,
        6,
        3,
      ];
    }

    if (singleOut) {
      return const [
        60,
        57,
        54,
        51,
        50,
        40,
        32,
        36,
        24,
        20,
        16,
        12,
        10,
        8,
        6,
        4,
        2,
        1,
      ];
    }

    return const [
      32,
      40,
      36,
      24,
      16,
      20,
      50,
      12,
      8,
      10,
      4,
      2,
      6,
    ];
  }

  static List<_Dart> _getSetupDarts() {
    return [
      for (final label in const [
        'S20',
        'S19',
        'S18',
        'S17',
        'S16',
        'S15',
        'S14',
        'S13',
        'S12',
        'S11',
        'S10',
        'S9',
        'S8',
        'S7',
        'S6',
        'S5',
        'S4',
        'S3',
        'S2',
        'S1',
        'S25',
        'T20',
        'T19',
        'T18',
        'T17',
        'T16',
        'T15',
        'T14',
        'T13',
        'T12',
        'T11',
        'T10',
        'D25',
        'D20',
        'D16',
        'D18',
        'D12',
        'D10',
        'D8',
        'D4',
        'D2',
        'D1',
      ])
        _dartFromLabel(label),
    ];
  }

  static List<_Dart> _getScoringDarts() {
    return [
      for (final label in const [
        'T20',
        'T19',
        'T18',
        'T17',
        'T16',
        'T15',
        'T14',
        'T13',
        'T12',
        'T11',
        'T10',
        'T9',
        'T8',
        'T7',
        'T6',
        'T5',
        'T4',
        'T3',
        'T2',
        'T1',
        'S20',
        'S19',
        'S18',
        'S17',
        'S16',
        'S15',
        'S14',
        'S13',
        'S12',
        'S11',
        'S10',
        'S9',
        'S8',
        'S7',
        'S6',
        'S5',
        'S4',
        'S3',
        'S2',
        'S1',
        'S25',
        'D25',
        'D20',
        'D16',
        'D18',
        'D12',
        'D10',
        'D8',
        'D4',
        'D2',
        'D1',
      ])
        _dartFromLabel(label),
    ];
  }

  static List<_Dart> _getFinishingDarts({
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (tripleOut) {
      return [
        for (final label in const [
          'T20',
          'T19',
          'T18',
          'T17',
          'T16',
          'T15',
          'T14',
          'T13',
          'T12',
          'T11',
          'T10',
          'T9',
          'T8',
          'T7',
          'T6',
          'T5',
          'T4',
          'T3',
          'T2',
          'T1',
        ])
          _dartFromLabel(label),
      ];
    }

    if (doubleOut) {
      return [
        for (final label in const [
          'D20',
          'D16',
          'D18',
          'D12',
          'D10',
          'D8',
          'D4',
          'D2',
          'D1',
          'D25',
          'D14',
          'D6',
          'D15',
          'D13',
          'D11',
          'D9',
          'D7',
          'D5',
          'D3',
          'D17',
          'D19',
        ])
          _dartFromLabel(label),
      ];
    }

    if (singleOut) {
      return [
        const _Dart('D25', 50),
        for (int n = 20; n >= 1; n--) _Dart('T$n', n * 3),
        for (int n = 20; n >= 1; n--) _Dart('D$n', n * 2),
        const _Dart('S25', 25),
        for (int n = 20; n >= 1; n--) _Dart('S$n', n),
      ];
    }

    return [];
  }

  static _Dart _dartFromLabel(String label) {
    final prefix = label.substring(0, 1);
    final number = int.parse(label.substring(1));

    if (prefix == 'S') return _Dart(label, number == 25 ? 25 : number);
    if (prefix == 'D') return _Dart(label, number == 25 ? 50 : number * 2);
    return _Dart(label, number * 3);
  }

  static int _labelValue(String label) {
    return _dartFromLabel(label).value;
  }


  static const Map<int, List<String>> _strategicDoubleOutRoutes = {
    170: ['T20', 'T20', 'D25'],
    167: ['T20', 'T19', 'D25'],
    164: ['T20', 'T18', 'D25'],
    161: ['T20', 'T17', 'D25'],

    160: ['T20', 'T20', 'D20'],
    158: ['T20', 'T20', 'D19'],
    157: ['T20', 'T19', 'D20'],
    156: ['T20', 'T20', 'D18'],
    155: ['T20', 'T19', 'D19'],
    154: ['T20', 'T18', 'D20'],
    153: ['T20', 'T19', 'D18'],
    152: ['T20', 'T20', 'D16'],
    151: ['T20', 'T17', 'D20'],
    150: ['T20', 'T18', 'D18'],
    149: ['T20', 'T19', 'D16'],
    148: ['T20', 'T20', 'D14'],
    147: ['T20', 'T17', 'D18'],
    146: ['T20', 'T18', 'D16'],
    145: ['T20', 'T15', 'D20'],
    144: ['T20', 'T20', 'D12'],
    143: ['T20', 'T17', 'D16'],
    142: ['T20', 'T14', 'D20'],
    141: ['T20', 'T19', 'D12'],

    140: ['T20', 'T20', 'D10'],
    139: ['T19', 'T14', 'D20'],
    138: ['T20', 'T18', 'D12'],
    137: ['T19', 'T20', 'D10'],
    136: ['T20', 'T20', 'D8'],
    135: ['T20', 'T17', 'D12'],
    134: ['T20', 'T14', 'D16'],
    133: ['T20', 'T19', 'D8'],
    132: ['T20', 'T16', 'D12'],
    131: ['T20', 'T13', 'D16'],
    130: ['T20', 'T18', 'D8'],
    129: ['T19', 'T16', 'D12'],
    128: ['T18', 'T18', 'D10'],
    127: ['T20', 'T17', 'D8'],
    126: ['T19', 'T19', 'D6'],
    125: ['T20', 'T19', 'D4'],
    124: ['T20', 'T16', 'D8'],
    123: ['T19', 'T16', 'D9'],
    122: ['T18', 'T18', 'D7'],
    121: ['T20', 'T11', 'D14'],

    120: ['T20', 'S20', 'D20'],
    119: ['T19', 'T10', 'D16'],
    118: ['T20', 'S18', 'D20'],
    117: ['T20', 'S17', 'D20'],
    116: ['T20', 'S16', 'D20'],
    115: ['T20', 'S15', 'D20'],
    114: ['T20', 'S14', 'D20'],
    113: ['T19', 'S16', 'D20'],
    112: ['T20', 'S20', 'D16'],
    111: ['T20', 'S19', 'D16'],
    110: ['T20', 'D25'],
    109: ['T20', 'S17', 'D16'],
    108: ['T20', 'S16', 'D16'],
    107: ['T19', 'S18', 'D16'],
    106: ['T20', 'S14', 'D16'],
    105: ['T20', 'S13', 'D16'],
    104: ['T18', 'S18', 'D16'],
    103: ['T19', 'S14', 'D16'],
    102: ['T20', 'S10', 'D16'],
    101: ['T17', 'D25'],
    100: ['T20', 'D20'],

    99: ['T19', 'S10', 'D16'],
    98: ['T20', 'D19'],
    97: ['T19', 'D20'],
    96: ['T20', 'D18'],
    95: ['T19', 'D19'],
    94: ['T18', 'D20'],
    93: ['T19', 'D18'],
    92: ['T20', 'D16'],
    91: ['T17', 'D20'],
    90: ['T18', 'D18'],
    89: ['T19', 'D16'],
    88: ['T20', 'D14'],
    87: ['T17', 'D18'],
    86: ['T18', 'D16'],
    85: ['T15', 'D20'],
    84: ['T20', 'D12'],
    83: ['T17', 'D16'],
    82: ['D25', 'D16'],
    81: ['T15', 'D18'],
    80: ['T20', 'D10'],
    79: ['T19', 'D11'],
    78: ['T18', 'D12'],
    77: ['T19', 'D10'],
    76: ['T20', 'D8'],
    75: ['T17', 'D12'],
    74: ['T14', 'D16'],
    73: ['T19', 'D8'],
    72: ['T16', 'D12'],
    71: ['T13', 'D16'],
    70: ['T18', 'D8'],
  };

}

class _Dart {
  final String label;
  final int value;

  const _Dart(this.label, this.value);
}

class _RouteCandidate {
  final List<_Dart> route;
  final int rank;

  const _RouteCandidate(this.route, this.rank);
}