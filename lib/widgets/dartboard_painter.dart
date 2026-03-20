import 'dart:math';
import 'package:flutter/material.dart';

import '../logic/dart_throw_logic.dart';

class DartboardPainter extends CustomPainter {
  final List<DartThrow> throws;

  DartboardPainter(this.throws);

  static const Color throwColor = Color(0xFF1976D2);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = size.width / 2;

    final throwFillPaint = Paint()
      ..color = throwColor
      ..style = PaintingStyle.fill;

    final throwStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, boardRadius * 0.0045);

    for (final t in throws) {
      final radius = max(3.0, boardRadius * 0.012);
      canvas.drawCircle(t.position, radius, throwFillPaint);
      canvas.drawCircle(t.position, radius, throwStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant DartboardPainter oldDelegate) {
    return oldDelegate.throws != throws;
  }
}