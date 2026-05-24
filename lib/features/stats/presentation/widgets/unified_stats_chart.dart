import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
class UnifiedStatsInfoData {
  final String title;
  final String text;
  final List<String> advice;
  final List<(String, Color)>? customLegend;

  const UnifiedStatsInfoData({
    required this.title,
    required this.text,
    this.advice = const [],
    this.customLegend,
  });
}

class UnifiedStatsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final UnifiedStatsInfoData info;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final IconData footerIcon;
  final String? footerText;
  final bool wrapChildInPanel;

  const UnifiedStatsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.info,
    required this.child,
    this.padding,
    this.footerIcon = Icons.analytics_rounded,
    this.footerText,
    this.wrapChildInPanel = false,
  });

  void _openInfo(BuildContext context) {
    _UnifiedStatsInfoSheet.show(
      context: context,
      title: info.title,
      text: info.text,
      advice: info.advice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

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
          ),
          _UnifiedStatsCardBody(
            padding: padding,
            wrapChildInPanel: wrapChildInPanel,
            footerIcon: footerIcon,
            footerText: footerText,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _UnifiedStatsCardBody extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool wrapChildInPanel;
  final IconData footerIcon;
  final String? footerText;

  const _UnifiedStatsCardBody({
    required this.child,
    required this.padding,
    required this.wrapChildInPanel,
    required this.footerIcon,
    required this.footerText,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wrapChildInPanel)
          DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceHigh,
              border: Border(
                top: BorderSide(color: t.divider),
                bottom: BorderSide(color: t.divider),
              ),
            ),
            child: content,
          )
        else
          content,
        if (footerText != null && footerText!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(footerIcon, color: t.textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    footerText!,
                    style: t.bodySmall(t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
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
  final double? minXValue;
  final double? maxXValue;
  final double minXRange;
  final double minYRange;
  final double height;
  final String infoTitle;
  final String infoText;
  final List<String> advice;
  final String? footerText;

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
    this.minXValue,
    this.maxXValue,
    this.minXRange = 6.0,
    this.minYRange = 10.0,
    this.height = 360,
    required this.infoTitle,
    required this.infoText,
    this.advice = const [],
    this.footerText,
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

class _TwoPointerScaleData {
  final Offset focalPoint;
  final double distanceX;
  final double distanceY;

  const _TwoPointerScaleData({
    required this.focalPoint,
    required this.distanceX,
    required this.distanceY,
  });
}


class _TwoPointerScaleGestureRecognizer extends OneSequenceGestureRecognizer {
  void Function(Offset globalFocalPoint, double distanceX, double distanceY)? onStart;
  void Function(Offset globalFocalPoint, double distanceX, double distanceY)? onUpdate;

  VoidCallback? onEnd;

  final Map<int, Offset> _pointers = <int, Offset>{};
  bool _active = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pointers[event.pointer] = event.position;

    if (_pointers.length == 2 && !_active) {
      _active = true;
      resolve(GestureDisposition.accepted);
      final data = _currentData();
      onStart?.call(data.focalPoint, data.distanceX, data.distanceY);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!_pointers.containsKey(event.pointer)) return;

      _pointers[event.pointer] = event.position;

      if (_active && _pointers.length >= 2) {
        final data = _currentData();
        onUpdate?.call(data.focalPoint, data.distanceX, data.distanceY);
      }

      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_pointers.containsKey(event.pointer)) {
        stopTrackingPointer(event.pointer);
        _pointers.remove(event.pointer);
      }

      if (_active && _pointers.length < 2) {
        _active = false;
        onEnd?.call();
      }
    }
  }

  _TwoPointerScaleData _currentData() {
    final values = _pointers.values.take(2).toList(growable: false);

    if (values.length < 2) {
      return const _TwoPointerScaleData(
        focalPoint: Offset.zero,
        distanceX: 1,
        distanceY: 1,
      );
    }

    final focal = Offset(
      (values[0].dx + values[1].dx) / 2,
      (values[0].dy + values[1].dy) / 2,
    );

    final dx = (values[0].dx - values[1].dx).abs();
    final dy = (values[0].dy - values[1].dy).abs();

    return _TwoPointerScaleData(
      focalPoint: focal,
      distanceX: dx <= 1 ? 1 : dx,
      distanceY: dy <= 1 ? 1 : dy,
    );
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();

    if (_active) {
      _active = false;
      onEnd?.call();
    }
  }

  @override
  String get debugDescription => 'two pointer chart scale';
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

  Size _plotSize = Size.zero;
  UnifiedStatsPoint? _selectedPoint;
  final GlobalKey _plotKey = GlobalKey();

  _UnifiedStatsBounds _twoPointerStartBounds = const _UnifiedStatsBounds(
    minX: 0,
    maxX: 1,
    minY: 0,
    maxY: 1,
  );

  Offset _twoPointerStartFocal = Offset.zero;
  double _twoPointerStartDistanceX = 1.0;
  double _twoPointerStartDistanceY = 1.0;
  bool _singleFingerPanActive = false;
  Offset? _singleFingerPanStart;

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

    final rawMinX = widget.points.map((p) => p.x).reduce(math.min);
    final rawMaxX = widget.points.map((p) => p.x).reduce(math.max);
    final rawMinY = widget.points.map((p) => p.y).reduce(math.min);
    final rawMaxY = widget.points.map((p) => p.y).reduce(math.max);

    final minXRaw = widget.minXValue ?? rawMinX;
    final maxXRaw = widget.maxXValue ?? rawMaxX;
    final minYRaw = widget.minYValue ?? rawMinY;
    final maxYRaw = widget.maxYValue ?? rawMaxY;

    final xRangeRaw = (maxXRaw - minXRaw).abs();
    final yRangeRaw = (maxYRaw - minYRaw).abs();

    final effectiveXRange = math.max(xRangeRaw, widget.minXRange);
    final effectiveYRange = math.max(yRangeRaw, widget.minYRange);

    final xCenter = (minXRaw + maxXRaw) / 2;
    final yCenter = (minYRaw + maxYRaw) / 2;

    final hasFixedMinX = widget.minXValue != null;
    final hasFixedMaxX = widget.maxXValue != null;
    final hasFixedMinY = widget.minYValue != null;
    final hasFixedMaxY = widget.maxYValue != null;

    final xPadding = hasFixedMinX && hasFixedMaxX ? 0.0 : effectiveXRange * 0.08;
    final yPadding = hasFixedMinY && hasFixedMaxY ? 0.0 : effectiveYRange * 0.18;

    return _UnifiedStatsBounds(
      minX: hasFixedMinX
          ? minXRaw
          : xCenter - effectiveXRange / 2 - xPadding,
      maxX: hasFixedMaxX
          ? maxXRaw
          : xCenter + effectiveXRange / 2 + xPadding,
      minY: hasFixedMinY
          ? minYRaw
          : yCenter - effectiveYRange / 2 - yPadding,
      maxY: hasFixedMaxY
          ? maxYRaw
          : yCenter + effectiveYRange / 2 + yPadding,
    );
  }

  void _resetZoom() {
    setState(() {
      _dataBounds = _calculateDataBounds();
      _visibleBounds = _dataBounds;
    });
  }


  Offset _plotLocalFromGlobal(Offset globalPosition) {
    final context = _plotKey.currentContext;
    if (context == null) return Offset.zero;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return Offset.zero;

    return renderObject.globalToLocal(globalPosition);
  }

  void _onTwoPointerScaleStart(
      Offset globalFocalPoint,
      double distanceX,
      double distanceY,
      ) {
    if (_plotSize.width <= 0 || _plotSize.height <= 0) return;

    _twoPointerStartBounds = _visibleBounds;
    _twoPointerStartFocal = _plotLocalFromGlobal(globalFocalPoint);
    _twoPointerStartDistanceX = distanceX <= 1 ? 1 : distanceX;
    _twoPointerStartDistanceY = distanceY <= 1 ? 1 : distanceY;
  }

  void _onTwoPointerScaleUpdate(
      Offset globalFocalPoint,
      double distanceX,
      double distanceY,
      ) {
    if (_plotSize.width <= 0 || _plotSize.height <= 0) return;

    final currentFocal = _plotLocalFromGlobal(globalFocalPoint);
    final currentDistanceX = distanceX <= 1 ? 1 : distanceX;
    final currentDistanceY = distanceY <= 1 ? 1 : distanceY;

    final scaleX =
    (currentDistanceX / _twoPointerStartDistanceX).clamp(0.25, 8.0);
    final scaleY =
    (currentDistanceY / _twoPointerStartDistanceY).clamp(0.25, 8.0);

    final startFocalXRatio =
    (_twoPointerStartFocal.dx / _plotSize.width).clamp(0.0, 1.0);
    final startFocalYRatio =
    (_twoPointerStartFocal.dy / _plotSize.height).clamp(0.0, 1.0);

    final focalX = _twoPointerStartBounds.minX +
        _twoPointerStartBounds.xRange * startFocalXRatio;

    final focalY = widget.invertYAxis
        ? _twoPointerStartBounds.minY +
        _twoPointerStartBounds.yRange * startFocalYRatio
        : _twoPointerStartBounds.maxY -
        _twoPointerStartBounds.yRange * startFocalYRatio;


    final nextXRange = (_twoPointerStartBounds.xRange / scaleX)
        .clamp(_dataBounds.xRange / 80, _dataBounds.xRange * 4);

    final nextYRange = (_twoPointerStartBounds.yRange / scaleY)
        .clamp(_dataBounds.yRange / 80, _dataBounds.yRange * 4);

    final focalDelta = currentFocal - _twoPointerStartFocal;

    final panDx = -(focalDelta.dx / _plotSize.width) * nextXRange;
    final panDy = widget.invertYAxis
        ? -(focalDelta.dy / _plotSize.height) * nextYRange
        : (focalDelta.dy / _plotSize.height) * nextYRange;


    final minX = focalX - nextXRange * startFocalXRatio + panDx;
    final maxX = minX + nextXRange;

    final double minY;
    final double maxY;

    if (widget.invertYAxis) {
      minY = focalY - nextYRange * startFocalYRatio + panDy;
      maxY = minY + nextYRange;
    } else {
      maxY = focalY + nextYRange * startFocalYRatio + panDy;
      minY = maxY - nextYRange;
    }
    
    setState(() {
      _visibleBounds = _clampToData(
        _UnifiedStatsBounds(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
        ),
      );
    });
  }

  void _onTwoPointerScaleEnd() {
    _twoPointerStartDistanceX = 1.0;
    _twoPointerStartDistanceY = 1.0;
  }

  void _onSingleFingerPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;

    _singleFingerPanActive = false;
    _singleFingerPanStart = event.localPosition;
  }

  void _onSingleFingerPointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (_plotSize.width <= 0) return;
    if (_singleFingerPanStart == null) return;

    final delta = event.localPosition - _singleFingerPanStart!;

    if (!_singleFingerPanActive) {
      if (delta.dx.abs() < 32) return;

      if (delta.dx.abs() <= delta.dy.abs()) return;

      _singleFingerPanActive = true;
    }

    final dx = -(event.delta.dx / _plotSize.width) * _visibleBounds.xRange;

    setState(() {
      _visibleBounds = _clampToData(
        _UnifiedStatsBounds(
          minX: _visibleBounds.minX + dx,
          maxX: _visibleBounds.maxX + dx,
          minY: _visibleBounds.minY,
          maxY: _visibleBounds.maxY,
        ),
      );
    });
  }

  void _onSingleFingerPointerEnd(PointerEvent event) {
    _singleFingerPanActive = false;
    _singleFingerPanStart = null;
  }


  void _selectNearestPoint(Offset local) {
    if (_plotSize.width <= 0 || _plotSize.height <= 0 || widget.points.isEmpty) {
      return;
    }
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final hitRadius = isCompact ? 90.0 : 72.0;


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
    if (!_isCtrlOrMetaPressed()) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final local = event.localPosition;
      final focalXRatio = (local.dx / _plotSize.width).clamp(0.0, 1.0);
      final focalYRatio = (local.dy / _plotSize.height).clamp(0.0, 1.0);
      final factor = _wheelZoomFactor(event);

      _zoomX(factor, focalXRatio);
      _zoomY(factor, focalYRatio);
    });
  }

  bool _isCtrlOrMetaPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;

    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  double _wheelZoomFactor(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;

    return delta < 0 ? 0.86 : 1.16;
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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return UnifiedStatsCard(
      title: widget.title,
      subtitle: widget.subtitle,
      info: UnifiedStatsInfoData(
        title: widget.infoTitle,
        text: widget.infoText,
        advice: widget.advice,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.points.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Text(
                'Nessun dato disponibile.',
                style: t.bodySmall(t.textMuted),
              ),
            )
          else ...[
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
                          onPointerDown: _onSingleFingerPointerDown,
                          onPointerMove: _onSingleFingerPointerMove,
                          onPointerUp: _onSingleFingerPointerEnd,
                          onPointerCancel: _onSingleFingerPointerEnd,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            excludeFromSemantics: true,
                            onTapDown: (details) {
                              if (_singleFingerPanActive) return;
                              _selectNearestPoint(details.localPosition);
                            },
                            onDoubleTap: _resetZoom,
                            child: RawGestureDetector(
                              behavior: HitTestBehavior.opaque,
                              gestures: <Type, GestureRecognizerFactory>{
                                _TwoPointerScaleGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                    _TwoPointerScaleGestureRecognizer>(
                                      () => _TwoPointerScaleGestureRecognizer(),
                                      (recognizer) {
                                    recognizer
                                      ..onStart = _onTwoPointerScaleStart
                                      ..onUpdate = _onTwoPointerScaleUpdate
                                      ..onEnd = _onTwoPointerScaleEnd;
                                  },
                                ),
                              },
                              child: RepaintBoundary(
                                key: _plotKey,
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
          ],
          if (widget.footerText != null && widget.footerText!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.analytics_rounded, color: t.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.footerText!,
                      style: t.bodySmall(t.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          //_UnifiedStatsFakeTable(points: widget.points),
        ],
      ),
    );
  }
}
class _UnifiedStatsInfoSheet extends StatelessWidget {
  final String title;
  final String text;
  final List<String> advice;

  const _UnifiedStatsInfoSheet({
    required this.title,
    required this.text,
    required this.advice,
  });

  static void show({
    required BuildContext context,
    required String title,
    required String text,
    required List<String> advice,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) {
        return _UnifiedStatsInfoSheet(
          title: title,
          text: text,
          advice: advice,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.34,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.overlay,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.16),
                      borderRadius: AppTokens.r12,
                      border: Border.all(color: t.accent.withOpacity(0.34)),
                    ),
                    child: Icon(Icons.info_rounded, color: t.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: t.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: AppTokens.r16,
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 14,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (advice.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('CONSIGLI', style: t.labelCaps(t.textMuted)),
                const SizedBox(height: 10),
                for (final item in advice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: AppTokens.r12,
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, color: t.green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                height: 1.38,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
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

  const _UnifiedStatsHeader({
    required this.title,
    required this.subtitle,
    required this.onInfo,
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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final maxCount = buckets.isEmpty
        ? 1
        : buckets.map((e) => e.count).reduce(math.max).clamp(1, 999999);

    return UnifiedStatsCard(
      title: title,
      subtitle: subtitle,
      info: UnifiedStatsInfoData(
        title: infoTitle,
        text: infoText,
        advice: advice,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
class UnifiedStatsTowerSegment {
  final String label;
  final double value;
  final Color color;

  const UnifiedStatsTowerSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class UnifiedStatsTowerValue {
  final String label;
  final double value;
  final String topLabel;
  final String? subTopLabel;
  final Color? color;
  final List<UnifiedStatsTowerSegment> segments;

  const UnifiedStatsTowerValue({
    required this.label,
    required this.value,
    required this.topLabel,
    this.subTopLabel,
    this.color,
    this.segments = const [],
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
  final List<(String, Color)>? customLegend;
  final String? footerText;
  final bool showTargetLines;

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
    this.customLegend,
    this.footerText,
    this.showTargetLines = false,
  });

  @override
  State<UnifiedStatsTowerChart> createState() => _UnifiedStatsTowerChartState();
}

class _UnifiedStatsTowerChartState extends State<UnifiedStatsTowerChart> {

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

    return UnifiedStatsCard(
      title: widget.title,
      subtitle: widget.subtitle,
      info: UnifiedStatsInfoData(
        title: widget.infoTitle,
        text: widget.infoText,
        advice: widget.advice,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      customLegend: widget.customLegend,
                      showTargetLines: widget.showTargetLines,
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
                    widget.footerText ??
                        'Confronta le barre per categoria e usa Info per leggere il significato del dato.',
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
  final List<(String, Color)>? customLegend;
  final bool showTargetLines;

  const _UnifiedStatsTowerPainter({
    required this.groups,
    required this.tokens,
    required this.yAxisLabel,
    this.customLegend,
    required this.showTargetLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 18.0;
    const top = 28.0;
    const bottom = 62.0;

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

    if (showTargetLines) {
      final targetLines = [
        (15.0, '15'),
        (18.0, '18'),
        (21.0, '21'),
        (24.0, '24'),
      ];

      for (final (target, label) in targetLines) {
        if (target > yMax) continue;

        final y = chart.bottom - ((target / yMax) * chart.height);

        canvas.drawLine(
          Offset(chart.left, y),
          Offset(chart.right, y),
          Paint()
            ..color = tokens.textMuted.withOpacity(0.18)
            ..strokeWidth = 1,
        );

        _drawText(
          canvas,
          '${label}d',
          Offset(chart.right - 28, y - 8),
          tokens.textMuted.withOpacity(0.6),
          9,
        );
      }
    }


    final compactGroupWidth = 84.0;
    final totalWidth = groups.length * compactGroupWidth;
    final horizontalOffset =
    totalWidth < chart.width ? (chart.width - totalWidth) / 6 : 0;

    final groupWidth = compactGroupWidth;

    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      final visibleValues = group.values.where((value) => value.value > 0).toList();
      if (visibleValues.isEmpty) continue;

      final centerX =
          chart.left + horizontalOffset + groupWidth * i + groupWidth / 2;

      final barCount = visibleValues.length;
      final barWidth = barCount <= 1
          ? math.min(groupWidth * 0.42, 34.0)
          : math.min((groupWidth - 18) / barCount, 28.0);

      final totalBarsWidth = barWidth * barCount + 6 * (barCount - 1);
      final startX = centerX - totalBarsWidth / 2;

      for (int j = 0; j < visibleValues.length; j++) {
        final value = visibleValues[j];
        final x = startX + j * (barWidth + 6);
        final barHeight = (value.value / yMax) * chart.height;
        final rect = Rect.fromLTWH(
          x,
          chart.bottom - barHeight,
          barWidth,
          barHeight,
        );

        if (value.segments.isEmpty) {
          final color = value.color ?? tokens.accent;

          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..color = color
              ..style = PaintingStyle.fill,
          );
        } else {
          double segmentBottom = chart.bottom;

          for (final segment in value.segments.where((s) => s.value > 0)) {
            final segmentHeight = (segment.value / yMax) * chart.height;

            final segmentRect = Rect.fromLTWH(
              x,
              segmentBottom - segmentHeight,
              barWidth,
              segmentHeight,
            );

            canvas.drawRRect(
              RRect.fromRectAndRadius(
                segmentRect,
                const Radius.circular(4),
              ),
              Paint()
                ..color = segment.color
                ..style = PaintingStyle.fill,
            );

            if (segmentHeight > 22) {
              _drawCenteredText(
                canvas,
                segment.value.toStringAsFixed(1),
                Offset(
                  segmentRect.center.dx,
                  segmentRect.center.dy - 6,
                ),
                Colors.white.withOpacity(0.92),
                9,
              );
            }

            segmentBottom -= segmentHeight;
          }
        }

        final labelColor = value.color ?? tokens.accent;

        _drawCenteredText(
          canvas,
          value.topLabel,
          Offset(rect.center.dx, rect.top - 28),
          labelColor,
          10,
        );

        final subTopLabel = value.subTopLabel;
        if (subTopLabel != null && subTopLabel.isNotEmpty) {
          _drawCenteredText(
            canvas,
            subTopLabel,
            Offset(rect.center.dx, rect.top - 15),
            labelColor,
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
    final items = customLegend;
    if (items == null || items.isEmpty) return;

    double x = chart.left;
    double y = chart.bottom + 42;

    for (final (label, color) in items) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 12, 12),
          const Radius.circular(3),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      _drawText(
        canvas,
        label,
        Offset(x + 18, y - 1),
        tokens.textMuted,
        10,
      );

      x += 62;
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
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.customLegend != customLegend ||
        oldDelegate.showTargetLines != showTargetLines;
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