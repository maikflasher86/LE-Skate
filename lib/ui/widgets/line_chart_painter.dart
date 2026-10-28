import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ChartSeries {
  const ChartSeries({
    required this.values,
    required this.color,
    this.label = '',
  });

  final List<double> values;
  final Color color;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ChartSeries &&
      listEquals(values, other.values) &&
      color == other.color &&
      label == other.label;

  @override
  int get hashCode => Object.hash(Object.hashAll(values), color, label);
}

/// Combined min/max of all finite values. Flat data is extended upwards so
/// the axis starts at the data value; no data yields (0, 1).
(double min, double max) chartRange(List<ChartSeries> series) {
  final all = [for (final s in series) ...s.values.where((v) => v.isFinite)];
  if (all.isEmpty) return (0, 1);
  var lo = all.first;
  var hi = all.first;
  for (final v in all) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if ((hi - lo).abs() < 0.001) return (lo, lo + 1);
  return (lo, hi);
}

/// Draws one or more lines on a shared grid. The first series is drawn on
/// top in full colour, further series behind it slightly translucent.
class LineChartPainter extends CustomPainter {
  const LineChartPainter({
    required this.series,
    required this.minValue,
    required this.maxValue,
    this.xGridIndices = const [],
  });

  final List<ChartSeries> series;
  final double minValue;
  final double maxValue;
  final List<int> xGridIndices;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final length = series.first.values.length;
    if (length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // Horizontal grid lines at 25 %, 50 %, 75 %
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines at the x-label positions
    for (final idx in xGridIndices) {
      if (idx > 0 && idx < length - 1) {
        final x = size.width * idx / (length - 1);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;

    for (var i = series.length - 1; i >= 0; i--) {
      final s = series[i];
      _drawSeries(
        canvas,
        size,
        s.values,
        i == 0 ? s.color : s.color.withValues(alpha: 0.85),
        range,
      );
    }
  }

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
  bool shouldRepaint(covariant LineChartPainter old) =>
      !listEquals(series, old.series) ||
      minValue != old.minValue ||
      maxValue != old.maxValue ||
      !listEquals(xGridIndices, old.xGridIndices);
}
