// TARGET: Selettore team per la lobby
// LOGIC GOAL: Permettere selezione modalità team (2v2, 3v3, 4v4)
// UI: Stile moderno compatibile con ConfigColumn, su un'unica riga

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';

class TeamSelector extends ConsumerWidget {
  final WidgetRef ref;

  const TeamSelector({required this.ref, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomNotifierProvider);
    final t = AppTokens.of(context);
    final teamSize = state.teamSize;
    final invalid = !state.canStartMatch && teamSize > 0;

    // I valori UI sono 1v1, 2v2, 3v3, 4v4
    // Ma mappano ai valori backend: 0 -> 1v1, 2 -> 2v2, 3 -> 3v3, 4 -> 4v4
    final uiOptions = const [0, 2, 3, 4];
    final uiLabels = const ['1v1', '2v2', '3v3', '4v4'];

    final currentIndex = uiOptions.indexOf(teamSize);
    final canGoLeft = currentIndex > 0;
    final canGoRight = currentIndex < uiOptions.length - 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (invalid) ...[
          const SizedBox(width: 8),
          Icon(Icons.warning_amber_rounded, size: 16, color: t.red),
        ],
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: AppTokens.r16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CarouselButton(
                onTap: canGoLeft
                    ? () => ref
                    .read(roomNotifierProvider.notifier)
                    .updateTeamSize(uiOptions[currentIndex - 1])
                    : null,
                icon: Icons.chevron_left,
                isActive: canGoLeft,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  uiLabels[currentIndex],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              _CarouselButton(
                onTap: canGoRight
                    ? () => ref
                    .read(roomNotifierProvider.notifier)
                    .updateTeamSize(uiOptions[currentIndex + 1])
                    : null,
                icon: Icons.chevron_right,
                isActive: canGoRight,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottone del carousel (stile unificato con ConfigColumn)
class _CarouselButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isActive;

  const _CarouselButton({
    required this.onTap,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isActive ? 1.0 : 0.25,
          child: Icon(
            icon,
            size: 20,
            color: isActive ? t.accent : t.textMuted,
          ),
        ),
      ),
    );
  }
}