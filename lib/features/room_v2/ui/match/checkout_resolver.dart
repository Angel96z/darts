
import '../../games_darts.dart';
import '../../room_data.dart';

class CheckoutPlan {
  final String kind; // checkout | setup | none | blocked
  final List<String> darts; // lunghezza 3
  final bool cannotCheckout;

  const CheckoutPlan({
    required this.kind,
    required this.darts,
    required this.cannotCheckout,
  });
}

class CheckoutResolver {
  static CheckoutPlan resolve(
      RoomData data,
      Map<String, dynamic> player,
      ) {
    if (data.game.type != GameType.x01) {
      return const CheckoutPlan(
        kind: 'none',
        darts: ['-', '-', '-'],
        cannotCheckout: false,
      );
    }

    final score = (player['score'] as int?) ?? 0;
    final throws = List<Map<String, dynamic>>.from(player['throws'] ?? []);
    final labels = throws.map((t) => t['label']?.toString() ?? '-').toList();

    final dartsUsed = labels.length;
    final dartsLeft = 3 - dartsUsed;

    final cannotCheckout = player['cannotCheckout'] == true;

    if (cannotCheckout) {
      return CheckoutPlan(
        kind: 'blocked',
        darts: _merge(labels, ['-', '-', '-']),
        cannotCheckout: true,
      );
    }

    if (dartsLeft <= 0 || score <= 1) {
      return CheckoutPlan(
        kind: 'none',
        darts: _merge(labels, ['-', '-', '-']),
        cannotCheckout: false,
      );
    }

    final rawCheckout = _checkoutTable[score]?[dartsLeft];

    final checkout = _filterValidCheckouts(
      data,
      rawCheckout,
    );

    if (checkout.isNotEmpty) {
      return CheckoutPlan(
        kind: 'checkout',
        darts: _merge(labels, checkout.first),
        cannotCheckout: false,
      );
    }

    final setup = _setupTable[score]?[dartsLeft];
    if (setup != null && setup.isNotEmpty) {
      return CheckoutPlan(
        kind: 'setup',
        darts: _merge(labels, setup.first),
        cannotCheckout: false,
      );
    }

    return CheckoutPlan(
      kind: 'none',
      darts: _merge(labels, ['-', '-', '-']),
      cannotCheckout: false,
    );
  }

  static List<String> _merge(
      List<String> real,
      List<String> suggestion,
      ) {
    final result = List<String>.filled(3, '-');

    for (int i = 0; i < 3; i++) {
      if (i < real.length) {
        result[i] = real[i];
      } else {
        result[i] = suggestion[i];
      }
    }

    return result;
  }

  // 🔥 BASE TABLE (espandi tu)
  static final Map<int, Map<int, List<List<String>>>> _checkoutTable = {
    170: {
      3: [
        ['T20', 'T20', 'D25'],
      ],
    },
    167: {
      3: [
        ['T20', 'T19', 'D25'],
      ],
    },
    160: {
      3: [
        ['T20', 'T20', 'D20'],
      ],
    },
    110: {
      3: [
        ['T20', '10', 'D20'],
        ['T20', '18', 'D16'],
      ],
    },
    50: {
      1: [
        ['D25', '-', '-'],
      ],
      2: [
        ['10', 'D20', '-'],
        ['18', 'D16', '-'],
      ],
    },
    48: {
      2: [
        ['S16', 'D16', '-'],
      ],
    },
  };

  static final Map<int, Map<int, List<List<String>>>> _setupTable = {
    162: {
      2: [
        ['T20', 'T18', '-'],
      ],
    },
    169: {
      3: [
        ['T20', 'T20', '25'],
      ],
    },
  };
  static List<List<String>> _filterValidCheckouts(
      RoomData data,
      List<List<String>>? options,
      ) {
    if (options == null) return [];

    final doubleOut = data.game.doubleOut == true;
    final tripleOut = data.game.tripleOut == true;

    return options.where((seq) {
      final last = seq.lastWhere(
            (e) => e != '-',
        orElse: () => '-',
      );

      if (last == '-') return false;

      final isDouble = last.startsWith('D');
      final isTriple = last.startsWith('T');

      if (doubleOut) return isDouble;
      if (tripleOut) return isDouble || isTriple;

      return true;
    }).toList();
  }


}

