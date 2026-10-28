import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/ui/widgets/line_chart.dart';
import 'package:inliner2/ui/widgets/line_chart_painter.dart';

List<DateTime> _times(int count) => [
  for (var i = 0; i < count; i++) DateTime(2026, 7, 5).add(Duration(hours: i)),
];

Future<void> _pump(WidgetTester tester, Widget chart) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: chart)),
    ),
  );
  await tester.pump();
}

void main() {
  group('LineChart (single series)', () {
    LineChart chart(int count, {bool flat = false}) => LineChart(
      title: 'Temperatur',
      unit: '°C',
      times: _times(count),
      series: [
        ChartSeries(
          values: [
            for (var i = 0; i < count; i++) flat ? 15 : 10 + (i % 7).toDouble(),
          ],
          color: Colors.cyan,
        ),
      ],
    );

    for (final count in [2, 13, 50]) {
      testWidgets('renders $count points', (tester) async {
        await _pump(tester, chart(count));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Temperatur'), findsOneWidget);
      });
    }

    testWidgets('renders a flat series with the chartRange y-axis', (
      tester,
    ) async {
      await _pump(tester, chart(13, flat: true));
      expect(tester.takeException(), isNull);
      expect(find.text('Temperatur (15.0 °C)'), findsOneWidget);
      // Flat data: axis runs from the value up to value + 1.
      expect(find.text('16.0'), findsOneWidget);
      expect(find.text('15.0'), findsOneWidget);
    });

    testWidgets('renders nothing for fewer than two points', (tester) async {
      await _pump(tester, chart(0));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Temperatur'), findsNothing);
    });
  });

  group('LineChart (two series with legend)', () {
    LineChart chart(int count, {bool flat = false}) => LineChart(
      title: 'Niederschlag',
      unit: 'mm/h',
      times: _times(count),
      showLegend: true,
      series: [
        ChartSeries(
          values: [for (var i = 0; i < count; i++) flat ? 0.5 : i * 0.1],
          label: 'Open-Meteo',
          color: Colors.blue,
        ),
        ChartSeries(
          values: [for (var i = 0; i < count; i++) flat ? 0.5 : (i % 3) * 0.2],
          label: 'DWD',
          color: Colors.green,
        ),
      ],
    );

    for (final count in [2, 13, 50]) {
      testWidgets('renders $count points', (tester) async {
        await _pump(tester, chart(count));
        expect(tester.takeException(), isNull);
        expect(find.text('Niederschlag (mm/h)'), findsOneWidget);
        expect(find.text('Open-Meteo'), findsOneWidget);
        expect(find.text('DWD'), findsOneWidget);
      });
    }

    testWidgets('renders a flat series', (tester) async {
      await _pump(tester, chart(13, flat: true));
      expect(tester.takeException(), isNull);
      expect(find.text('Niederschlag (mm/h)'), findsOneWidget);
    });
  });

  group('chartRange', () {
    ChartSeries s(List<double> values) =>
        ChartSeries(values: values, color: Colors.blue);

    test('spans all series', () {
      expect(
        chartRange([
          s([1, 3]),
          s([-2, 2]),
        ]),
        (-2.0, 3.0),
      );
    });

    test('extends flat data upwards', () {
      expect(
        chartRange([
          s([4, 4]),
        ]),
        (4.0, 5.0),
      );
    });

    test('ignores non-finite values and handles empty input', () {
      expect(
        chartRange([
          s([1, double.nan, 2]),
        ]),
        (1.0, 2.0),
      );
      expect(chartRange([]), (0.0, 1.0));
      expect(chartRange([s([])]), (0.0, 1.0));
    });
  });

  group('LineChartPainter.shouldRepaint', () {
    LineChartPainter painter({
      Color color = Colors.blue,
      List<int> grid = const [0, 2],
    }) => LineChartPainter(
      series: [
        ChartSeries(values: [1, 2, 3], color: color),
      ],
      minValue: 1,
      maxValue: 3,
      xGridIndices: grid,
    );

    test('is false for equal inputs', () {
      expect(painter().shouldRepaint(painter()), isFalse);
    });

    test('is true when colour or grid change', () {
      expect(painter(color: Colors.red).shouldRepaint(painter()), isTrue);
      expect(painter(grid: [0, 1]).shouldRepaint(painter()), isTrue);
    });

    test('paints empty input without throwing', () {
      const empty = LineChartPainter(series: [], minValue: 0, maxValue: 1);
      final recorder = PictureRecorder();
      empty.paint(Canvas(recorder), const Size(100, 100));
      recorder.endRecording();
    });
  });
}
