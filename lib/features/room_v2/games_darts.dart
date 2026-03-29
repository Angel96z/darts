import 'package:flutter/material.dart';

enum GameType {
  x01,
  cricket,
}

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