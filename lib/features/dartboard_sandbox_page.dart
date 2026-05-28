import 'package:flutter/material.dart';
import '../app_theme.dart';

class DartboardSandboxPage extends StatefulWidget {
  const DartboardSandboxPage({super.key});

  @override
  State<DartboardSandboxPage> createState() => _DartboardSandboxPageState();
}

class _DartboardSandboxPageState extends State<DartboardSandboxPage> {
  double _splitFraction = 0.5;
  double _topFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dartboard Sandbox')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final totalHeight = constraints.maxHeight;
          final leftWidth = totalWidth * _splitFraction;
          final topHeight = totalHeight * _topFraction;

          return Row(
            children: [
              // ── Colonna sinistra (1 + 3) ──────────────────
              SizedBox(
                width: leftWidth,
                child: Column(
                  children: [
                    // Zona 1
// Zona 1
                    SizedBox(
                      height: topHeight,
                      child: Container(
                        color: t.surface,
                        child: const RedCircle(), // ← qui
                      ),
                    ),

                    // Divisore orizzontale
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) {
                        setState(() {
                          _topFraction =
                              (_topFraction + d.delta.dy / totalHeight).clamp(0.2, 0.8);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeRow,
                        child: Container(
                          height: 8,
                          color: t.divider,
                          child: Center(
                            child: Container(height: 2, color: t.border),
                          ),
                        ),
                      ),
                    ),

                    // Zona 3
                    Expanded(
                      child: Container(
                        color: t.surfaceHigh,
                        child: Center(
                          child: Text(
                            '3',
                            style: AppTokens.scoreStyle.copyWith(color: t.orange),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divisore verticale ────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _splitFraction =
                        (_splitFraction + d.delta.dx / totalWidth).clamp(0.2, 0.8);
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 8,
                    color: t.divider,
                    child: Center(
                      child: Container(width: 2, color: t.border),
                    ),
                  ),
                ),
              ),

              // ── Zona 2 ────────────────────────────────────
              Expanded(
                child: Container(
                  color: t.overlay,
                  child: Center(
                    child: Text(
                      '2',
                      style: AppTokens.scoreStyle.copyWith(color: t.accent),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class RedCircle extends StatelessWidget {
  const RedCircle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = [constraints.maxWidth, constraints.maxHeight].reduce((a, b) => a < b ? a : b);
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 10,
          child: Container(
            color: Colors.cyan,
            child: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}