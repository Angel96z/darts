// lib/features/room_v4/presentation/widgets/cricket_keyboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';

class CricketKeyboard extends ConsumerStatefulWidget {
  const CricketKeyboard({super.key});

  @override
  ConsumerState<CricketKeyboard> createState() => _CricketKeyboardState();
}

enum _CricketButtonEmphasis { soft, medium, strong }

class _CricketKeyboardState extends ConsumerState<CricketKeyboard> {
  static const List<int> sectors = [20, 19, 18, 17, 16, 15, 25];

  void _throw(int sector, int multiplier) {
    ref.read(roomNotifierProvider.notifier).throwDart(sector, multiplier);
  }

  void _miss() {
    ref.read(roomNotifierProvider.notifier).throwDart(0, 0);
  }

  void _undo() {
    ref.read(roomNotifierProvider.notifier).undoLastThrow();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          top: BorderSide(color: t.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final sector in sectors) ...[
                  Expanded(child: _buildSectorColumn(sector: sector, t: t)),
                  if (sector != sectors.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    label: 'MISS',
                    onTap: _miss,
                    color: t.red,
                    t: t,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildControlButton(
                    label: 'UNDO',
                    onTap: _undo,
                    color: t.orange,
                    t: t,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorColumn({
    required int sector,
    required AppTokens t,
  }) {
    final tt = Theme.of(context).textTheme;
    final isBull = sector == 25;

    return Column(
      children: [
        SizedBox(
          height: 26,
          child: Center(
            child: Text(
              isBull ? 'BULL' : sector.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelLarge?.copyWith(
                color: isBull ? t.green : t.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: isBull ? -0.5 : 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildButton(
          label: 'S',
          onTap: () => _throw(sector, 1),
          t: t,
          emphasis: _CricketButtonEmphasis.soft,
        ),
        const SizedBox(height: 6),
        _buildButton(
          label: 'D',
          onTap: () => _throw(sector, 2),
          t: t,
          emphasis: _CricketButtonEmphasis.medium,
        ),
        if (!isBull) ...[
          const SizedBox(height: 6),
          _buildButton(
            label: 'T',
            onTap: () => _throw(sector, 3),
            t: t,
            emphasis: _CricketButtonEmphasis.strong,
          ),
        ] else ...[
          const SizedBox(height: 6),
          const SizedBox(height: 42),
        ],
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    required AppTokens t,
    required _CricketButtonEmphasis emphasis,
  }) {
    final tt = Theme.of(context).textTheme;

    final Color bg = switch (emphasis) {
      _CricketButtonEmphasis.soft => t.surfaceHigh,
      _CricketButtonEmphasis.medium => t.accent.withOpacity(0.10),
      _CricketButtonEmphasis.strong => t.accent.withOpacity(0.18),
    };

    final Color border = switch (emphasis) {
      _CricketButtonEmphasis.soft => t.border,
      _CricketButtonEmphasis.medium => t.accent.withOpacity(0.30),
      _CricketButtonEmphasis.strong => t.accent.withOpacity(0.52),
    };

    final Color fg = switch (emphasis) {
      _CricketButtonEmphasis.soft => t.textSecondary,
      _CricketButtonEmphasis.medium => t.textPrimary,
      _CricketButtonEmphasis.strong => t.accent,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.r8,
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTokens.r8,
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              label,
              style: tt.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
    required AppTokens t,
  }) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTokens.r12,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: AppTokens.r12,
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Center(
            child: Text(
              label,
              style: tt.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
