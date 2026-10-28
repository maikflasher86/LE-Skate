import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/line_chart_painter.dart';
import 'package:intl/intl.dart';

const double _yAxisWidth = 46.0;
const double _xAxisHeight = 30.0;
const double _chartHeight = 140.0;
const double _pixelsPerPoint = 24.0;

/// Horizontally scrollable line chart with a fixed y-axis for one or more
/// [series] sharing the x-axis [times].
///
/// Without legend the title shows the latest value of the first series;
/// with [showLegend] it shows only the unit, followed by the legend.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.series,
    this.scrollController,
    this.showLegend = false,
  });

  final String title;
  final String unit;
  final List<DateTime> times;
  final List<ChartSeries> series;

  /// Optional external controller to synchronize multiple charts horizontally.
  final ScrollController? scrollController;
  final bool showLegend;

  /// Interval (number of data points) between two x-axis time marks.
  int _xInterval(int length) {
    if (length <= 12) return 2;
    if (length <= 24) return 3;
    if (length <= 48) return 6;
    return 12;
  }

  /// Label for a time point – at midnight includes the date.
  String _xLabel(DateTime t) {
    if (t.hour == 0 && t.minute == 0) {
      return '${DateFormat('dd.MM.').format(t)}\n${DateFormat('HH:mm').format(t)}';
    }
    return DateFormat('HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (times.length < 2 || series.isEmpty || series.first.values.length < 2) {
      return const SizedBox.shrink();
    }

    final (minValue, maxValue) = chartRange(series);
    final range = maxValue - minValue;

    // Y-axis: 5 labels from top (max) to bottom (min)
    final yLabels = List.generate(
      5,
      (i) => (maxValue - (i / 4) * range).toStringAsFixed(1),
    );

    final interval = _xInterval(times.length);
    final xLabelIndices = <int>[
      for (var i = 0; i < times.length; i++)
        if (i % interval == 0 || i == times.length - 1) i,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(borderColor: Colors.white24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
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
                        children: [
                          for (final label in yLabels)
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                        ],
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
                      times.length * _pixelsPerPoint,
                      constraints.maxWidth,
                    );
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                        },
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: Column(
                            children: [
                              SizedBox(
                                height: _chartHeight,
                                child: CustomPaint(
                                  painter: LineChartPainter(
                                    series: series,
                                    minValue: minValue,
                                    maxValue: maxValue,
                                    xGridIndices: xLabelIndices,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              _buildXLabels(chartWidth, xLabelIndices),
                            ],
                          ),
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

  Widget _buildTitle() {
    if (!showLegend) {
      return Text(
        '$title (${series.first.values.last.toStringAsFixed(1)} $unit)',
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            '$title ($unit)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        for (var i = 0; i < series.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          if (series[i].values.isNotEmpty)
            _LegendDot(color: series[i].color, label: series[i].label),
        ],
      ],
    );
  }

  Widget _buildXLabels(double chartWidth, List<int> xLabelIndices) {
    return SizedBox(
      height: _xAxisHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final i in xLabelIndices)
            Positioned(
              left: i == times.length - 1
                  ? chartWidth - 40
                  : (chartWidth * i / (times.length - 1) - 20).clamp(
                      0.0,
                      chartWidth - 40,
                    ),
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
