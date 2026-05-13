import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../app_theme.dart';

enum UnifiedStatsChartMode {
  line,
  points,
  lineAndPoints,
}

class UnifiedStatsPoint {
  final double x;
  final double y;
  final String label;
  final String detail;

  const UnifiedStatsPoint({
    required this.x,
    required this.y,
    required this.label,
    required this.detail,
  });
}

class UnifiedStatsChart extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<UnifiedStatsPoint> points;
  final UnifiedStatsChartMode mode;
  final String xAxisLabel;
  final String yAxisLabel;
  final bool invertYAxis;
  final double? minYValue;
  final double? maxYValue;
  final double height;
  final String infoTitle;
  final String infoText;
  final List<String> advice;

  const UnifiedStatsChart({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    this.mode = UnifiedStatsChartMode.lineAndPoints,
    this.xAxisLabel = 'X',
    this.yAxisLabel = 'Y',
    this.invertYAxis = false,
    this.minYValue,
    this.maxYValue,
    this.height = 360,
    required this.infoTitle,
    required this.infoText,
    this.advice = const [],
  });

  factory UnifiedStatsChart.fakeTrainingPreview({Key? key}) {
    final points = List<UnifiedStatsPoint>.generate(42, (index) {
      final x = index + 1.0;
      final wave = math.sin(index / 3.0) * 9.0;
      final trend = index * 0.85;
      final correction = index % 7 == 0 ? -8.0 : 0.0;
      final y = 42.0 + trend + wave + correction;

      return UnifiedStatsPoint(
        x: x,
        y: y.clamp(18.0, 92.0),
        label: 'Tiro ${index + 1}',
        detail: 'Sequenza fake ${index + 1}: valore ${y.toStringAsFixed(1)}',
      );
    });

    return UnifiedStatsChart(
      key: key,
      title: 'Grafico statistiche unico',
      subtitle: 'Grafico XY reale: pan e zoom modificano i valori degli assi, non una immagine.',
      points: points,
      xAxisLabel: 'freccetta',
      yAxisLabel: 'valore',
      infoTitle: 'Come leggere il grafico',
      infoText:
      'Il grafico lavora come un grafico professionale: trascinando sposti il range visibile, '
          'zoomando in orizzontale restringi o allarghi X, zoomando in verticale restringi o allarghi Y.',
      advice: const [
        'Zoom orizzontale: restringe o allarga il range X visibile.',
        'Zoom verticale: restringe o allarga il range Y visibile.',
        'Pan: sposta la finestra visibile sui dati.',
        'Reset: torna al range completo dei dati.',
      ],
    );
  }

  @override
  State<UnifiedStatsChart> createState() => _UnifiedStatsChartState();
}

class _UnifiedStatsChartState extends State<UnifiedStatsChart> {
  static const double _axisLeftWidth = 64;
  static const double _axisBottomHeight = 36;
  static const double _axisTopPad = 12;
  static const double _axisRightPad = 12;

  _UnifiedStatsBounds _dataBounds = const _UnifiedStatsBounds(
    minX: 0,
    maxX: 1,
    minY: 0,
    maxY: 1,
  );

  _UnifiedStatsBounds _visibleBounds = const _UnifiedStatsBounds(
    minX: 0,
    maxX: 1,
    minY: 0,
    maxY: 1,
  );

  _UnifiedStatsBounds _gestureStartBounds = const _UnifiedStatsBounds(
    minX: 0,
    maxX: 1,
    minY: 0,
    maxY: 1,
  );

