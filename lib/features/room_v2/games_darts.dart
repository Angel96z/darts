import 'package:flutter/material.dart';

enum GameType {
  x01,
  cricket,
}
enum MatchMode { firstTo, bestOf }
enum MatchUnit { legs, sets }
/// Config base comune a tutti i giochi
class GameConfig {
  final GameType type;

  // opzionali per specifici giochi
  final int? startingScore; // x01
  final bool? tripleOut;    // x01
  final bool? doubleOut;    // x01
  final bool? doubleIn;     // x01

  final bool? cutThroat;    // cricket

  const GameConfig({
    required this.type,
    this.startingScore,
    this.tripleOut,
    this.doubleOut,
    this.doubleIn,
    this.cutThroat,
  });

  /// Factory pulite per partire da 0
  factory GameConfig.x01({
    int startingScore = 501,
    bool tripleOut = false,
    bool doubleOut = true,
    bool doubleIn = false,
  }) {
    return GameConfig(
      type: GameType.x01,
      startingScore: startingScore,
      tripleOut: tripleOut,
      doubleOut: doubleOut,
      doubleIn: doubleIn,
    );
  }

  factory GameConfig.cricket({
    bool cutThroat = false,
  }) {
    return GameConfig(
      type: GameType.cricket,
      cutThroat: cutThroat,
    );
  }

  GameConfig copyWith({
    GameType? type,
    int? startingScore,
    bool? tripleOut,
    bool? doubleOut,
    bool? doubleIn,
    bool? cutThroat,
  }) {
    return GameConfig(
      type: type ?? this.type,
      startingScore: startingScore ?? this.startingScore,
      tripleOut: tripleOut ?? this.tripleOut,
      doubleOut: doubleOut ?? this.doubleOut,
      doubleIn: doubleIn ?? this.doubleIn,
      cutThroat: cutThroat ?? this.cutThroat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'startingScore': startingScore,
      'tripleOut': tripleOut,
      'doubleOut': doubleOut,
      'doubleIn': doubleIn,
      'cutThroat': cutThroat,
    };
  }

  factory GameConfig.fromMap(Map<String, dynamic> map) {
    return GameConfig(
      type: GameType.values.firstWhere((e) => e.name == map['type']),
      startingScore: map['startingScore'],
      tripleOut: map['tripleOut'],
      doubleOut: map['doubleOut'],
      doubleIn: map['doubleIn'],
      cutThroat: map['cutThroat'],
    );
  }
}

class GameSelector extends StatelessWidget {
  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;

  const GameSelector({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<GameType>(
          segments: const [
            ButtonSegment(value: GameType.x01, label: Text('X01')),
            ButtonSegment(value: GameType.cricket, label: Text('Cricket')),
          ],
          selected: {config.type},
          onSelectionChanged: (set) {
            final type = set.first;

            if (type == GameType.x01) {
              onChanged(GameConfig.x01());
            } else {
              onChanged(GameConfig.cricket());
            }
          },
        ),

        const SizedBox(height: 12),

        if (config.type == GameType.x01)
          _X01ConfigView(
            config: config,
            onChanged: onChanged,
          ),

        if (config.type == GameType.cricket)
          _CricketConfigView(
            config: config,
            onChanged: onChanged,
          ),
      ],
    );
  }
}
class MatchSelector extends StatelessWidget {
  final MatchConfig config;
  final ValueChanged<MatchConfig> onChanged;

  const MatchSelector({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MATCH STRUCTURE',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        // MODE
        const Text('Win Mode'),

        SegmentedButton<MatchMode>(
          segments: const [
            ButtonSegment(value: MatchMode.firstTo, label: Text('First To')),
            ButtonSegment(value: MatchMode.bestOf, label: Text('Best Of')),
          ],
          selected: {config.mode},
          onSelectionChanged: (set) {
            onChanged(config.copyWith(mode: set.first));
          },
        ),

        const SizedBox(height: 16),

        // SET
        const Text('Sets (match level)'),

        DropdownButton<int>(
          value: config.setCount,
          items: List.generate(10, (i) {
            final v = i + 1;
            return DropdownMenuItem(value: v, child: Text('$v'));
          }),
          onChanged: (v) {
            if (v == null) return;
            onChanged(config.copyWith(setCount: v));
          },
        ),

        const SizedBox(height: 16),

        // LEG
        const Text('Legs per set'),

        DropdownButton<int>(
          value: config.legCount,
          items: List.generate(10, (i) {
            final v = i + 1;
            return DropdownMenuItem(value: v, child: Text('$v'));
          }),
          onChanged: (v) {
            if (v == null) return;
            onChanged(config.copyWith(legCount: v));
          },
        ),
      ],
    );
  }
}
class _X01ConfigView extends StatelessWidget {
  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;

