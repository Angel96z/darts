import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/dart_models.dart';
import '../../../../core/utils/dart_rules.dart';

enum DartboardOverlayType {
  throws,
  heatmap,
  quadrants,
  targetCenter,
  bias,
  dispersion,
  targetZone,
  radialError,
  directionalBias,
}

class DartboardWidget extends StatefulWidget {
  final ValueChanged<DartHitData>? onHit;
  final double minScale;
  final double maxScale;
  final List<DartThrow> throws;
  final String? target;

  final Set<DartboardOverlayType> overlays;

  const DartboardWidget({
    super.key,
    this.onHit,
    this.minScale = 1,
    this.maxScale = 5,
    this.throws = const [],
    this.target,
    this.overlays = const {DartboardOverlayType.throws},
  });

  @override
  State<DartboardWidget> createState() => _DartboardWidgetState();
}

class _DartboardWidgetState extends State<DartboardWidget> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition;

    final hit = DartRules.calculateHit(
      dx: pos.dx - center.dx,
      dy: pos.dy - center.dy,
      boardRadius: size.width / 2,
      boardX: pos.dx,
      boardY: pos.dy,
      target: widget.target,
    );

    widget.onHit?.call(
      DartHitData(
        boardPosition: Offset(pos.dx / size.width, pos.dy / size.height),
        sector: hit.sector,
        score: hit.score,
        distanceMm: hit.distanceMm,
        targetQuadrant: hit.targetQuadrant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {

        final side = min(constraints.maxWidth, constraints.maxHeight);

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: ScrollConfiguration(
                behavior: const _NoScrollBehavior(),
                child: Listener(
              behavior: HitTestBehavior.opaque,
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
                        if (resolvedEvent is PointerScrollEvent) {

                          final scaleFactor = resolvedEvent.scrollDelta.dy > 0 ? 0.9 : 1.1;

                          final matrix = _controller.value.clone();
                          final currentScale = matrix.getMaxScaleOnAxis();

                          final newScale = (currentScale * scaleFactor)
                              .clamp(widget.minScale, widget.maxScale);

                          matrix.scale(newScale / currentScale);

                          _controller.value = matrix;
                        }
                      });
                    }
                  },
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: widget.minScale,
                maxScale: widget.maxScale,
                boundaryMargin: const EdgeInsets.all(32),

                // 👇 IMPORTANTE
                panEnabled: _controller.value.getMaxScaleOnAxis() > 1,

                onInteractionUpdate: (_) {
                  final scale = _controller.value.getMaxScaleOnAxis();

                  if (scale <= widget.minScale) {
                    _controller.value = Matrix4.identity();
                  }

                  setState(() {}); // aggiorna panEnabled
                },

                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _handleTap(d, Size(side, side)),
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _DartboardPainter(
                      throws: widget.throws,
                      overlays: widget.overlays,
                      target: widget.target,
                    ),
                  ),
                ),
              ),
            )
          ),
          ),
        );
      },
    );
  }
}
class _NoScrollBehavior extends ScrollBehavior {
  const _NoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };

  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
class _DartboardPainter extends CustomPainter {
  final List<DartThrow> throws;
  final Set<DartboardOverlayType> overlays;
  final String? target;

  _DartboardPainter({
    required this.throws,
    required this.overlays,
    this.target,
  });