  Offset _gestureStartLocal = Offset.zero;
  Size _plotSize = Size.zero;
  UnifiedStatsPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _dataBounds = _calculateDataBounds();
    _visibleBounds = _dataBounds;
  }

  @override
  void didUpdateWidget(covariant UnifiedStatsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _dataBounds = _calculateDataBounds();
      _visibleBounds = _dataBounds;
      _gestureStartBounds = _dataBounds;
    }
  }

  _UnifiedStatsBounds _calculateDataBounds() {
    if (widget.points.isEmpty) {
      return const _UnifiedStatsBounds(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
      );
    }

    final minXRaw = widget.points.map((p) => p.x).reduce(math.min);
    final maxXRaw = widget.points.map((p) => p.x).reduce(math.max);
    final minYRaw = widget.minYValue ?? widget.points.map((p) => p.y).reduce(math.min);
    final maxYRaw = widget.maxYValue ?? widget.points.map((p) => p.y).reduce(math.max);

    final xRange = (maxXRaw - minXRaw).abs();
    final yRange = (maxYRaw - minYRaw).abs();

    final xPadding = xRange == 0 ? 1.0 : (xRange * 0.04).clamp(1.0, 8.0);
    final yPadding = widget.minYValue != null || widget.maxYValue != null
        ? 0.0
        : (yRange == 0 ? 1.0 : (yRange * 0.16).clamp(6.0, 18.0));

    return _UnifiedStatsBounds(
      minX: minXRaw - xPadding,
      maxX: maxXRaw + xPadding,
      minY: minYRaw - yPadding,
      maxY: maxYRaw + yPadding,
    );
  }

  void _resetZoom() {
    setState(() {
      _dataBounds = _calculateDataBounds();
      _visibleBounds = _dataBounds;
      _gestureStartBounds = _dataBounds;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartBounds = _visibleBounds;
    _gestureStartLocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_plotSize.width <= 0 || _plotSize.height <= 0) return;

    final pointerCount = details.pointerCount;
    final local = details.localFocalPoint;

    if (pointerCount <= 1) {
      final dxPx = local.dx - _gestureStartLocal.dx;
      final dyPx = local.dy - _gestureStartLocal.dy;

      final dxValue = -dxPx / _plotSize.width * _gestureStartBounds.xRange;
      final dyValue = widget.invertYAxis
          ? -dyPx / _plotSize.height * _gestureStartBounds.yRange
          : dyPx / _plotSize.height * _gestureStartBounds.yRange;

      final moved = _gestureStartBounds.shifted(
        dx: dxValue,
        dy: dyValue,
      );

      setState(() {
        _visibleBounds = _clampToData(moved);
      });
      return;
    }

    final horizontalScale = details.horizontalScale <= 0 ? 1.0 : details.horizontalScale;
    final verticalScale = details.verticalScale <= 0 ? 1.0 : details.verticalScale;

    final focalXRatio = (local.dx / _plotSize.width).clamp(0.0, 1.0);
    final focalYRatio = (local.dy / _plotSize.height).clamp(0.0, 1.0);

    final focalX = _gestureStartBounds.minX + _gestureStartBounds.xRange * focalXRatio;
    final focalY = _gestureStartBounds.maxY - _gestureStartBounds.yRange * focalYRatio;

    final nextXRange = (_gestureStartBounds.xRange / horizontalScale)
        .clamp(_dataBounds.xRange / 80, _dataBounds.xRange * 4);

    final nextYRange = (_gestureStartBounds.yRange / verticalScale)
        .clamp(_dataBounds.yRange / 80, _dataBounds.yRange * 4);

    final nextMinX = focalX - nextXRange * focalXRatio;
    final nextMaxX = nextMinX + nextXRange;

    final nextMaxY = focalY + nextYRange * focalYRatio;
    final nextMinY = nextMaxY - nextYRange;

    setState(() {
      _visibleBounds = _clampToData(
        _UnifiedStatsBounds(
          minX: nextMinX,
          maxX: nextMaxX,
          minY: nextMinY,
          maxY: nextMaxY,
        ),
      );
    });
  }
  void _onTapUp(TapUpDetails details) {
    if (_plotSize.width <= 0 || _plotSize.height <= 0 || widget.points.isEmpty) {
      return;
    }

    final local = details.localPosition;
    const hitRadius = 18.0;

    UnifiedStatsPoint? nearest;
    double nearestDistance = double.infinity;

    for (final point in widget.points) {
      if (point.x < _visibleBounds.minX ||
          point.x > _visibleBounds.maxX ||
          point.y < _visibleBounds.minY ||
          point.y > _visibleBounds.maxY) {
        continue;
      }

      final dx = (point.x - _visibleBounds.minX) / _visibleBounds.xRange;
      final dy = (point.y - _visibleBounds.minY) / _visibleBounds.yRange;

      final mapped = Offset(
        dx * _plotSize.width,
        widget.invertYAxis
            ? dy * _plotSize.height
            : _plotSize.height - dy * _plotSize.height,
      );

      final distance = (mapped - local).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = point;
      }
    }

    setState(() {
      _selectedPoint = nearestDistance <= hitRadius ? nearest : null;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_plotSize.width <= 0 || _plotSize.height <= 0) return;

    final local = event.localPosition;
    final focalXRatio = (local.dx / _plotSize.width).clamp(0.0, 1.0);
    final focalYRatio = (local.dy / _plotSize.height).clamp(0.0, 1.0);

    final isHorizontalIntent = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs();
    final zoomIn = isHorizontalIntent ? event.scrollDelta.dx < 0 : event.scrollDelta.dy < 0;
    final factor = zoomIn ? 0.86 : 1.16;

    if (isHorizontalIntent) {
      _zoomX(factor, focalXRatio);
    } else {
      _zoomY(factor, focalYRatio);
    }
  }

  void _zoomX(double factor, double focalRatio) {
    final focal = _visibleBounds.minX + _visibleBounds.xRange * focalRatio;
    final nextRange = (_visibleBounds.xRange * factor)
        .clamp(_dataBounds.xRange / 80, _dataBounds.xRange * 4);

    final minX = focal - nextRange * focalRatio;
    final maxX = minX + nextRange;

    setState(() {
      _visibleBounds = _clampToData(
        _UnifiedStatsBounds(
          minX: minX,
          maxX: maxX,
          minY: _visibleBounds.minY,
          maxY: _visibleBounds.maxY,
        ),
      );
    });
  }

  void _zoomY(double factor, double focalRatio) {
    final focal = _visibleBounds.maxY - _visibleBounds.yRange * focalRatio;
    final nextRange = (_visibleBounds.yRange * factor)
        .clamp(_dataBounds.yRange / 80, _dataBounds.yRange * 4);

    final maxY = focal + nextRange * focalRatio;
    final minY = maxY - nextRange;

    setState(() {
      _visibleBounds = _clampToData(
        _UnifiedStatsBounds(
          minX: _visibleBounds.minX,
          maxX: _visibleBounds.maxX,
          minY: minY,
          maxY: maxY,
        ),
      );
    });
  }

  _UnifiedStatsBounds _clampToData(_UnifiedStatsBounds input) {
    double minX = input.minX;
    double maxX = input.maxX;
    double minY = input.minY;
    double maxY = input.maxY;

    final xRange = maxX - minX;
    final yRange = maxY - minY;

    final minAllowedX = _dataBounds.minX - _dataBounds.xRange * 1.5;
    final maxAllowedX = _dataBounds.maxX + _dataBounds.xRange * 1.5;
    final minAllowedY = _dataBounds.minY - _dataBounds.yRange * 1.5;
    final maxAllowedY = _dataBounds.maxY + _dataBounds.yRange * 1.5;

    if (minX < minAllowedX) {
      minX = minAllowedX;
      maxX = minX + xRange;
    }

    if (maxX > maxAllowedX) {
      maxX = maxAllowedX;
      minX = maxX - xRange;
    }

    if (minY < minAllowedY) {
      minY = minAllowedY;
      maxY = minY + yRange;
    }

    if (maxY > maxAllowedY) {
      maxY = maxAllowedY;
      minY = maxY - yRange;
    }

    return _UnifiedStatsBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  void _openInfo() {
    final t = AppTokens.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.overlay,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: t.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.infoTitle,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.infoText,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.advice.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'CONSIGLI',
                    style: t.labelCaps(t.textMuted),
                  ),
                  const SizedBox(height: 8),
                  for (final item in widget.advice)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, color: t.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 12.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    _dataBounds = _calculateDataBounds();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UnifiedStatsHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            onInfo: _openInfo,
            onReset: _resetZoom,
          ),
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plotWidth = math.max(
                  1.0,
                  constraints.maxWidth - _axisLeftWidth - _axisRightPad,
                );
                final plotHeight = math.max(
                  1.0,
                  constraints.maxHeight - _axisTopPad - _axisBottomHeight,
                );

                _plotSize = Size(plotWidth, plotHeight);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.surfaceHigh,
                          border: Border(
                            top: BorderSide(color: t.divider),
                            bottom: BorderSide(color: t.divider),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: _axisTopPad,
                      bottom: _axisBottomHeight,
                      width: _axisLeftWidth,
                      child: CustomPaint(
                        painter: _UnifiedStatsFixedYAxisPainter(
                          visibleBounds: _visibleBounds,
                          tokens: t,
                          axisLabel: widget.yAxisLabel,
                          invertYAxis: widget.invertYAxis,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _axisLeftWidth,
                      right: _axisRightPad,
                      bottom: 0,
                      height: _axisBottomHeight,
                      child: CustomPaint(
                        painter: _UnifiedStatsFixedXAxisPainter(
                          visibleBounds: _visibleBounds,
                          tokens: t,
                          axisLabel: widget.xAxisLabel,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _axisLeftWidth,
                      right: _axisRightPad,
                      top: _axisTopPad,
                      bottom: _axisBottomHeight,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerSignal: _onPointerSignal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {},
                          onTapUp: _onTapUp,
                          onDoubleTap: _resetZoom,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: CustomPaint(
                            painter: _UnifiedStatsPlotPainter(
                              points: widget.points,
                              mode: widget.mode,
                              visibleBounds: _visibleBounds,
                              tokens: t,
                              selectedPoint: _selectedPoint,
                              invertYAxis: widget.invertYAxis,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _UnifiedStatsPointDetails(
            point: _selectedPoint,
            xAxisLabel: widget.xAxisLabel,
            yAxisLabel: widget.yAxisLabel,
          ),

          //_UnifiedStatsFakeTable(points: widget.points),
        ],
      ),
    );
  }
}

class _UnifiedStatsBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _UnifiedStatsBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get xRange => maxX - minX;
  double get yRange => maxY - minY;

  _UnifiedStatsBounds shifted({
    required double dx,
    required double dy,
  }) {
    return _UnifiedStatsBounds(
      minX: minX + dx,
      maxX: maxX + dx,
      minY: minY + dy,
      maxY: maxY + dy,
    );
  }
}

class _UnifiedStatsHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onInfo;
  final VoidCallback onReset;

  const _UnifiedStatsHeader({
    required this.title,
    required this.subtitle,
    required this.onInfo,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.16),
              borderRadius: AppTokens.r12,
              border: Border.all(color: t.accent.withOpacity(0.38)),
            ),
            child: Icon(Icons.show_chart_rounded, color: t.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Info',
            onPressed: onInfo,
            icon: Icon(Icons.info_outline_rounded, color: t.textSecondary),
          ),
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: onReset,
            icon: Icon(Icons.center_focus_strong_rounded, color: t.accent),
          ),
        ],
      ),
    );
  }
}

