// TARGET: Colonna configurazioni per la lobby
// LOGIC GOAL: Mostrare e modificare configurazioni di gioco e match
// REACTION: UI reagisce ai cambiamenti delle config

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
    final t = AppTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormGroup(
          title: 'Match',
          icon: Icons.emoji_events_outlined,
          t: t,
          child: _MatchConfigCard(
            matchConfig: state.matchConfig,
            onUpdate: (c) =>
                ref.read(roomNotifierProvider.notifier).updateMatchConfig(c),
          ),
        ),

        const SizedBox(height: 18),

        _FormGroup(
          title: 'Gioco',
          icon: Icons.sports_esports_outlined,
          t: t,
          child: _GameConfigCard(
            gameConfig: state.gameConfig,
            onUpdate: (c) =>
                ref.read(roomNotifierProvider.notifier).updateGameConfig(c),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// HEADER FORM
/// ─────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppTokens t;

  const _FormHeader({
    required this.title,
    required this.subtitle,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          size: 18,
          color: t.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// FORM GROUP
/// Sezione visiva leggera: niente card pesante.
/// ─────────────────────────────────────────────

class _FormGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final AppTokens t;

  const _FormGroup({
    required this.title,
    required this.icon,
    required this.child,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: t.textSecondary),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w900,
                color: t.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// UI BASE
/// ─────────────────────────────────────────────

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final bg = selected ? t.accent.withOpacity(0.14) : t.surfaceHigh;
    final border = selected ? t.accent.withOpacity(0.75) : t.border;
    final fg = selected ? t.accent : t.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppTokens.r8,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTokens.r8,
            border: Border.all(
              color: border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleLine extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  const _ToggleLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final bg = value ? t.accent.withOpacity(0.13) : t.surfaceHigh;
    final border = value ? t.accent.withOpacity(0.75) : t.border;
    final fg = value ? t.accent : t.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppTokens.r8,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTokens.r8,
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
              Icon(
                value ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r8,
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          iconSize: 18,
          dropdownColor: t.surface,
          borderRadius: AppTokens.r10,
          style: TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w800,
            color: t.textPrimary,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                label(e),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
          color: t.textMuted,
          letterSpacing: 0.7,
        ),
      ),
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

  static const _options = [1, 2, 3, 4, 5, 6, 7];

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('DURATA'),
        Row(
          children: [
            Expanded(
              child: _CompactDropdown<int>(
                value: _setCount,
                items: _options,
                label: (v) => 'Set $v',
                onChanged: (v) {
                  setState(() => _setCount = v);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactDropdown<int>(
                value: _legCount,
                items: _options,
                label: (v) => 'Leg $v',
                onChanged: (v) {
                  setState(() => _legCount = v);
                  _emit();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        const _FieldLabel('MODALITÀ'),
        Row(
          children: [
            Expanded(
              child: _OptionChip(
                label: 'First To',
                icon: Icons.flag_outlined,
                selected: _mode == MatchMode.firstTo,
                onTap: () {
                  setState(() => _mode = MatchMode.firstTo);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OptionChip(
                label: 'Best Of',
                icon: Icons.emoji_events_outlined,
                selected: _mode == MatchMode.bestOf,
                onTap: () {
                  setState(() => _mode = MatchMode.bestOf);
                  _emit();
                },
              ),
            ),
          ],
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

  @override
  void initState() {
    super.initState();
    _type = widget.gameConfig.type;
    _startingScore = widget.gameConfig.startingScore ?? 501;
    _outMode = widget.gameConfig.tripleOut == true
        ? 'triple'
        : widget.gameConfig.doubleOut == true
        ? 'double'
        : 'single';
    _doubleIn = widget.gameConfig.doubleIn ?? false;
    _cutThroat = widget.gameConfig.cutThroat ?? false;
  }

  void _emitX01() => widget.onUpdate(
    GameConfig.x01(
      startingScore: _startingScore,
      doubleOut: _outMode == 'double',
      tripleOut: _outMode == 'triple',
      doubleIn: _doubleIn,
    ),
  );

  void _emitCricket() => widget.onUpdate(
    GameConfig.cricket(cutThroat: _cutThroat),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('TIPO GIOCO'),
        Row(
          children: [
            Expanded(
              child: _OptionChip(
                label: 'X01',
                icon: Icons.adjust_rounded,
                selected: _type == GameType.x01,
                onTap: () {
                  setState(() => _type = GameType.x01);
                  _emitX01();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OptionChip(
                label: 'Cricket',
                icon: Icons.grid_3x3_rounded,
                selected: _type == GameType.cricket,
                onTap: () {
                  setState(() => _type = GameType.cricket);
                  _emitCricket();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (_type == GameType.x01) _buildX01Config(),
        if (_type == GameType.cricket) _buildCricketConfig(),
      ],
    );
  }

  Widget _buildX01Config() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('PUNTEGGIO'),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 3;

            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _scoreOptions.map((score) {
                return SizedBox(
                  width: itemWidth,
                  child: _OptionChip(
                    label: '$score',
                    selected: _startingScore == score,
                    onTap: () {
                      setState(() => _startingScore = score);
                      _emitX01();
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 12),

        const _FieldLabel('CHIUSURA'),
        Row(
          children: [
            Expanded(
              child: _OptionChip(
                label: 'Single',
                selected: _outMode == 'single',
                onTap: () {
                  setState(() => _outMode = 'single');
                  _emitX01();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _OptionChip(
                label: 'Double',
                selected: _outMode == 'double',
                onTap: () {
                  setState(() => _outMode = 'double');
                  _emitX01();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _OptionChip(
                label: 'Triple',
                selected: _outMode == 'triple',
                onTap: () {
                  setState(() => _outMode = 'triple');
                  _emitX01();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _ToggleLine(
          label: 'Double In',
          value: _doubleIn,
          icon: Icons.lock_open_outlined,
          onChanged: (v) {
            setState(() => _doubleIn = v);
            _emitX01();
          },
        ),
      ],
    );
  }

  Widget _buildCricketConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('REGOLE'),
        _ToggleLine(
          label: 'Cut Throat',
          value: _cutThroat,
          icon: Icons.groups_2_outlined,
          onChanged: (v) {
            setState(() => _cutThroat = v);
            _emitCricket();
          },
        ),
      ],
    );
  }
}