  static const List<int> _sectors = [
    20, 1, 18, 4, 13,
    6, 10, 15, 2, 17,
    3, 19, 7, 16, 8,
    11, 14, 9, 12, 5,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    _drawBoard(canvas, center, r);

    if (overlays.contains(DartboardOverlayType.heatmap)) {
      _drawHeatmap(canvas, size, r);
    }

    if (overlays.contains(DartboardOverlayType.targetCenter)) {
      _drawTargetCenter(canvas, center, r);
    }

    if (overlays.contains(DartboardOverlayType.dispersion)) {
      _drawDispersion(canvas, size, r);
    }

    if (overlays.contains(DartboardOverlayType.bias)) {
      _drawBias(canvas, size, r);
    }
    if (overlays.contains(DartboardOverlayType.directionalBias)) {
      _drawDirectionalBias(canvas, size, r);
    }
    if (overlays.contains(DartboardOverlayType.targetZone)) {
      _drawTargetZone(canvas, center, r);
    }

    if (overlays.contains(DartboardOverlayType.radialError)) {
      _drawRadialError(canvas, size, r);
    }
    if (overlays.contains(DartboardOverlayType.throws)) {
      _drawThrows(canvas, size, r);
    }

  }
  void _drawTargetZone(Canvas canvas, Offset center, double r) {
    if (target == null) return;

    final paint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final bullInner = r * (6.35 / 225.5);
    final bullOuter = r * (15.9 / 225.5);
    final tripleInner = r * (99 / 225.5);
    final tripleOuter = r * (107 / 225.5);
    final doubleInner = r * (162 / 225.5);
    final doubleOuter = r * (170 / 225.5);

    if (target!.endsWith("25")) {
      canvas.drawCircle(center, bullOuter, paint);
      return;
    }

    const sectorAngle = 2 * pi / 20;
    const startOffset = -pi / 2 - sectorAngle / 2;

    final ring = target![0];
    final value = int.tryParse(target!.substring(1));
    if (value == null) return;

    final index = _sectors.indexOf(value);
    if (index == -1) return;

    final start = startOffset + index * sectorAngle;
    final sweep = sectorAngle;

    double inner;
    double outer;

    if (ring == 'T') {
      inner = tripleInner;
      outer = tripleOuter;
    } else if (ring == 'D') {
      inner = doubleInner;
      outer = doubleOuter;
    } else {
      inner = bullOuter;
      outer = tripleInner;
    }

    final rectOuter = Rect.fromCircle(center: center, radius: outer);
    final rectInner = Rect.fromCircle(center: center, radius: inner);

    final path = Path()
      ..addArc(rectOuter, start, sweep)
      ..arcTo(rectInner, start + sweep, -sweep, false)
      ..close();

    canvas.drawPath(path, paint);
  }
  void _drawRadialError(Canvas canvas, Size size, double r) {
    if (throws.isEmpty) return;

    final boardCenter = Offset(size.width / 2, size.height / 2);
    final targetCenter = _getTargetCenter(boardCenter, r);

    double total = 0;
    int n = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      total += t.distanceMm;
      n++;
    }

    if (n == 0) return;

    final avgMm = total / n;

    // conversione mm → pixel (diametro board 451mm)
    final pxPerMm = size.width / 451;
    final radiusPx = avgMm * pxPerMm;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(targetCenter, radiusPx, paint);

    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.006;