class _UnifiedStatsFixedYAxisPainter extends CustomPainter {
  final _UnifiedStatsBounds visibleBounds;
  final AppTokens tokens;
  final String axisLabel;
  final bool invertYAxis;

  const _UnifiedStatsFixedYAxisPainter({
    required this.visibleBounds,
    required this.tokens,
    required this.axisLabel,
    required this.invertYAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = tokens.border
      ..strokeWidth = 1.4;

    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      axisPaint,
    );

    final ticks = _niceTicks(visibleBounds.minY, visibleBounds.maxY, 6);

    for (final tick in ticks) {
      final normalized = invertYAxis
          ? (tick - visibleBounds.minY) / visibleBounds.yRange
          : (visibleBounds.maxY - tick) / visibleBounds.yRange;
      final y = normalized.clamp(0.0, 1.0) * size.height;

      _drawText(
        canvas,
        _formatTick(tick),
        Offset(7, y - 7),
        tokens.textMuted,
        10,
        FontWeight.w800,
      );
    }

    _drawText(
      canvas,
      axisLabel,
      const Offset(8, 4),
      tokens.accent,
      11,
      FontWeight.w900,
    );
  }

  List<double> _niceTicks(double min, double max, int targetCount) {
    final range = (max - min).abs();
    if (range == 0) return [min];

    final rawStep = range / targetCount;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;

    final niceStep = residual >= 5
        ? 5 * magnitude
        : residual >= 2
        ? 2 * magnitude
        : magnitude;

    final start = (min / niceStep).ceil() * niceStep;
    final values = <double>[];

    for (double v = start; v <= max + niceStep * 0.5; v += niceStep) {
      values.add(v);
    }

    if (values.isEmpty) {
      values.add(min);
      values.add(max);
    }

    return values;
  }

