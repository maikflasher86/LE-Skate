import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inliner2/ui/widgets/dual_line_chart_painter.dart';

const double _yAxisWidth = 46.0;
const double _xAxisHeight = 30.0;
const double _chartHeight = 140.0;
const double _pixelsPerPoint = 24.0;

/// Chart with two overlaid lines (e.g. Open-Meteo + DWD).
class DualMiniLineChart extends StatelessWidget {
  const DualMiniLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.series1,
    required this.series1Label,
    required this.series1Color,
    required this.series2,
    required this.series2Label,
    required this.series2Color,
    this.scrollController,
  });

  final String title;
  final String unit;

  /// Optional external controller to synchronize multiple charts horizontally
  /// (e.g. precipitation + precipitation probability).
  final ScrollController? scrollController;

  /// Time stamps of the X-axis (from series 1).
  final List<DateTime> times;

  final List<double> series1;
  final String series1Label;
  final Color series1Color;

  /// Can be empty – will not be drawn in that case.
  final List<double> series2;
  final String series2Label;
  final Color series2Color;

  int _xInterval(int length) {
    if (length <= 12) return 2;
    if (length <= 24) return 3;
    if (length <= 48) return 6;
    return 12;
  }

  String _xLabel(DateTime t) {
    if (t.hour == 0 && t.minute == 0) {
      return '${DateFormat('dd.MM.').format(t)}\n${DateFormat('HH:mm').format(t)}';
    }
    return DateFormat('HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (times.length < 2 || series1.length < 2) return const SizedBox.shrink();

    final (minVal, maxVal) = dualRange(series1, series2);
    final range = (maxVal - minVal).abs() < 0.001 ? 1.0 : maxVal - minVal;

    // Y-axis labels
    final yLabels = List.generate(
      5,
      (i) => (maxVal - (i / 4) * range).toStringAsFixed(1),
    );

    final interval = _xInterval(times.length);
    final xLabelIndices = <int>[
      for (var i = 0; i < times.length; i++)
        if (i % interval == 0 || i == times.length - 1) i,
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
          // Title + Legend
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title ($unit)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              _LegendDot(color: series1Color, label: series1Label),
              const SizedBox(width: 8),
              if (series2.isNotEmpty)
                _LegendDot(color: series2Color, label: series2Label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis (fixed)
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
                              (l) => Text(
                                l,
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
              // Scrollable chart
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = math.max(
                      times.length * _pixelsPerPoint,
                      constraints.maxWidth,
                    );
                    return SingleChildScrollView(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: Column(
                          children: [
                            SizedBox(
                              height: _chartHeight,
                              child: CustomPaint(
                                painter: DualLineChartPainter(
                                  values1: series1,
                                  values2: series2,
                                  color1: series1Color,
                                  color2: series2Color,
                                  minValue: minVal,
                                  maxValue: maxVal,
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
                                  final rawX = times.length > 1
                                      ? chartWidth * i / (times.length - 1)
                                      : 0.0;
                                  final left = i == times.length - 1
                                      ? chartWidth - 40
                                      : (rawX - 20).clamp(0.0, chartWidth - 40);
                                  return Positioned(
                                    left: left,
                                    top: 4,
                                    child: SizedBox(
                                      width: 40,
                                      child: Text(
                                        _xLabel(times[i]),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }
}