    canvas.drawCircle(targetCenter, radiusPx, border);
  }
  Offset _getTargetCenter(Offset center, double r) {
    if (target == null) return center;

    final bullInner = r * (6.35 / 225.5);
    final bullOuter = r * (15.9 / 225.5);
    final tripleInner = r * (99 / 225.5);
    final tripleOuter = r * (107 / 225.5);
    final doubleInner = r * (162 / 225.5);
    final doubleOuter = r * (170 / 225.5);

    if (target!.endsWith("25")) {
      return center;
    }

    const sectorAngle = 2 * pi / 20;
    const startOffset = -pi / 2 - sectorAngle / 2;

    final ring = target![0];
    final value = int.tryParse(target!.substring(1));

    if (value == null) return center;

    final index = _sectors.indexOf(value);
    if (index == -1) return center;

    final angle = startOffset + index * sectorAngle + sectorAngle / 2;

    double radius;

    if (ring == 'T') {
      radius = (tripleInner + tripleOuter) / 2;
    } else if (ring == 'D') {
      radius = (doubleInner + doubleOuter) / 2;
    } else {
      radius = (bullOuter + tripleInner) / 2;
    }

    return Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );

  }

  void _drawTargetCenter(Canvas canvas, Offset center, double r) {
    final targetCenter = _getTargetCenter(center, r);

    final paint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.01;

    canvas.drawCircle(targetCenter, r * 0.06, paint);

  }

  void _drawBias(Canvas canvas, Size size, double r) {
    if (throws.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    int n = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      sumX += t.position.dx;
      sumY += t.position.dy;
      n++;
    }

    if (n == 0) return;

    final mean = Offset(sumX / n * size.width, sumY / n * size.height);

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = r * 0.008;

    canvas.drawCircle(mean, r * 0.02, paint);

  }
  void _drawDirectionalBias(Canvas canvas, Size size, double r) {
    if (throws.length < 2) return;

    double meanX = 0;
    double meanY = 0;
    int n = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      meanX += t.position.dx;
      meanY += t.position.dy;
      n++;
    }

    if (n < 2) return;

    meanX /= n;
    meanY /= n;

    double varX = 0;
    double varY = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      varX += pow(t.position.dx - meanX, 2);
      varY += pow(t.position.dy - meanY, 2);
    }

    final stdX = sqrt(varX / n);
    final stdY = sqrt(varY / n);

    final centerX = meanX * size.width;
    final centerY = meanY * size.height;

    final halfBandX = max(r * 0.03, stdX * size.width * 2);
    final halfBandY = max(r * 0.03, stdY * size.height * 2);

    final verticalBand = Rect.fromLTWH(
      centerX - halfBandX,
      0,
      halfBandX * 2,
      size.height,
    );
    final horizontalBand = Rect.fromLTWH(
      0,
      centerY - halfBandY,
      size.width,
      halfBandY * 2,
    );

    final fillX = Paint()
      ..color = Colors.red.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final fillY = Paint()
      ..color = Colors.orange.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    canvas.drawRect(verticalBand, fillX);
    canvas.drawRect(horizontalBand, fillY);

    final line = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, r * 0.006);

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), line);
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), line);
  }
  void _drawErrorVector(Canvas canvas, Size size, double r) {
    if (throws.isEmpty) return;

    final boardCenter = Offset(size.width / 2, size.height / 2);
    final targetCenter = _getTargetCenter(boardCenter, r);

    double sumX = 0;
    double sumY = 0;
    int n = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      sumX += t.position.dx;
      sumY += t.position.dy;
      n++;
    }

    if (n == 0) return;

    final mean = Offset(
      sumX / n * size.width,
      sumY / n * size.height,
    );

    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = r * 0.01
      ..style = PaintingStyle.stroke;

// linea errore
    canvas.drawLine(targetCenter, mean, paint);