  String _formatTick(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value.abs() >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  void _drawText(
      Canvas canvas,
      String text,
      Offset offset,
      Color color,
      double size,
      FontWeight weight,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 45);

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _UnifiedStatsFixedYAxisPainter oldDelegate) {
    return oldDelegate.visibleBounds != visibleBounds ||
        oldDelegate.tokens != tokens ||
        oldDelegate.axisLabel != axisLabel ||
        oldDelegate.invertYAxis != invertYAxis;
  }
}

class _UnifiedStatsFixedXAxisPainter extends CustomPainter {
  final _UnifiedStatsBounds visibleBounds;
  final AppTokens tokens;
  final String axisLabel;

  const _UnifiedStatsFixedXAxisPainter({
    required this.visibleBounds,
    required this.tokens,
    required this.axisLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = tokens.border
      ..strokeWidth = 1.4;

    canvas.drawLine(
      const Offset(0, 1),
      Offset(size.width, 1),
      axisPaint,
    );

    final ticks = _niceTicks(visibleBounds.minX, visibleBounds.maxX, 5);

    for (final tick in ticks) {
      final normalized = (tick - visibleBounds.minX) / visibleBounds.xRange;
      final x = normalized.clamp(0.0, 1.0) * size.width;

      _drawText(
        canvas,
        _formatTick(tick),
        Offset(x - 8, 10),
        tokens.textMuted,
        10,
        FontWeight.w800,
      );
    }

    _drawTextRightAligned(
      canvas,
      axisLabel,
      Offset(size.width - 4, 10),
      tokens.accent,
      11,
      FontWeight.w900,
    );
  }

  List<double> _niceTicks(double min, double max, int targetCount) {
    final range = (max - min).abs();
    if (range == 0) return [min];

    final rawStep = range / targetCount;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;

    final niceStep = residual >= 5
        ? 5 * magnitude
        : residual >= 2
        ? 2 * magnitude
        : magnitude;

    final start = (min / niceStep).ceil() * niceStep;
    final values = <double>[];

    for (double v = start; v <= max + niceStep * 0.5; v += niceStep) {
      values.add(v);
    }

    if (values.isEmpty) {
      values.add(min);
      values.add(max);
    }

    return values;
  }

  String _formatTick(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value.abs() >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  void _drawText(
      Canvas canvas,
      String text,
      Offset offset,
      Color color,
      double size,
      FontWeight weight,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }
  void _drawTextRightAligned(
      Canvas canvas,
      String text,
      Offset offset,
      Color color,
      double size,
      FontWeight weight,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, Offset(offset.dx - painter.width, offset.dy));
  }
  @override
  bool shouldRepaint(covariant _UnifiedStatsFixedXAxisPainter oldDelegate) {
    return oldDelegate.visibleBounds != visibleBounds ||
        oldDelegate.tokens != tokens ||
        oldDelegate.axisLabel != axisLabel;
  }
}

class _UnifiedStatsPlotPainter extends CustomPainter {
  final List<UnifiedStatsPoint> points;
  final UnifiedStatsChartMode mode;
  final _UnifiedStatsBounds visibleBounds;
  final AppTokens tokens;
  final UnifiedStatsPoint? selectedPoint;
  final bool invertYAxis;

