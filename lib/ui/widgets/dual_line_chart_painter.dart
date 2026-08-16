import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws two lines on a shared canvas.
class DualLineChartPainter extends CustomPainter {
  const DualLineChartPainter({
    required this.values1,
    required this.values2,
    required this.color1,
    required this.color2,
    required this.minValue,
    required this.maxValue,
    this.xGridIndices = const [],
  });

  final List<double> values1;

  /// Can be empty – will not be drawn in that case.
  final List<double> values2;
  final Color color1;
  final Color color2;
  final double minValue;
  final double maxValue;
  final List<int> xGridIndices;

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
    double range,
  ) {
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height).clamp(0, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values1.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines
    for (final idx in xGridIndices) {
      if (idx > 0 && idx < values1.length - 1) {
        final x = size.width * idx / (values1.length - 1);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;

    // Series 2 (DWD) dashed in background
    if (values2.isNotEmpty) {
      _drawSeries(canvas, size, values2, color2.withValues(alpha: 0.85), range);
    }
    // Series 1 (Open-Meteo) solid in foreground
    _drawSeries(canvas, size, values1, color1, range);
  }

  @override
  bool shouldRepaint(covariant DualLineChartPainter old) =>
      values1 != old.values1 ||
      values2 != old.values2 ||
      minValue != old.minValue ||
      maxValue != old.maxValue;
}

/// Calculates the combined min/max value of both series.
(double min, double max) dualRange(List<double> s1, List<double> s2) {
  final all = [...s1, ...s2.where((v) => v.isFinite)];
  if (all.isEmpty) return (0, 1);
  return (all.reduce(math.min), all.reduce(math.max));
}
