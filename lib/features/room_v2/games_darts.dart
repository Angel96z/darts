import 'package:flutter/material.dart';

enum GameType { x01, cricket }
enum MatchMode { firstTo, bestOf }

/// =======================
/// GAME CONFIG
/// =======================
class GameConfig {
  final GameType type;

  final int? startingScore;
  final bool? tripleOut;
  final bool? doubleOut;
  final bool? doubleIn;

  final bool? cutThroat;

  const GameConfig({
    required this.type,
    this.startingScore,
    this.tripleOut,
    this.doubleOut,
    this.doubleIn,
    this.cutThroat,
  });

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

  factory GameConfig.cricket({bool cutThroat = false}) {
    return GameConfig(type: GameType.cricket, cutThroat: cutThroat);
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

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'startingScore': startingScore,
    'tripleOut': tripleOut,
    'doubleOut': doubleOut,
    'doubleIn': doubleIn,
    'cutThroat': cutThroat,
  };

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

/// =======================
/// MATCH CONFIG
/// =======================
class MatchConfig {
  final MatchMode mode;
  final int setCount;
  final int legCount;

  const MatchConfig({
    required this.mode,
    this.setCount = 1,
    this.legCount = 5,
  });

  int get setsToWin =>
      mode == MatchMode.firstTo ? setCount : (setCount ~/ 2) + 1;

  int get legsToWin =>
      mode == MatchMode.firstTo ? legCount : (legCount ~/ 2) + 1;

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

/// =======================
/// GAME SELECTOR
/// =======================
class GameSelector extends StatelessWidget {
  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;
  final bool isAdmin;

  const GameSelector({
    super.key,
    required this.config,
    required this.onChanged,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return _GameSummary(config: config);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SegmentWrapper(
          child: SegmentedButton<GameType>(
            segments: const [
              ButtonSegment(value: GameType.x01, label: Text('X01')),
              ButtonSegment(value: GameType.cricket, label: Text('Cricket')),
            ],
            selected: {config.type},
            onSelectionChanged: (set) {
              final type = set.first;
              onChanged(
                type == GameType.x01
                    ? GameConfig.x01()
                    : GameConfig.cricket(),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: config.type == GameType.x01
              ? _X01ConfigView(config: config, onChanged: onChanged)
              : _CricketConfigView(config: config, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// =======================
/// MATCH SELECTOR
/// =======================
class MatchSelector extends StatelessWidget {
  final MatchConfig config;
  final ValueChanged<MatchConfig> onChanged;
  final bool isAdmin;

  const MatchSelector({
    super.key,
    required this.config,
    required this.onChanged,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return _MatchSummary(config: config);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SegmentWrapper(
          child: SegmentedButton<MatchMode>(
            segments: const [
              ButtonSegment(value: MatchMode.firstTo, label: Text('First To')),
              ButtonSegment(value: MatchMode.bestOf, label: Text('Best Of')),
            ],
            selected: {config.mode},
            onSelectionChanged: (set) {
              onChanged(config.copyWith(mode: set.first));
            },
          ),
        ),
        const SizedBox(height: 16),

        // ✅ SET + LEG INLINE (NO DUPLICATI)
        Row(
          children: [
            Expanded(
              child: _DropdownBlock(
                label: 'Sets',
                value: config.setCount,
                onChanged: (v) =>
                v != null ? onChanged(config.copyWith(setCount: v)) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DropdownBlock(
                label: 'Legs',
                value: config.legCount,
                onChanged: (v) =>
                v != null ? onChanged(config.copyWith(legCount: v)) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


/// =======================
/// X01 CONFIG
/// =======================
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ✅ SCORE INLINE (NO DUPLICATI)
        _DropdownBlock(
          label: 'Score',
          value: config.startingScore ?? 501,
          items: const [101, 301, 501, 701, 1001],
          onChanged: (v) =>
          v != null ? onChanged(config.copyWith(startingScore: v)) : null,
        ),

        const SizedBox(height: 16),

        _SegmentWrapper(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'single', label: Text('Single')),
              ButtonSegment(value: 'double', label: Text('Double')),
              ButtonSegment(value: 'triple', label: Text('Triple')),
            ],
            selected: {
              config.tripleOut == true
                  ? 'triple'
                  : config.doubleOut == true
                  ? 'double'
                  : 'single'
            },
            onSelectionChanged: (set) {
              final v = set.first;
              onChanged(config.copyWith(
                doubleOut: v == 'double',
                tripleOut: v == 'triple',
              ));
            },
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Double In',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: config.doubleIn ?? false,
              onChanged: (v) => onChanged(config.copyWith(doubleIn: v)),
            ),
          ],
        )
      ],
    );
  }
}


/// =======================
/// CRICKET CONFIG
/// =======================
class _CricketConfigView extends StatelessWidget {
  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;

  const _CricketConfigView({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            'Cut Throat',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: config.cutThroat ?? false,
          onChanged: (v) => onChanged(config.copyWith(cutThroat: v)),
        ),
      ],
    );
  }
}

/// =======================
/// UI HELPERS
/// =======================
class _SegmentWrapper extends StatelessWidget {
  final Widget child;

  const _SegmentWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}


class _DropdownBlock extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int?> onChanged;
  final List<int>? items;

  const _DropdownBlock({
    required this.label,
    required this.value,
    required this.onChanged,
    this.items,
  });

  @override
  Widget build(BuildContext context) {
    final values = items ?? List.generate(10, (i) => i + 1);
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: textStyle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              style: textStyle,
              items: values
                  .map((v) => DropdownMenuItem(
                value: v,
                child: Text('$v', style: textStyle),
              ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================
/// READ ONLY SUMMARY
/// =======================
class _GameSummary extends StatelessWidget {
  final GameConfig config;

  const _GameSummary({required this.config});

  @override
  Widget build(BuildContext context) {
    return Text(
      config.type == GameType.x01
          ? 'X01 • ${config.startingScore} • ${config.doubleOut == true ? "Double Out" : "Single"}'
          : 'Cricket • ${config.cutThroat == true ? "Cut Throat" : "Standard"}',
    );
  }
}

class _MatchSummary extends StatelessWidget {
  final MatchConfig config;

  const _MatchSummary({required this.config});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${config.mode.name} • Sets: ${config.setCount} • Legs: ${config.legCount}',
    );
  }
}