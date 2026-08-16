import 'package:flutter/material.dart';

class LineChartPainter extends CustomPainter {
  const LineChartPainter({
    required this.values,
    required this.color,
    required this.minValue,
    required this.maxValue,
    this.xGridIndices = const [],
  });

  final List<double> values;
  final Color color;
  final double minValue;
  final double maxValue;
  final List<int> xGridIndices;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // Horizontale Rasterlinien bei 25 %, 50 %, 75 %
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertikale Rasterlinien an den X-Label-Positionen
    for (final idx in xGridIndices) {
      if (idx > 0 && idx < values.length - 1) {
        final x = size.width * idx / (values.length - 1);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;
    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return values != oldDelegate.values ||
        color != oldDelegate.color ||
        minValue != oldDelegate.minValue ||
        maxValue != oldDelegate.maxValue ||
        xGridIndices != oldDelegate.xGridIndices;
  }
}
