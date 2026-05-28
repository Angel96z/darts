/// FILE: features/bootstrap/presentation/dart_boot_splash.dart
/// TARGET: Splash screen con animazione del tabellone freccette durante il bootstrap.
/// LOGIC GOAL: Mostrare progresso, step di caricamento e feedback visivo/errori.
/// REACTION: UI reattiva a stato di caricamento, errore o completamento.
/// ERROR STRATEGY: Mostra errore e pulsante retry.
/// ANTI-REGRESSION: Mantenere animazioni, step doppio/triplo/settore/bull, glow, numeri e colori.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app_theme.dart';

// ----- DOMAIN LAYER (modello puro) -----

@immutable
class BootState {
  final double progress;
  final String label;
  final Object? error;
  final VoidCallback? onRetry;

  const BootState({
    required this.progress,
    required this.label,
    this.error,
    this.onRetry,
  });

  bool get hasError => error != null;
  bool get isComplete => progress >= 1.0 && !hasError;
  double get clampedProgress => progress.clamp(0.0, 1.0);

  BootState copyWith({
    double? progress,
    String? label,
    Object? error,
    VoidCallback? onRetry,
  }) {
    return BootState(
      progress: progress ?? this.progress,
      label: label ?? this.label,
      error: error ?? this.error,
      onRetry: onRetry ?? this.onRetry,
    );
  }
}

// ----- DATA LAYER (logica di calcolo step e valori) -----

class _DartboardStepLogic {
  static const List<int> boardNumbers = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];

  static const List<int> doublesOrder = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
  ];

  static const List<int> triplesOrder = doublesOrder;

  static const List<int> singlesOrder = [
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
    20,
  ];

  static const int totalSteps = 62;

  static int stepFromProgress(double progress) {
    return (progress * totalSteps).round().clamp(0, totalSteps);
  }

  static String prefix(int step, bool hasError) {
    if (hasError) return '';
    if (step == 0 || step > 60) return '';
    if (step <= 20) return 'DOPPIO';
    if (step <= 40) return 'TRIPLO';
    return 'SETTORE';
  }

  static String value(int step, bool hasError) {
    if (hasError) return 'CHECK FALLITO';
    if (step == 0) return 'CARICAMENTO...';
    if (step <= 20) return '${doublesOrder[step - 1]}';
    if (step <= 40) return '${triplesOrder[step - 21]}';
    if (step <= 60) return '${singlesOrder[step - 41]}';
    if (step == 61) return 'MEZZO BULL';
    return 'BULL!';
  }

  static Color barColor(int step, bool hasError) {
    if (hasError) return const Color(0xFFD62B2B);
    if (step <= 20) return const Color(0xFFD62B2B);
    if (step <= 40) return const Color(0xFF009A44);
    if (step <= 60) return const Color(0xFFF0D870);
    return const Color(0xFFFFD700);
  }

  static bool isBullPhase(int step) => step >= 61;
}

// ----- PRESENTATION LAYER (UI pura) -----

class DartBootSplash extends StatefulWidget {
  final String appName;
  final BootState state;

  const DartBootSplash({super.key, required this.appName, required this.state});

  @override
  State<DartBootSplash> createState() => _DartBootSplashState();
}

