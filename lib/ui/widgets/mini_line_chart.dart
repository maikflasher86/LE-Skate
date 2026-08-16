import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/ui/widgets/line_chart_painter.dart';

const double _yAxisWidth = 46.0;
const double _xAxisHeight = 30.0;
const double _chartHeight = 140.0;
const double _pixelsPerPoint = 24.0;

class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.title,
    required this.color,
    required this.unit,
    required this.points,
    required this.selector,
  });

  final String title;
  final Color color;
  final String unit;
  final List<HourlyPoint> points;
  final double Function(HourlyPoint point) selector;

  /// Interval (number of data points) between two X-axis time marks
  int _xInterval(int length) {
    if (length <= 12) return 2;
    if (length <= 24) return 3;
    if (length <= 48) return 6;
    return 12;
  }

  /// Label for a time point – at midnight includes the date
  String _xLabel(DateTime t) {
    if (t.hour == 0 && t.minute == 0) {
      return '${DateFormat('dd.MM.').format(t)}\n${DateFormat('HH:mm').format(t)}';
    }
    return DateFormat('HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final values = points.map(selector).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;

    // Y-axis: 5 labels from top (max) to bottom (min)
    final yLabels = List.generate(
      5,
      (i) => (maxValue - (i / 4) * range).toStringAsFixed(1),
    );

    final interval = _xInterval(points.length);

    // Indices where X-axis time marks should appear
    final xLabelIndices = <int>[
      for (var i = 0; i < points.length; i++)
        if (i % interval == 0 || i == points.length - 1) i,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${values.last.toStringAsFixed(1)} $unit)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Y-axis (fixed, does not scroll) ──
              SizedBox(
                width: _yAxisWidth,
                child: Column(
                  children: [
                    SizedBox(
                      height: _chartHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: yLabels
                            .map(
                              (label) => Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: _xAxisHeight),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // ── Scrollable chart area ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = math.max(
                      points.length * _pixelsPerPoint,
                      constraints.maxWidth,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: Column(
                          children: [
                            // Chart
                            SizedBox(
                              height: _chartHeight,
                              child: CustomPaint(
                                painter: LineChartPainter(
                                  values: values,
                                  color: color,
                                  minValue: minValue,
                                  maxValue: maxValue,
                                  xGridIndices: xLabelIndices,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            // X-axis labels
                            SizedBox(
                              height: _xAxisHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: xLabelIndices.map((i) {
                                  final double rawX = points.length > 1
                                      ? chartWidth * i / (points.length - 1)
                                      : 0;
                                  final double left = i == points.length - 1
                                      ? chartWidth - 40
                                      : (rawX - 20).clamp(0.0, chartWidth - 40);
                                  return Positioned(
                                    left: left,
                                    top: 4,
                                    child: SizedBox(
                                      width: 40,
                                      child: Text(
                                        _xLabel(points[i].time),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