  const _UnifiedStatsPlotPainter({
    required this.points,
    required this.mode,
    required this.visibleBounds,
    required this.tokens,
    required this.selectedPoint,
    required this.invertYAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chart = Offset.zero & size;

    canvas.clipRect(chart);

    final gridPaint = Paint()
      ..color = tokens.divider
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = tokens.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = tokens.accent
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = tokens.bg
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final selectedHaloPaint = Paint()
      ..color = tokens.accent.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final selectedBorderPaint = Paint()
      ..color = tokens.accent
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;


    Offset mapPoint(UnifiedStatsPoint p) {
      final dx = (p.x - visibleBounds.minX) / visibleBounds.xRange;
      final dy = (p.y - visibleBounds.minY) / visibleBounds.yRange;

      return Offset(
        chart.left + dx * chart.width,
        invertYAxis
            ? chart.top + dy * chart.height
            : chart.bottom - dy * chart.height,
      );
    }

    final visibleXTicks = _niceTicks(visibleBounds.minX, visibleBounds.maxX, 5);
    for (final tick in visibleXTicks) {
      final normalized = (tick - visibleBounds.minX) / visibleBounds.xRange;
      final x = normalized * chart.width;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
    }

    final visibleYTicks = _niceTicks(visibleBounds.minY, visibleBounds.maxY, 6);
    for (final tick in visibleYTicks) {
      final normalized = invertYAxis
          ? (tick - visibleBounds.minY) / visibleBounds.yRange
          : (visibleBounds.maxY - tick) / visibleBounds.yRange;
      final y = normalized * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final visiblePoints = points.where((p) {
      return p.x >= visibleBounds.minX &&
          p.x <= visibleBounds.maxX &&
          p.y >= visibleBounds.minY &&
          p.y <= visibleBounds.maxY;
    }).toList();

    final allMapped = points.map(mapPoint).toList();

    if (mode == UnifiedStatsChartMode.line || mode == UnifiedStatsChartMode.lineAndPoints) {
      final path = Path()..moveTo(allMapped.first.dx, allMapped.first.dy);
      for (int i = 1; i < allMapped.length; i++) {
        path.lineTo(allMapped[i].dx, allMapped[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    if (mode == UnifiedStatsChartMode.points || mode == UnifiedStatsChartMode.lineAndPoints) {
      for (int i = 0; i < visiblePoints.length; i++) {
        final point = visiblePoints[i];
        final p = mapPoint(point);
        final selected = selectedPoint == point;

        if (selected) {
          canvas.drawCircle(p, 12, selectedHaloPaint);
          canvas.drawCircle(p, 7.5, selectedBorderPaint);
        }

        canvas.drawCircle(p, 5.4, pointBorderPaint);
        canvas.drawCircle(p, selected ? 5.2 : 4.2, pointPaint);

        if (i % 4 == 0 || i == visiblePoints.length - 1) {
          _drawText(
            canvas,
            visiblePoints[i].y.toStringAsFixed(0),
            Offset(p.dx + 6, p.dy - 18),
            tokens.textSecondary,
            10,
            FontWeight.w800,
          );
        }
      }
    }
  }

  List<double> _niceTicks(double min, double max, int targetCount) {
    final range = (max - min).abs();
    if (range == 0) return [min];

    final rawStep = range / targetCount;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;

    final niceStep = residual >= 5
        ? 5 * magnitude
        : residual >= 2
        ? 2 * magnitude
        : magnitude;

    final start = (min / niceStep).ceil() * niceStep;
    final values = <double>[];

    for (double v = start; v <= max + niceStep * 0.5; v += niceStep) {
      values.add(v);
    }

    if (values.isEmpty) {
      values.add(min);
      values.add(max);
    }

    return values;
  }

  void _drawText(
      Canvas canvas,
      String text,
      Offset offset,
      Color color,
      double size,
      FontWeight weight,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _UnifiedStatsPlotPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.mode != mode ||
        oldDelegate.visibleBounds != visibleBounds ||
        oldDelegate.tokens != tokens ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.invertYAxis != invertYAxis;
  }
}
class _UnifiedStatsPointDetails extends StatelessWidget {
  final UnifiedStatsPoint? point;
  final String xAxisLabel;
  final String yAxisLabel;

  const _UnifiedStatsPointDetails({
    required this.point,
    required this.xAxisLabel,
    required this.yAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    if (point == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(
          children: [
            Icon(Icons.touch_app_rounded, color: t.textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tocca un punto del grafico per leggere il dettaglio.',
                style: t.bodySmall(t.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.analytics_rounded, color: t.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _UnifiedStatsPointChip(
                  label: xAxisLabel,
                  value: _formatValue(point!.x),
                ),
                _UnifiedStatsPointChip(
                  label: yAxisLabel,
                  value: _formatValue(point!.y),
                ),
                Text(
                  point!.detail,
                  style: t.bodySmall(t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}


class _UnifiedStatsPointChip extends StatelessWidget {
  final String label;
  final String value;

  const _UnifiedStatsPointChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: AppTokens.r8,
        border: Border.all(color: t.border),
      ),
      child: Text(
        '$label $value',
        style: t.bodyBold(t.textPrimary),
      ),
    );
  }
}

class _UnifiedStatsFakeTable extends StatelessWidget {
  final List<UnifiedStatsPoint> points;

  const _UnifiedStatsFakeTable({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final rows = points.take(18).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
      ),
      child: SingleChildScrollView(

        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 42,
          columnSpacing: 22,
          headingTextStyle: TextStyle(
            color: t.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
          dataTextStyle: TextStyle(
            color: t.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          columns: const [
            DataColumn(label: Text('IDX')),
            DataColumn(label: Text('LABEL')),
            DataColumn(label: Text('X')),
            DataColumn(label: Text('Y')),
            DataColumn(label: Text('DELTA')),
            DataColumn(label: Text('TREND')),
            DataColumn(label: Text('LETTURA')),
          ],
          rows: [
            for (int i = 0; i < rows.length; i++)
              DataRow(
                cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(rows[i].label)),
                  DataCell(Text(rows[i].x.toStringAsFixed(0))),
                  DataCell(Text(rows[i].y.toStringAsFixed(1))),
                  DataCell(Text(_deltaLabel(rows, i))),
                  DataCell(Text(_trendLabel(rows, i))),
                  DataCell(Text(rows[i].detail)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _deltaLabel(List<UnifiedStatsPoint> rows, int index) {
    if (index == 0) return '—';
    final delta = rows[index].y - rows[index - 1].y;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}';
  }

  String _trendLabel(List<UnifiedStatsPoint> rows, int index) {
    if (index == 0) return 'START';
    final delta = rows[index].y - rows[index - 1].y;
    if (delta > 3) return 'UP';
    if (delta < -3) return 'DOWN';
    return 'STABLE';
  }
}


class UnifiedStatsDistanceBucket {
  final String label;
  final int count;
  final double percent;
  final String detail;

  const UnifiedStatsDistanceBucket({
    required this.label,
    required this.count,
    required this.percent,
    required this.detail,
  });
}

class UnifiedStatsHorizontalBars extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<UnifiedStatsDistanceBucket> buckets;
  final String infoTitle;
  final String infoText;
  final List<String> advice;

  const UnifiedStatsHorizontalBars({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buckets,
    required this.infoTitle,
    required this.infoText,
    this.advice = const [],
  });

  void _openInfo(BuildContext context) {
    final t = AppTokens.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.overlay,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.info_rounded, color: t.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(infoTitle, style: t.bodyBold(t.textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(infoText, style: t.bodySmall(t.textSecondary)),
              if (advice.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('CONSIGLI', style: t.labelCaps(t.textMuted)),
                const SizedBox(height: 8),
                for (final item in advice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded, color: t.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item, style: t.bodySmall(t.textPrimary))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final maxCount = buckets.isEmpty
        ? 1
        : buckets.map((e) => e.count).reduce(math.max).clamp(1, 999999);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UnifiedStatsHeader(
            title: title,
            subtitle: subtitle,
            onInfo: () => _openInfo(context),
            onReset: () {},
          ),
          if (buckets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Text('Nessun dato disponibile.', style: t.bodySmall(t.textMuted)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  for (final bucket in buckets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UnifiedDistanceBarRow(
                        bucket: bucket,
                        maxCount: maxCount.toDouble(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
class UnifiedStatsTowerValue {
  final String label;
  final double value;
  final String topLabel;
  final String? subTopLabel;
  final Color? color;

  const UnifiedStatsTowerValue({
    required this.label,
    required this.value,
    required this.topLabel,
    this.subTopLabel,
    this.color,
  });
}

class UnifiedStatsTowerGroup {
  final String xLabel;
  final List<UnifiedStatsTowerValue> values;

  const UnifiedStatsTowerGroup({
    required this.xLabel,
    required this.values,
  });
}

class UnifiedStatsTowerChart extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<UnifiedStatsTowerGroup> groups;
  final String yAxisLabel;
  final double height;
  final String infoTitle;
  final String infoText;
  final List<String> advice;

  const UnifiedStatsTowerChart({
    super.key,
    required this.title,
    required this.subtitle,
    required this.groups,
    this.yAxisLabel = '',
    this.height = 320,
    this.infoTitle = 'Come leggere il grafico',
    this.infoText = 'Il grafico a torre mostra categorie sull’asse orizzontale e quantità o medie sull’asse verticale.',
    this.advice = const [],
  });

  @override
  State<UnifiedStatsTowerChart> createState() => _UnifiedStatsTowerChartState();
}

class _UnifiedStatsTowerChartState extends State<UnifiedStatsTowerChart> {
  void _openInfo() {
    final t = AppTokens.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.overlay,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: t.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.infoTitle,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.infoText,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.advice.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('CONSIGLI', style: t.labelCaps(t.textMuted)),
                  const SizedBox(height: 8),
                  for (final item in widget.advice)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, color: t.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 12.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetView() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    if (widget.groups.isEmpty) return const SizedBox.shrink();

    final maxBarsInGroup = widget.groups.fold<int>(
      1,
          (max, group) => group.values.length > max ? group.values.length : max,
    );

    final minWidth = (widget.groups.length * (maxBarsInGroup <= 1 ? 46.0 : 92.0))
        .clamp(520.0, 9000.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: AppTokens.r16,
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UnifiedStatsHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            onInfo: _openInfo,
            onReset: _resetView,
          ),
          SizedBox(
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surfaceHigh,
                border: Border(
                  top: BorderSide(color: t.divider),
                  bottom: BorderSide(color: t.divider),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  height: widget.height,
                  child: CustomPaint(
                    painter: _UnifiedStatsTowerPainter(
                      groups: widget.groups,
                      tokens: t,
                      yAxisLabel: widget.yAxisLabel,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grafico a torre standardizzato: confronta le barre per categoria e usa Info per leggere il significato del dato.',
                    style: t.bodySmall(t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedStatsTowerPainter extends CustomPainter {
  final List<UnifiedStatsTowerGroup> groups;
  final AppTokens tokens;
  final String yAxisLabel;

  const _UnifiedStatsTowerPainter({
    required this.groups,
    required this.tokens,
    required this.yAxisLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 18.0;
    const top = 18.0;
    const bottom = 50.0;

    final chart = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    if (groups.isEmpty) return;

    final allValues = groups.expand((group) => group.values).toList();
    if (allValues.isEmpty) return;

    final maxValue = allValues.fold<double>(
      0,
          (max, item) => item.value > max ? item.value : max,
    );

    final yMax = maxValue < 4 ? 4.0 : maxValue.ceilToDouble();

    final gridPaint = Paint()
      ..color = tokens.divider
      ..strokeWidth = 1;

    canvas.drawLine(chart.bottomLeft, chart.bottomRight, gridPaint);
    canvas.drawLine(chart.bottomLeft, chart.topLeft, gridPaint);

    for (int i = 0; i <= 4; i++) {
      final y = chart.bottom - (chart.height / 4) * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);

      final label = ((yMax / 4) * i).toStringAsFixed(0);
      _drawText(canvas, label, Offset(4, y - 7), tokens.textMuted, 10);
    }

    final groupWidth = chart.width / groups.length;

    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final visibleValues = group.values.where((value) => value.value > 0).toList();
      if (visibleValues.isEmpty) continue;

      final centerX = chart.left + groupWidth * i + groupWidth / 2;
      final barCount = visibleValues.length;
      final barWidth = barCount <= 1
          ? (groupWidth * 0.44).clamp(12.0, 30.0)
          : (groupWidth * 0.24).clamp(12.0, 30.0);
      final gap = (groupWidth * 0.08).clamp(4.0, 8.0);
      final totalBarsWidth = barWidth * barCount + gap * (barCount - 1);
      final startX = centerX - totalBarsWidth / 2;

      for (int valueIndex = 0; valueIndex < visibleValues.length; valueIndex++) {
        final value = visibleValues[valueIndex];
        final barHeight = (value.value / yMax) * chart.height;
        final x = startX + valueIndex * (barWidth + gap);

        final rect = Rect.fromLTWH(
          x,
          chart.bottom - barHeight,
          barWidth,
          barHeight,
        );

        final color = value.color ?? tokens.accent;

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );

        _drawCenteredText(
          canvas,
          value.topLabel,
          Offset(rect.center.dx, rect.top - 28),
          color,
          10,
        );

        final subTopLabel = value.subTopLabel;
        if (subTopLabel != null && subTopLabel.isNotEmpty) {
          _drawCenteredText(
            canvas,
            subTopLabel,
            Offset(rect.center.dx, rect.top - 15),
            color,
            9,
          );
        }
      }

      _drawCenteredText(
        canvas,
        group.xLabel,
        Offset(centerX, chart.bottom + 10),
        tokens.textMuted,
        10,
      );
    }

    if (yAxisLabel.isNotEmpty) {
      _drawText(canvas, yAxisLabel, Offset(0, chart.top - 14), tokens.textMuted, 10);
    }

    _drawLegend(canvas, chart);
  }

  void _drawLegend(Canvas canvas, Rect chart) {
    final ordered = <String, Color>{};

    for (final group in groups) {
      for (final value in group.values) {
        ordered.putIfAbsent(value.label, () => value.color ?? tokens.accent);
      }
    }

    if (ordered.length <= 1) return;

    double x = chart.left;
    final y = chart.bottom + 30;

    for (final entry in ordered.entries) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 10, 10),
          const Radius.circular(2),
        ),
        Paint()
          ..color = entry.value
          ..style = PaintingStyle.fill,
      );

      _drawText(canvas, entry.key, Offset(x + 14, y - 2), tokens.textMuted, 10);
      x += 64;
    }
  }

  void _drawCenteredText(
      Canvas canvas,
      String text,
      Offset center,
      Color color,
      double size,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  void _drawText(
      Canvas canvas,
      String text,
      Offset offset,
      Color color,
      double size,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _UnifiedStatsTowerPainter oldDelegate) {
    return oldDelegate.groups != groups ||
        oldDelegate.tokens != tokens ||
        oldDelegate.yAxisLabel != yAxisLabel;
  }
}

class _UnifiedDistanceBarRow extends StatelessWidget {
  final UnifiedStatsDistanceBucket bucket;
  final double maxCount;

  const _UnifiedDistanceBarRow({
    required this.bucket,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final ratio = maxCount <= 0 ? 0.0 : (bucket.count / maxCount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(bucket.label, style: t.bodyBold(t.textPrimary)),
            ),
            Text(
              '${bucket.count} • ${bucket.percent.toStringAsFixed(1)}%',
              style: t.bodyBold(t.accent),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: AppTokens.r8,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: t.surfaceHigh,
            color: t.accent,
          ),
        ),
        const SizedBox(height: 5),
        Text(bucket.detail, style: t.bodySmall(t.textSecondary)),
      ],
    );
  }
}