class _DartBootSplashState extends State<DartBootSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  double _glowValue = 0.0;
  int _lastStep = 0;

  int get _step =>
      _DartboardStepLogic.stepFromProgress(widget.state.clampedProgress);

  @override
  void initState() {
    super.initState();
    _lastStep = _step;
    _glowCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..addListener(() {
          if (mounted) setState(() => _glowValue = 1.0 - _glowCtrl.value);
        });
  }

  @override
  void didUpdateWidget(covariant DartBootSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_step != _lastStep) {
      _lastStep = _step;
      _glowCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pct = (widget.state.clampedProgress * 100).round();
    final hasError = widget.state.hasError;
    final step = _step;

    final prefix = _DartboardStepLogic.prefix(step, hasError);
    final value = _DartboardStepLogic.value(step, hasError);
    final barColor = _DartboardStepLogic.barColor(step, hasError);
    final isBullPhase = _DartboardStepLogic.isBullPhase(step);

    return Scaffold(
      backgroundColor: const Color(0xFF090910),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: CustomPaint(
                size: const Size(300, 300),
                painter: _DartboardPainter(
                  step: step,
                  glowValue: _glowValue,
                  boardNumberStyle: AppTokens.scoreSmallStyle.copyWith(
                    color: Colors.white.withOpacity(0.90),
                  ),
                  boardNumbers: _DartboardStepLogic.boardNumbers,
                  doublesOrder: _DartboardStepLogic.doublesOrder,
                  triplesOrder: _DartboardStepLogic.triplesOrder,
                  singlesOrder: _DartboardStepLogic.singlesOrder,
                ),
              ),
            ),
            const SizedBox(height: 34),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Column(
                key: ValueKey('${step}_${hasError}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (step > 0 && step <= 60 && !hasError)
                    Text(
                      prefix,
                      style: tt.labelSmall?.copyWith(
                        color: Colors.white.withOpacity(0.38),
                      ),
                    ),
                  const SizedBox(height: 2),
                  MediaQuery(
                    data: AppTokens.clampScore(context),
                    child: SizedBox(
                      height: isBullPhase ? 28 : 24,
                      child: FittedBox(
                        fit: BoxFit.fitHeight,
                        child: Text(
                          value,
                          style: AppTokens.scoreStyle.copyWith(
                            color: isBullPhase
                                ? const Color(0xFFFFD700)
                                : Colors.white,
                            shadows: isBullPhase
                                ? const [
                                    Shadow(
                                      color: Color(0xFFFFD700),
                                      blurRadius: 20,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.state.label,
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.42),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: widget.state.clampedProgress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$pct%',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withOpacity(0.40),
                    ),
                  ),
                ],
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.state.onRetry,
                child: Text(
                  'RIPROVA',
                  style: tt.titleSmall?.copyWith(color: Color(0xFFFFD700)),
                ),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 42),
              child: SizedBox(
                height: 20,
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: Text(
                    widget.appName.toUpperCase(),
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- CUSTOM PAINTER (logica di disegno pura) -----

class _DartboardPainter extends CustomPainter {
  final int step;
  final double glowValue;
  final TextStyle boardNumberStyle;
  final List<int> boardNumbers;
  final List<int> doublesOrder;
  final List<int> triplesOrder;
  final List<int> singlesOrder;

  static const double _kDoubleOuter = 1.000;
  static const double _kDoubleInner = 0.953;
  static const double _kTripleOuter = 0.629;
  static const double _kTripleInner = 0.582;
  static const double _kBullOuter = 0.094;
  static const double _kBullseye = 0.038;
  static const double _kSweep = 18 * math.pi / 180;

  const _DartboardPainter({
    required this.step,
    required this.glowValue,
    required this.boardNumberStyle,
    required this.boardNumbers,
    required this.doublesOrder,
    required this.triplesOrder,
    required this.singlesOrder,
  });

  int _bi(int number) => boardNumbers.indexOf(number);
  double _sa(int boardIndex) => (boardIndex * 18 - 9 - 90) * math.pi / 180;

  Color _colorDT(int bi) =>
      bi.isOdd ? const Color(0xFF009A44) : const Color(0xFFD62B2B);

  Color _colorSingle(int bi) =>
      bi.isOdd ? const Color(0xFFEEDFB0) : const Color(0xFF181818);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 * 0.88;

    canvas.drawCircle(c, R * 1.13, Paint()..color = const Color(0xFF0B0B0B));
    canvas.drawCircle(
      c,
      R * 1.095,
      Paint()
        ..color = const Color(0xFF1E1E28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.06,
    );

    final ghost = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.045);

    for (int i = 0; i < 20; i++) {
      final sa = _sa(i);
      _arc(canvas, c, R * _kDoubleInner, R * _kDoubleOuter, sa, _kSweep, ghost);
      _arc(canvas, c, R * _kTripleInner, R * _kTripleOuter, sa, _kSweep, ghost);
      _arc(canvas, c, R * _kTripleOuter, R * _kDoubleInner, sa, _kSweep, ghost);
      _arc(canvas, c, R * _kBullOuter, R * _kTripleInner, sa, _kSweep, ghost);
    }
    canvas.drawCircle(c, R * _kBullOuter, ghost);

    final dDone = step.clamp(0, 20);
    for (int d = 0; d < dDone; d++) {
      final bi = _bi(doublesOrder[d]);
      final gv = d == dDone - 1 && step <= 20 ? glowValue : 0.0;
      _seg(
        canvas,
        c,
        R * _kDoubleInner,
        R * _kDoubleOuter,
        _sa(bi),
        _kSweep,
        _colorDT(bi),
        gv,
      );
    }

    final tDone = (step - 20).clamp(0, 20);
    for (int t = 0; t < tDone; t++) {
      final bi = _bi(triplesOrder[t]);
      final gv = t == tDone - 1 && step > 20 && step <= 40 ? glowValue : 0.0;
      _seg(
        canvas,
        c,
        R * _kTripleInner,
        R * _kTripleOuter,
        _sa(bi),
        _kSweep,
        _colorDT(bi),
        gv,
      );
    }

    final sDone = (step - 40).clamp(0, 20);
    for (int s = 0; s < sDone; s++) {
      final bi = _bi(singlesOrder[s]);
      final gv = s == sDone - 1 && step > 40 && step <= 60 ? glowValue : 0.0;
      final col = _colorSingle(bi);
      _seg(
        canvas,
        c,
        R * _kBullOuter,
        R * _kTripleInner,
        _sa(bi),
        _kSweep,
        col,
        gv,
      );
      _seg(
        canvas,
        c,
        R * _kTripleOuter,
        R * _kDoubleInner,
        _sa(bi),
        _kSweep,
        col,
        gv,
      );
    }

    if (step >= 61) {
      _circle(
        canvas,
        c,
        R * _kBullOuter,
        const Color(0xFF009A44),
        step == 61 ? glowValue : 0.0,
      );
    }
    if (step >= 62) {
      _circle(
        canvas,
        c,
        R * _kBullseye,
        const Color(0xFFD62B2B),
        step == 62 ? glowValue : 0.0,
      );
    }

    _drawWire(canvas, c, R);
    _drawNumbers(canvas, c, R);
  }

  void _drawWire(Canvas canvas, Offset c, double R) {
    final wire = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = 0.85
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 20; i++) {
      final a = _sa(i);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (R * _kBullOuter),
        c + Offset(math.cos(a), math.sin(a)) * (R * _kDoubleOuter),
        wire,
      );
    }

    for (final r in [
      _kDoubleOuter,
      _kDoubleInner,
      _kTripleOuter,
      _kTripleInner,
      _kBullOuter,
      _kBullseye,
    ]) {
      canvas.drawCircle(c, R * r, wire);
    }
  }

  void _drawNumbers(Canvas canvas, Offset c, double R) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final numR = R * _kDoubleOuter + R * 0.10;

    for (int i = 0; i < 20; i++) {
      final a = (i * 18 - 90) * math.pi / 180;
      final pos = c + Offset(math.cos(a), math.sin(a)) * numR;

      tp.text = TextSpan(
        text: boardNumbers[i].toString(),
        style: boardNumberStyle,
      );
      tp.textScaler = TextScaler.linear(
        (R * 0.112) / (boardNumberStyle.fontSize ?? 18),
      );

      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _seg(
    Canvas canvas,
    Offset c,
    double r1,
    double r2,
    double sa,
    double sw,
    Color col,
    double gv,
  ) {
    final path = _buildPath(c, r1, r2, sa, sw);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = col,
    );
    if (gv > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(gv * 0.52)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * gv),
      );
    }
  }

  void _circle(Canvas canvas, Offset c, double r, Color col, double gv) {
    canvas.drawCircle(c, r, Paint()..color = col);
    if (gv > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withOpacity(gv * 0.60)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * gv),
      );
    }
  }

  void _arc(
    Canvas canvas,
    Offset c,
    double r1,
    double r2,
    double sa,
    double sw,
    Paint p,
  ) {
    canvas.drawPath(_buildPath(c, r1, r2, sa, sw), p);
  }

  Path _buildPath(Offset c, double r1, double r2, double sa, double sw) {
    return Path()
      ..moveTo(c.dx + r1 * math.cos(sa), c.dy + r1 * math.sin(sa))
      ..lineTo(c.dx + r2 * math.cos(sa), c.dy + r2 * math.sin(sa))
      ..arcTo(Rect.fromCircle(center: c, radius: r2), sa, sw, false)
      ..lineTo(c.dx + r1 * math.cos(sa + sw), c.dy + r1 * math.sin(sa + sw))
      ..arcTo(Rect.fromCircle(center: c, radius: r1), sa + sw, -sw, false)
      ..close();
  }

  @override
  bool shouldRepaint(_DartboardPainter oldDelegate) {
    return oldDelegate.step != step || oldDelegate.glowValue != glowValue;
  }
}
