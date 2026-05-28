// TARGET: Colonna configurazioni per la lobby
// UI: Compatta, centrata, moderna, con icone essenziali

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';
import '../../domain/models/game_config.dart';

class ConfigColumn extends ConsumerWidget {
  final WidgetRef ref;

  const ConfigColumn({required this.ref, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomNotifierProvider);

    return Column(
      children: [
        _ConfigSection(
          title: 'MATCH',
          icon: Icons.emoji_events_outlined,
          child: _MatchConfigCard(
            matchConfig: state.matchConfig,
            onUpdate: (c) =>
                ref.read(roomNotifierProvider.notifier).updateMatchConfig(c),
          ),
        ),
        const SizedBox(height: 60),
        _ConfigSection(
          title: 'GAME',
          icon: Icons.sports_esports_outlined,
          child: _GameConfigCard(
            gameConfig: state.gameConfig,
            onUpdate: (c) =>
                ref.read(roomNotifierProvider.notifier).updateGameConfig(c),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// SEZIONE CON INTESTAZIONE (SENZA CARD ESTERNA)
/// ─────────────────────────────────────────────

class _ConfigSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ConfigSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: t.accent),
            const SizedBox(width: 8),
            Text(title, style: tt.labelSmall?.copyWith(color: t.accent)),
          ],
        ),
        const SizedBox(height: 12),
        child, // ← SENZA card esterna, solo il contenuto
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// CAROSELLO MODERNO CON CONTORNO
/// <  valore  > con frecce grandi e touch friendly
/// ─────────────────────────────────────────────

class _Carousel<T> extends StatelessWidget {
  final List<T> options;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final double width;

  const _Carousel({
    required this.options,
    required this.value,
    required this.label,
    required this.onChanged,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;
    final currentIndex = options.indexOf(value);
    final canGoLeft = currentIndex > 0;
    final canGoRight = currentIndex < options.length - 1;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r12,
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CarouselButton(
            onTap: canGoLeft ? () => onChanged(options[currentIndex - 1]) : null,
            icon: Icons.chevron_left,
            isActive: canGoLeft,
          ),
          Expanded(
            child: Text(
              label(value),
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: t.textPrimary),
            ),
          ),
          _CarouselButton(
            onTap: canGoRight ? () => onChanged(options[currentIndex + 1]) : null,
            icon: Icons.chevron_right,
            isActive: canGoRight,
          ),
        ],
      ),
    );
  }
}

class _CarouselButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isActive;

  const _CarouselButton({
    required this.onTap,
    required this.icon,
    required this.isActive,
  });

  @override
  State<_CarouselButton> createState() => _CarouselButtonState();
}

class _CarouselButtonState extends State<_CarouselButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: widget.isActive ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.isActive ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.isActive ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed && widget.isActive
              ? t.accent.withOpacity(0.2)
              : Colors.transparent,
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: widget.isActive ? 1.0 : 0.25,
            child: AnimatedScale(
              scale: _isPressed && widget.isActive ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isActive ? t.accent : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// TOGGLE MODERNO (checkbox elegante)
/// Icona check + label
/// ─────────────────────────────────────────────

class _ModernToggle extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ModernToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ModernToggle> createState() => _ModernToggleState();
}

