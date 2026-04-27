// lib/features/game/presentation/widgets/checkout_suggestion.dart

class CheckoutSuggestion {
  /// Calcola i consigli per le freccette rimanenti.
  ///
  /// Restituisce SEMPRE 3 posizioni:
  /// - dartsLeft == 3 -> usa posizione 0, 1, 2
  /// - dartsLeft == 2 -> usa posizione 1, 2
  /// - dartsLeft == 1 -> usa posizione 2
  ///
  /// Esempi:
  /// - 3 darts: ['T20', 'T20', 'D20']
  /// - 2 darts: ['', 'T20', 'D20']
  /// - 1 dart : ['', '', 'S11']
  ///
  /// Se non c'è checkout diretto, prova a suggerire un setup utile.
  static List<String> getSuggestions({
    required int score,
    required int dartsLeft,
    required String outMode, // 'double', 'triple', 'single'
  }) {
    if (score <= 0 || dartsLeft <= 0) return [];

    final safeDartsLeft = dartsLeft.clamp(1, 3);

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

    if (setup != null) {
      return [setup.label];
    }

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
      tripleOut: tripleOut,
      singleOut: singleOut,
    );

    if (score > maxScore) return null;

    for (int len = 1; len <= dartsLeft; len++) {
      final route = _findRoute(
        score: score,
        dartsLeft: len,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      );

      if (route != null) return route;
    }

    return null;
  }

  static int _maxReachableScore({
    required int dartsLeft,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (dartsLeft <= 0) return 0;

    if (doubleOut) {
      if (dartsLeft == 1) return 50;
      if (dartsLeft == 2) return 110;
      return 170;
    }

    return dartsLeft * 60;
  }

  static List<_Dart>? _findRoute({
    required int score,
    required int dartsLeft,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (dartsLeft <= 0) return null;

    if (dartsLeft == 1) {
      for (final d in _getFinishingDarts(
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      )) {
        if (d.value == score) return [d];
      }

      return null;
    }

    for (final d in _getAllDarts()) {
      if (d.value >= score) continue;

      final remaining = score - d.value;

      if (remaining <= 1) continue;

      final next = _findRoute(
        score: remaining,
        dartsLeft: dartsLeft - 1,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      );

      if (next != null) {
        return [d, ...next];
      }
    }

    return null;
  }

  /// Se non puoi chiudere ora, scegli una freccetta utile per lasciare
  /// un numero buono al turno successivo.
  static _Dart? _findSetupDart({
    required int score,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    _Dart? best;
    int bestRank = 9999;

    for (final d in _getSetupDarts()) {
      if (d.value >= score) continue;

      final remaining = score - d.value;

      if (remaining <= 1) continue;

      final rank = _leaveRank(
        remaining: remaining,
        doubleOut: doubleOut,
        tripleOut: tripleOut,
        singleOut: singleOut,
      );

      if (rank < bestRank) {
        best = d;
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

    if (_canCheckoutNextTurn(
      score: remaining,
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    )) {
      return 100 + remaining;
    }

    return 9999;
  }

  static bool _canCheckoutNextTurn({
    required int score,
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    return _findBestCheckoutRoute(
      score: score,
      dartsLeft: 3,
      doubleOut: doubleOut,
      tripleOut: tripleOut,
      singleOut: singleOut,
    ) !=
        null;
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
      50,
      24,
      20,
      16,
      12,
      10,
      8,
      6,
      4,
      2,
    ];
  }

  /// Tiri ordinati per setup.
  /// Prima i singoli utili, poi bull, poi doppie/triple.
  /// Questo evita consigli stupidi tipo T20 quando basta S11 per lasciare 50.
  static List<_Dart> _getSetupDarts() => [
    for (int n = 20; n >= 1; n--) _Dart('S$n', n),
    const _Dart('S25', 25),
    for (int n = 20; n >= 1; n--) _Dart('D$n', n * 2),
    const _Dart('D25', 50),
    for (int n = 20; n >= 1; n--) _Dart('T$n', n * 3),
  ];

  static List<_Dart> _getAllDarts() => [
    for (int n = 20; n >= 1; n--) _Dart('T$n', n * 3),
    const _Dart('D25', 50),
    for (int n = 20; n >= 1; n--) _Dart('D$n', n * 2),
    const _Dart('S25', 25),
    for (int n = 20; n >= 1; n--) _Dart('S$n', n),
  ];

  static List<_Dart> _getFinishingDarts({
    required bool doubleOut,
    required bool tripleOut,
    required bool singleOut,
  }) {
    if (tripleOut) {
      return [
        for (int n = 20; n >= 1; n--) _Dart('T$n', n * 3),
      ];
    }

    if (doubleOut) {
      return [
        const _Dart('D25', 50),
        for (int n = 20; n >= 1; n--) _Dart('D$n', n * 2),
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
}

class _Dart {
  final String label;
  final int value;

  const _Dart(this.label, this.value);
}