// punta freccia
    final angle = atan2(mean.dy - targetCenter.dy, mean.dx - targetCenter.dx);

    const arrowSizeFactor = 0.04;

    final arrowLength = r * arrowSizeFactor;

    final p1 = Offset(
      mean.dx - cos(angle - pi / 6) * arrowLength,
      mean.dy - sin(angle - pi / 6) * arrowLength,
    );

    final p2 = Offset(
      mean.dx - cos(angle + pi / 6) * arrowLength,
      mean.dy - sin(angle + pi / 6) * arrowLength,
    );

    final path = Path()
      ..moveTo(mean.dx, mean.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(mean.dx, mean.dy)
      ..lineTo(p2.dx, p2.dy);

    canvas.drawPath(path, paint);
  }
  void _drawDispersion(Canvas canvas, Size size, double r) {
    if (throws.length < 2) return;

    double meanX = 0;
    double meanY = 0;
    int n = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      meanX += t.position.dx;
      meanY += t.position.dy;
      n++;
    }

    if (n == 0) return;

    meanX /= n;
    meanY /= n;

    double varX = 0;
    double varY = 0;

    for (final t in throws) {
      if (t.isPass) continue;
      varX += pow(t.position.dx - meanX, 2);
      varY += pow(t.position.dy - meanY, 2);
    }

    final stdX = sqrt(varX / n);
    final stdY = sqrt(varY / n);

    final centerPx = Offset(meanX * size.width, meanY * size.height);

    final rect = Rect.fromCenter(
      center: centerPx,
      width: stdX * size.width * 4,
      height: stdY * size.height * 4,
    );

    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    canvas.drawOval(rect, paint);

  }

  void _drawThrows(Canvas canvas, Size size, double r) {
    final fill = Paint()..color = const Color(0xFF1976D2);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, r * 0.0045);

    for (final t in throws) {
      if (t.isPass) continue;

      final pos = Offset(
        t.position.dx * size.width,
        t.position.dy * size.height,
      );

      final radius = max(3.0, r * 0.012);

      canvas.drawCircle(pos, radius, fill);
      canvas.drawCircle(pos, radius, stroke);
    }
  }

  void _drawHeatmap(Canvas canvas, Size size, double r) {

    const gridSize = 80; // risoluzione heatmap
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    // 1. GRID DENSITÀ
    final grid = List.generate(
      gridSize,
          (_) => List<double>.filled(gridSize, 0),
    );

    for (final t in throws) {
      if (t.isPass) continue;

      final gx = (t.position.dx * gridSize).clamp(0, gridSize - 1).toInt();
      final gy = (t.position.dy * gridSize).clamp(0, gridSize - 1).toInt();

      grid[gx][gy] += 1;
    }

    // 2. BLUR SEMPLICE (kernel)
    final blurred = List.generate(
      gridSize,
          (_) => List<double>.filled(gridSize, 0),
    );

    const kernelRadius = 2;

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {

        double sum = 0;
        double weightSum = 0;

        for (int dx = -kernelRadius; dx <= kernelRadius; dx++) {
          for (int dy = -kernelRadius; dy <= kernelRadius; dy++) {

            final nx = x + dx;
            final ny = y + dy;

            if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;

            final dist = sqrt((dx * dx + dy * dy).toDouble());
            final weight = exp(-dist * 0.8);

            sum += grid[nx][ny] * weight;
            weightSum += weight;
          }
        }

        blurred[x][y] = weightSum == 0 ? 0 : sum / weightSum;
      }
    }

    // 3. NORMALIZZAZIONE
    double maxVal = 0;
    for (var row in blurred) {
      for (var v in row) {
        if (v > maxVal) maxVal = v;
      }
    }

    if (maxVal == 0) return;

    // 4. RENDER
    final paint = Paint();

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {

        final v = blurred[x][y] / maxVal;

        if (v < 0.05) continue;

        paint.color = _heatColor(v);

        canvas.drawRect(
          Rect.fromLTWH(
            x * cellW,
            y * cellH,
            cellW,
            cellH,
          ),
          paint,
        );
      }
    }
  }
  Color _heatColor(double t) {
    t = t.clamp(0.0, 1.0);

    if (t < 0.25) {
      return Colors.blue.withOpacity(0.25 * t);
    } else if (t < 0.5) {
      return Color.lerp(Colors.blue, Colors.green, (t - 0.25) * 4)!
          .withOpacity(0.4);
    } else if (t < 0.75) {
      return Color.lerp(Colors.green, Colors.yellow, (t - 0.5) * 4)!
          .withOpacity(0.55);
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (t - 0.75) * 4)!
          .withOpacity(0.7);
    }
  }
  void _drawQuadrants(Canvas canvas, Size size, Offset c) {
    final p = Paint()..color = Colors.blue.withOpacity(0.05);
    canvas.drawRect(Rect.fromLTWH(0, 0, c.dx, c.dy), p);
    canvas.drawRect(Rect.fromLTWH(c.dx, 0, c.dx, c.dy), p);
    canvas.drawRect(Rect.fromLTWH(0, c.dy, c.dx, c.dy), p);
    canvas.drawRect(Rect.fromLTWH(c.dx, c.dy, c.dx, c.dy), p);
  }

  void _drawBoard(Canvas canvas, Offset center, double boardRadius) {

    final bullInner = boardRadius * (6.35 / 225.5);
    final bullOuter = boardRadius * (15.9 / 225.5);
    final tripleInner = boardRadius * (99 / 225.5);
    final tripleOuter = boardRadius * (107 / 225.5);
    final doubleInner = boardRadius * (162 / 225.5);
    final doubleOuter = boardRadius * (170 / 225.5);
    final numberRingOuter = boardRadius * (205 / 225.5);
    final numberTextRadius = boardRadius * (186 / 225.5);

    final sectorAngle = 2 * pi / 20;
    final startOffset = -pi / 2 - sectorAngle / 2;

    final paintBlack = Paint()..color = const Color(0xFF101010);
    final paintCream = Paint()..color = const Color(0xFFF1E9D2);
    final paintRed = Paint()..color = const Color(0xFFC8102E);
    final paintGreen = Paint()..color = const Color(0xFF007A33);
    final paintNumberRing = Paint()..color = const Color(0xFF181818);

    final wirePaint = Paint()
      ..color = const Color(0xFFC9C9C9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, boardRadius * 0.006);

    canvas.drawCircle(center, numberRingOuter, paintNumberRing);

    for (int i = 0; i < 20; i++) {
      final start = startOffset + i * sectorAngle;
      final single = i.isEven ? paintBlack : paintCream;
      final ring = i.isEven ? paintRed : paintGreen;

      _drawRing(canvas, center, bullOuter, tripleInner, start, sectorAngle, single);
      _drawRing(canvas, center, tripleInner, tripleOuter, start, sectorAngle, ring);
      _drawRing(canvas, center, tripleOuter, doubleInner, start, sectorAngle, single);
      _drawRing(canvas, center, doubleInner, doubleOuter, start, sectorAngle, ring);
    }

    canvas.drawCircle(center, bullOuter, paintGreen);
    canvas.drawCircle(center, bullInner, paintRed);

    // WIRES RADIALI
    for (int i = 0; i < 20; i++) {
      final angle = startOffset + i * sectorAngle;

      final p1 = Offset(
        center.dx + cos(angle) * bullOuter,
        center.dy + sin(angle) * bullOuter,
      );
      final p2 = Offset(
        center.dx + cos(angle) * doubleOuter,
        center.dy + sin(angle) * doubleOuter,
      );

      canvas.drawLine(p1, p2, wirePaint);
    }

    // WIRES CERCHI
    for (final radius in [
      bullOuter,
      tripleInner,
      tripleOuter,
      doubleInner,
      doubleOuter,
    ]) {
      canvas.drawCircle(center, radius, wirePaint);
    }

    // NUMERI
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < 20; i++) {
      final angle = startOffset + i * sectorAngle + sectorAngle / 2;

      final pos = Offset(
        center.dx + cos(angle) * numberTextRadius,
        center.dy + sin(angle) * numberTextRadius,
      );

      textPainter.text = TextSpan(
        text: _sectors[i].toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: max(10, boardRadius * 0.09),
          fontWeight: FontWeight.w700,
        ),
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawRing(
      Canvas canvas,
      Offset center,
      double inner,
      double outer,
      double start,
      double sweep,
      Paint paint,
      ) {
    final outerRect = Rect.fromCircle(center: center, radius: outer);
    final innerRect = Rect.fromCircle(center: center, radius: inner);

    final path = Path()
      ..arcTo(outerRect, start, sweep, false)
      ..arcTo(innerRect, start + sweep, -sweep, false)
      ..close();

    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _DartboardPainter old) {
    return old.throws != throws || old.overlays != overlays;
  }
}