class _ModernToggleState extends State<_ModernToggle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => widget.onChanged(!widget.value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.value ? t.accent : Colors.transparent,
                    border: Border.all(
                      color: widget.value ? t.accent : t.border,
                      width: 1.5,
                    ),
                  ),
                  child: widget.value
                      ? Icon(Icons.check, size: 16, color: t.accentFg)
                      : null,
                ),
              ),
            ),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: tt.titleSmall?.copyWith(
                  color: widget.value ? t.accent : t.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// LABEL ROW (label + child, usata ovunque)
/// ─────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelSmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// RIGA CON DUE CAROSELLI AFFIANCATI (per int)
/// ─────────────────────────────────────────────

class _DoubleCarouselInt extends StatelessWidget {
  final String label1;
  final List<int> options1;
  final int value1;
  final String Function(int) label1Builder;
  final ValueChanged<int> onChanged1;

  final String label2;
  final List<int> options2;
  final int value2;
  final String Function(int) label2Builder;
  final ValueChanged<int> onChanged2;

  const _DoubleCarouselInt({
    required this.label1,
    required this.options1,
    required this.value1,
    required this.label1Builder,
    required this.onChanged1,
    required this.label2,
    required this.options2,
    required this.value2,
    required this.label2Builder,
    required this.onChanged2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LabeledField(
            label: label1,
            child: _Carousel<int>(
              options: options1,
              value: value1,
              label: label1Builder,
              onChanged: onChanged1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LabeledField(
            label: label2,
            child: _Carousel<int>(
              options: options2,
              value: value2,
              label: label2Builder,
              onChanged: onChanged2,
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// RIGA CON DUE CAROSELLI AFFIANCATI (generica per X01)
/// ─────────────────────────────────────────────

class _DoubleCarouselX01 extends StatelessWidget {
  final String label1;
  final List<GameType> options1;
  final GameType value1;
  final String Function(GameType) label1Builder;
  final ValueChanged<GameType> onChanged1;

  final String label2;
  final List<int> options2;
  final int value2;
  final String Function(int) label2Builder;
  final ValueChanged<int> onChanged2;

  const _DoubleCarouselX01({
    required this.label1,
    required this.options1,
    required this.value1,
    required this.label1Builder,
    required this.onChanged1,
    required this.label2,
    required this.options2,
    required this.value2,
    required this.label2Builder,
    required this.onChanged2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LabeledField(
            label: label1,
            child: _Carousel<GameType>(
              options: options1,
              value: value1,
              label: label1Builder,
              onChanged: onChanged1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LabeledField(
            label: label2,
            child: _Carousel<int>(
              options: options2,
              value: value2,
              label: label2Builder,
              onChanged: onChanged2,
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// RIGA CON CAROSELLO + TOGGLE AFFIANCATI (OUT + Double In)
/// ─────────────────────────────────────────────

class _DoubleCarouselOut extends StatelessWidget {
  final String label1;
  final List<String> options1;
  final String value1;
  final String Function(String) label1Builder;
  final ValueChanged<String> onChanged1;

  final String label2;
  final bool value2;
  final ValueChanged<bool> onChanged2;

  const _DoubleCarouselOut({
    required this.label1,
    required this.options1,
    required this.value1,
    required this.label1Builder,
    required this.onChanged1,
    required this.label2,
    required this.value2,
    required this.onChanged2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LabeledField(
            label: label1,
            child: _Carousel<String>(
              options: options1,
              value: value1,
              label: label1Builder,
              onChanged: onChanged1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LabeledField(
            label: label2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ModernToggle(
                label: '',
                value: value2,
                onChanged: onChanged2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// MATCH CONFIG
/// ─────────────────────────────────────────────

class _MatchConfigCard extends StatefulWidget {
  final MatchConfig matchConfig;
  final Function(MatchConfig) onUpdate;

  const _MatchConfigCard({
    required this.matchConfig,
    required this.onUpdate,
  });

  @override
  State<_MatchConfigCard> createState() => _MatchConfigCardState();
}

class _MatchConfigCardState extends State<_MatchConfigCard> {
  late MatchMode _mode;
  late int _setCount;
  late int _legCount;

  static const _setOptions = [1, 2, 3, 4, 5];
  static const _legOptions = [1, 2, 3, 4, 5, 6, 7];
  static const _modeOptions = [MatchMode.firstTo, MatchMode.bestOf];

  @override
  void initState() {
    super.initState();
    _mode = widget.matchConfig.mode;
    _setCount = widget.matchConfig.setCount;
    _legCount = widget.matchConfig.legCount;
  }

  void _emit() => widget.onUpdate(
    widget.matchConfig.copyWith(
      mode: _mode,
      setCount: _setCount,
      legCount: _legCount,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LabeledField(
          label: 'MODE',
          child: _Carousel<MatchMode>(
            options: _modeOptions,
            value: _mode,
            label: (v) => v == MatchMode.firstTo ? 'First To' : 'Best Of',
            onChanged: (v) {
              setState(() => _mode = v);
              _emit();
            },
          ),
        ),
        const SizedBox(height: 16),
        _DoubleCarouselInt(
          label1: 'SET',
          options1: _setOptions,
          value1: _setCount,
          label1Builder: (v) => '$v',
          onChanged1: (v) {
            setState(() => _setCount = v);
            _emit();
          },
          label2: 'LEG',
          options2: _legOptions,
          value2: _legCount,
          label2Builder: (v) => '$v',
          onChanged2: (v) {
            setState(() => _legCount = v);
            _emit();
          },
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// GAME CONFIG
/// ─────────────────────────────────────────────

class _GameConfigCard extends StatefulWidget {
  final GameConfig gameConfig;
  final Function(GameConfig) onUpdate;

  const _GameConfigCard({
    required this.gameConfig,
    required this.onUpdate,
  });

  @override
  State<_GameConfigCard> createState() => _GameConfigCardState();
}

class _GameConfigCardState extends State<_GameConfigCard> {
  late GameType _type;
  late int _startingScore;
  late String _outMode;
  late bool _doubleIn;
  late bool _cutThroat;

  static const _scoreOptions = [101, 301, 501, 701, 1001];
  static const _typeOptions = [GameType.x01, GameType.cricket];
  static const _outModeOptions = ['Single Out', 'Master Out', 'Double Out'];

  @override
  void initState() {
    super.initState();
    _syncFromGameConfig(widget.gameConfig);
  }

  @override
  void didUpdateWidget(covariant _GameConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.gameConfig != widget.gameConfig) {
      _syncFromGameConfig(widget.gameConfig);
    }
  }

  void _syncFromGameConfig(GameConfig config) {
    _type = config.type;

    final incomingScore = config.startingScore;
    if (incomingScore != null && _scoreOptions.contains(incomingScore)) {
      _startingScore = incomingScore;
    } else if (!_scoreOptions.contains(_startingScore)) {
      _startingScore = 501;
    }

    // Mappa le configurazioni ai nuovi testi UI
    if (config.tripleOut == true) {
      _outMode = 'Master Out';  // Triple Out → Master Out
    } else if (config.doubleOut == true) {
      _outMode = 'Double Out';
    } else {
      _outMode = 'Single Out';
    }

    _doubleIn = config.doubleIn ?? false;
    _cutThroat = config.cutThroat ?? false;
  }

  void _emitX01() => widget.onUpdate(
    GameConfig.x01(
      startingScore: _startingScore,
      doubleOut: _outMode == 'Double Out',      // ← modificato
      tripleOut: _outMode == 'Master Out',      // ← modificato
      doubleIn: _doubleIn,
    ),
  );

  void _emitCricket() => widget.onUpdate(
    GameConfig.cricket(cutThroat: _cutThroat),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // X01: TYPE e SCORE affiancati
        if (_type == GameType.x01)
          _DoubleCarouselX01(
            label1: 'TYPE',
            options1: _typeOptions,
            value1: _type,
            label1Builder: (v) => v == GameType.x01 ? 'X01' : 'Cricket',
            onChanged1: (v) {
              setState(() {
                _type = v;
                if (_type == GameType.x01) {
                  _emitX01();
                } else {
                  _emitCricket();
                }
              });
            },
            label2: 'SCORE',
            options2: _scoreOptions,
            value2: _startingScore,
            label2Builder: (v) => '$v',
            onChanged2: (v) {
              setState(() => _startingScore = v);
              _emitX01();
            },
          ),

        // Cricket: TYPE e CUT THROAT affiancati
        if (_type == GameType.cricket)
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'TYPE',
                  child: _Carousel<GameType>(
                    options: _typeOptions,
                    value: _type,
                    label: (v) => v == GameType.x01 ? 'X01' : 'Cricket',
                    onChanged: (v) {
                      setState(() {
                        _type = v;


                        if (_type == GameType.x01) {
                          if (!_scoreOptions.contains(_startingScore)) {
                            _startingScore = 501;
                          }
                          _emitX01();
                        } else {
                          _emitCricket();
                        }

                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'CUT THROAT',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _ModernToggle(
                      label: '',
                      value: _cutThroat,
                      onChanged: (v) {
                        setState(() => _cutThroat = v);
                        _emitCricket();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // X01: OUT (CAROUSEL) e Double In (TOGGLE) affiancati
        if (_type == GameType.x01)
          _DoubleCarouselOut(
            label1: 'CHECKOUT',
            options1: _outModeOptions,
            value1: _outMode,
            label1Builder: (v) => v,
            onChanged1: (v) {
              setState(() => _outMode = v);
              _emitX01();
            },
            label2: 'DOUBLE IN',
            value2: _doubleIn,
            onChanged2: (v) {
              setState(() => _doubleIn = v);
              _emitX01();
            },
          ),
      ],
    );
  }
}
