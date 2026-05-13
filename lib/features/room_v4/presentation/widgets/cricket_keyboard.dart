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
    final screenWidth = MediaQuery.of(context).size.width;
    final sectorWidth = (screenWidth - 32) / sectors.length;

    return Container(
      color: t.bg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Griglia settori (colonne verticali)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sectors.map((sector) {
              return SizedBox(
                width: sectorWidth,
                child: Column(
                  children: [
                    // Numero del settore
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          sector == 25 ? 'BULL' : sector.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Bottone SINGLE
                    _buildButton(
                      label: 'S',
                      onTap: () => _throw(sector, 1),
                      t: t,
                    ),
                    const SizedBox(height: 4),
                    // Bottone DOUBLE
                    _buildButton(
                      label: 'D',
                      onTap: () => _throw(sector, 2),
                      t: t,
                    ),
                    // Bottone TRIPLE (solo per numeri, non per BULL)
                    if (sector != 25) ...[
                      const SizedBox(height: 4),
                      _buildButton(
                        label: 'T',
                        onTap: () => _throw(sector, 3),
                        t: t,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Bottoni di controllo
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
              const SizedBox(width: 12),
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
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    required AppTokens t,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border, width: 0.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}