  const _X01ConfigView({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<int>(
          value: config.startingScore ?? 501,
          items: const [
            DropdownMenuItem(value: 101, child: Text('101')),
            DropdownMenuItem(value: 301, child: Text('301')),
            DropdownMenuItem(value: 501, child: Text('501')),
            DropdownMenuItem(value: 701, child: Text('701')),
            DropdownMenuItem(value: 1001, child: Text('1001')),
          ],
          onChanged: (v) {
            if (v == null) return;
            onChanged(config.copyWith(startingScore: v));
          },
        ),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'single', label: Text('Single Out')),
            ButtonSegment(value: 'double', label: Text('Double Out')),
            ButtonSegment(value: 'triple', label: Text('Triple Out')),
          ],
          selected: {
            config.tripleOut == true
                ? 'triple'
                : config.doubleOut == true
                ? 'double'
                : 'single'
          },
          onSelectionChanged: (set) {
            final value = set.first;

            if (value == 'single') {
              onChanged(config.copyWith(doubleOut: false, tripleOut: false));
            } else if (value == 'double') {
              onChanged(config.copyWith(doubleOut: true, tripleOut: false));
            } else {
              onChanged(config.copyWith(doubleOut: false, tripleOut: true));
            }
          },
        ),

        SwitchListTile(
          title: const Text('Double In'),
          value: config.doubleIn ?? false,
          onChanged: (v) {
            onChanged(config.copyWith(doubleIn: v));
          },
        ),
      ],
    );
  }
}

class _CricketConfigView extends StatelessWidget {
  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;

  const _CricketConfigView({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Cut Throat'),
      value: config.cutThroat ?? false,
      onChanged: (v) {
        onChanged(config.copyWith(cutThroat: v));
      },
    );
  }
}

class MatchConfig {
  final MatchMode mode;

  final int setCount; // quanti set
  final int legCount; // quanti leg per set

  const MatchConfig({
    required this.mode,
    this.setCount = 1,
    this.legCount = 5,
  });

  int get setsToWin {
    if (mode == MatchMode.firstTo) return setCount;
    return (setCount ~/ 2) + 1;
  }

  int get legsToWin {
    if (mode == MatchMode.firstTo) return legCount;
    return (legCount ~/ 2) + 1;
  }

  MatchConfig copyWith({
    MatchMode? mode,
    int? setCount,
    int? legCount,
  }) {
    return MatchConfig(
      mode: mode ?? this.mode,
      setCount: setCount ?? this.setCount,
      legCount: legCount ?? this.legCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    'setCount': setCount,
    'legCount': legCount,
  };

  factory MatchConfig.fromMap(Map<String, dynamic> map) {
    return MatchConfig(
      mode: MatchMode.values.byName(map['mode']),
      setCount: map['setCount'] ?? 1,
      legCount: map['legCount'] ?? 5,
    );
  }
}


class SetConfig {
  final MatchMode mode;
  final int legs;

  const SetConfig({
    required this.mode,
    required this.legs,
  });
  SetConfig copyWith({
    MatchMode? mode,
    int? legs,
  }) {
    return SetConfig(
      mode: mode ?? this.mode,
      legs: legs ?? this.legs,
    );
  }
  int get winTarget {
    if (mode == MatchMode.firstTo) return legs;
    return (legs ~/ 2) + 1;
  }

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    'legs': legs,
  };

  factory SetConfig.fromMap(Map<String, dynamic> map) {
    return SetConfig(
      mode: MatchMode.values.byName(map['mode']),
      legs: map['legs'],
    );
  }
}