import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_theme.dart';
import '../../application/room_notifier.dart';

class DartKeyboard extends ConsumerStatefulWidget {
  const DartKeyboard({super.key});

  @override
  ConsumerState<DartKeyboard> createState() => _DartKeyboardState();
}

class _DartKeyboardState extends ConsumerState<DartKeyboard> {
  int _multiplier = 1;

  void _setMultiplier(int m) {
    setState(() => _multiplier = (_multiplier == m) ? 1 : m);
  }

  void _throw(int sector, int multiplier) {
    ref.read(roomNotifierProvider.notifier).throwDart(sector, multiplier);
    setState(() => _multiplier = 1);
  }

  void _miss() {
    ref.read(roomNotifierProvider.notifier).throwDart(0, 0);
    setState(() => _multiplier = 1);
  }

  void _undo() {
    ref.read(roomNotifierProvider.notifier).undoLastThrow();
    setState(() => _multiplier = 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = min(screenWidth * 0.8, 340.0);

    return Container(
      color: t.bg,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
      child: Center(
        child: _Board(
          size: boardSize,
          multiplier: _multiplier,
          onSetMultiplier: _setMultiplier,
          onThrow: _throw,
          onUndo: _undo,
          onMiss: _miss,
          t: t,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOARD
// ─────────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  final double size;
  final int multiplier;
  final void Function(int) onSetMultiplier;
  final void Function(int sector, int multiplier) onThrow;
  final VoidCallback onUndo;
  final VoidCallback onMiss;
  final AppTokens t;

  const _Board({
    required this.size,
    required this.multiplier,
    required this.onSetMultiplier,
    required this.onThrow,
    required this.onUndo,
    required this.onMiss,
    required this.t,
  });

  static const _geometry = _BoardGeometry();

  // SOSTITUISCI completamente il metodo build di _Board

  @override
  Widget build(BuildContext context) {
    // DIMENSIONI FISSE - sempre uguali
    const double btnWidth = 70.0;
    const double btnHeight = 44.0;
    const double horizontalMargin = 16.0;
    const double topMargin = 8.0;
    const double bottomMargin = 8.0;

    return Stack(
      children: [
        // Board centrata
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localPosition = box.globalToLocal(
                details.globalPosition,
              );
              final Size boardSize = Size.square(size);
              final Offset boardTopLeft = Offset(
                (box.size.width - size) / 2,
                (box.size.height - size) / 2,
              );
              final Offset relativeToBoard = localPosition - boardTopLeft;

              final hit = _BoardHitTester.hitTest(
                localPosition: relativeToBoard,
                size: size,
                geometry: _geometry,
              );
              if (hit == null) return;
              onThrow(hit.sector, hit.multiplier ?? multiplier);
            },
            child: CustomPaint(
              size: Size.square(size),
              painter: const _BoardPainter(geometry: _geometry),
            ),
          ),
        ),
        // Bottone D - alto sinistra
        Positioned(
          top: topMargin,
          left: horizontalMargin,
          child: _CornerBtn(
            label: 'D',
            isActive: multiplier == 2,
            onTap: () => onSetMultiplier(2),
            t: t,
            width: btnWidth,
            height: btnHeight,
          ),
        ),
        // Bottone T - alto destra
        Positioned(
          top: topMargin,
          right: horizontalMargin,
          child: _CornerBtn(
            label: 'T',
            isActive: multiplier == 3,
            onTap: () => onSetMultiplier(3),
            t: t,
            width: btnWidth,
            height: btnHeight,
          ),
        ),
        // Bottone UNDO - basso sinistra
        Positioned(
          bottom: bottomMargin,
          left: horizontalMargin,
          child: _CornerBtn(
            label: 'ANNULLA',
            onTap: onUndo,
            icon: Icons.undo,
            t: t,
            width: btnWidth,
            height: btnHeight,
          ),
        ),
        // Bottone MISS - basso destra
        Positioned(
          bottom: bottomMargin,
          right: horizontalMargin,
          child: _CornerBtn(
            label: '0',
            onTap: onMiss,
            t: t,
            width: btnWidth,
            height: btnHeight,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GEOMETRY
// ─────────────────────────────────────────────────────────────

class _BoardGeometry {
  final double doubleBullRadius;
  final double gapAfterDoubleBull;
  final double singleBullThickness;
  final double gapAfterSingleBull;
  final double innerSectorThickness;
  final double gapBetweenSectorRings;
  final double outerSectorThickness;

  /// Separatore visivo a spessore costante.
  /// Non taglia gli spicchi con un gap angolare.
  final double separatorWidth;

  /// Contorno nero finale esterno.
  final double outerBorderWidth;

  /// Angolo verticale alto. Il 20 viene centrato qui.
  final double topAngleRadians;

  const _BoardGeometry({
    this.doubleBullRadius = 30,
    this.gapAfterDoubleBull = 6,
    this.singleBullThickness = 26,
    this.gapAfterSingleBull = 10,
    this.innerSectorThickness = 52,
    this.gapBetweenSectorRings = 12,
    this.outerSectorThickness = 52,
    this.separatorWidth = 4,
    this.outerBorderWidth = 7,
    this.topAngleRadians = -pi / 2,
  });

  double get sectorSweep => (pi * 2) / 10;

  /// L’anello esterno parte mezzo settore prima del verticale:
  /// così il 20 è centrato esattamente in alto.
  double get outerRingStartAngle => topAngleRadians - sectorSweep / 2;

  /// L’anello interno parte un altro mezzo settore prima:
  /// così sotto al 20 c’è il taglio tra 5 e 1.
  double get innerRingStartAngle => topAngleRadians - sectorSweep;

  double get singleBullInnerRadius => doubleBullRadius + gapAfterDoubleBull;

  double get singleBullOuterRadius =>
      singleBullInnerRadius + singleBullThickness;

  double get innerSectorInnerRadius =>
      singleBullOuterRadius + gapAfterSingleBull;

  double get innerSectorOuterRadius =>
      innerSectorInnerRadius + innerSectorThickness;

  double get outerSectorInnerRadius =>
      innerSectorOuterRadius + gapBetweenSectorRings;

  double get outerSectorOuterRadius =>
      outerSectorInnerRadius + outerSectorThickness;

  double get boardRadius => outerSectorOuterRadius;
}

// ─────────────────────────────────────────────────────────────
// HIT TEST
// ─────────────────────────────────────────────────────────────

class _BoardHit {
  final int sector;
  final int? multiplier;

  const _BoardHit({required this.sector, this.multiplier});
}

class _BoardHitTester {
  static const List<int> innerNumbers = [5, 1, 4, 6, 15, 17, 19, 16, 11, 9];

  static const List<int> outerNumbers = [20, 18, 13, 10, 2, 3, 7, 8, 14, 12];

  static _BoardHit? hitTest({
    required Offset localPosition,
    required double size,
    required _BoardGeometry geometry,
  }) {
    final scale = size / (geometry.boardRadius * 2);
    final center = Offset(size / 2, size / 2);
    final point = (localPosition - center) / scale;
    final distance = point.distance;

    if (distance <= geometry.doubleBullRadius) {
      return const _BoardHit(sector: 25, multiplier: 2);
    }

    if (distance >= geometry.singleBullInnerRadius &&
        distance <= geometry.singleBullOuterRadius) {
      return const _BoardHit(sector: 25, multiplier: 1);
    }

    if (distance >= geometry.innerSectorInnerRadius &&
        distance <= geometry.innerSectorOuterRadius) {
      final sector = _sectorFromAngle(
        point: point,
        rotation: geometry.innerRingStartAngle,
        numbers: innerNumbers,
      );

      return _BoardHit(sector: sector);
    }

    if (distance >= geometry.outerSectorInnerRadius &&
        distance <= geometry.outerSectorOuterRadius) {
      final sector = _sectorFromAngle(
        point: point,
        rotation: geometry.outerRingStartAngle,
        numbers: outerNumbers,
      );

      return _BoardHit(sector: sector);
    }

    return null;
  }

  static int _sectorFromAngle({
    required Offset point,
    required double rotation,
    required List<int> numbers,
  }) {
    final sweep = (pi * 2) / numbers.length;
    final rawAngle = atan2(point.dy, point.dx);
    final normalized = _normalizeAngle(rawAngle - rotation);
    final index = (normalized / sweep).floor() % numbers.length;

    return numbers[index];
  }

  static double _normalizeAngle(double angle) {
    const full = pi * 2;
    var a = angle;

    while (a < 0) {
      a += full;
    }

    while (a >= full) {
      a -= full;
    }

    return a;
  }
}

// ─────────────────────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final _BoardGeometry geometry;

  const _BoardPainter({required this.geometry});

  static const List<int> innerNumbers = [5, 1, 4, 6, 15, 17, 19, 16, 11, 9];

  static const List<int> outerNumbers = [20, 18, 13, 10, 2, 3, 7, 8, 14, 12];

  static const Color bg = Color(0xFF101418);
  static const Color sector = Color(0xFFD8D8D8);
  static const Color black = Color(0xFF12161B);
  static const Color green = Color(0xFF12B866);
  static const Color red = Color(0xFFE53B3B);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / (geometry.boardRadius * 2);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    _drawBoardBackground(canvas);

    _drawSectorRing(
      canvas: canvas,
      innerRadius: geometry.outerSectorInnerRadius,
      outerRadius: geometry.outerSectorOuterRadius,
      numbers: outerNumbers,
      rotation: geometry.outerRingStartAngle,
    );

    _drawSectorRing(
      canvas: canvas,
      innerRadius: geometry.innerSectorInnerRadius,
      outerRadius: geometry.innerSectorOuterRadius,
      numbers: innerNumbers,
      rotation: geometry.innerRingStartAngle,
    );

    _drawBull(canvas);
    _drawOuterBorder(canvas);

    canvas.restore();
  }

  void _drawBoardBackground(Canvas canvas) {
    final paint = Paint()
      ..color = black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, geometry.boardRadius, paint);
  }

  void _drawBull(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = green;
    canvas.drawCircle(Offset.zero, geometry.singleBullOuterRadius, paint);

    paint.color = black;
    canvas.drawCircle(Offset.zero, geometry.singleBullInnerRadius, paint);

    paint.color = red;
    canvas.drawCircle(Offset.zero, geometry.doubleBullRadius, paint);

    _drawCenteredText(
      canvas: canvas,
      text: 'DB',
      radius: 0,
      color: Colors.white,
    );
  }

  void _drawOuterBorder(Canvas canvas) {
    final paint = Paint()
      ..color = black
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.outerBorderWidth;

    canvas.drawCircle(
      Offset.zero,
      geometry.boardRadius - geometry.outerBorderWidth / 2,
      paint,
    );
  }

  void _drawSectorRing({
    required Canvas canvas,
    required double innerRadius,
    required double outerRadius,
    required List<int> numbers,
    required double rotation,
  }) {
    final sweep = (pi * 2) / numbers.length;

    final paint = Paint()
      ..color = sector
      ..style = PaintingStyle.fill;

    for (int i = 0; i < numbers.length; i++) {
      final start = rotation + i * sweep;
      final end = rotation + (i + 1) * sweep;

      final path = _ringSectorPath(
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        startAngle: start,
        endAngle: end,
      );

      canvas.drawPath(path, paint);

      final mid = (start + end) / 2;
      final textRadius = (innerRadius + outerRadius) / 2;

      _drawCenteredText(
        canvas: canvas,
        text: numbers[i].toString(),
        radius: textRadius,
        angle: mid,
        color: Colors.black,
      );
    }

    _drawRadialSeparators(
      canvas: canvas,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      count: numbers.length,
      rotation: rotation,
    );
  }

  void _drawRadialSeparators({
    required Canvas canvas,
    required double innerRadius,
    required double outerRadius,
    required int count,
    required double rotation,
  }) {
    final sweep = (pi * 2) / count;

    final paint = Paint()
      ..color = black
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.separatorWidth
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < count; i++) {
      final angle = rotation + i * sweep;

      final p1 = Offset(cos(angle) * innerRadius, sin(angle) * innerRadius);

      final p2 = Offset(cos(angle) * outerRadius, sin(angle) * outerRadius);

      canvas.drawLine(p1, p2, paint);
    }
  }

  Path _ringSectorPath({
    required double innerRadius,
    required double outerRadius,
    required double startAngle,
    required double endAngle,
  }) {
    final outerStart = Offset(
      cos(startAngle) * outerRadius,
      sin(startAngle) * outerRadius,
    );

    final innerEnd = Offset(
      cos(endAngle) * innerRadius,
      sin(endAngle) * innerRadius,
    );

    return Path()
      ..moveTo(outerStart.dx, outerStart.dy)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: outerRadius),
        startAngle,
        endAngle - startAngle,
        false,
      )
      ..lineTo(innerEnd.dx, innerEnd.dy)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: innerRadius),
        endAngle,
        -(endAngle - startAngle),
        false,
      )
      ..close();
  }

  void _drawCenteredText({
    required Canvas canvas,
    required String text,
    required double radius,
    double angle = 0,
    required Color color,
  }) {
    final offset = Offset(cos(angle) * radius, sin(angle) * radius);
    final labelStyle = AppTokens.scoreSmallStyle.copyWith(color: color);

    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textScaler: TextScaler.linear(
        24 / (AppTokens.scoreSmallStyle.fontSize ?? 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      offset - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.geometry != geometry;
  }
}

// ─────────────────────────────────────────────────────────────
// CORNER BUTTON
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// CORNER BUTTONS - Modern & Clean
// ─────────────────────────────────────────────────────────────

class _CornerBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  final AppTokens t;
  final double width;
  final double height;

  const _CornerBtn({
    this.label = '',
    this.icon,
    required this.onTap,
    required this.t,
    required this.width,
    required this.height,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? t.accent : t.border, width: 1),
        ),
        child: icon != null
            ? Icon(
                icon,
                color: isActive ? t.accentFg : t.textSecondary,
                size: (tt.titleSmall?.fontSize ?? 13) * 1.4,
              )
            : Text(
                label,
                style: tt.titleSmall?.copyWith(
                  color: isActive ? t.accentFg : t.textSecondary,
                ),
              ),
      ),
    );
  }
}
