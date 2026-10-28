import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/precipitation_15m_point.dart';
import 'package:inliner2/utils/precip_series.dart';

HourlyPoint _hourly(DateTime time, {double mm = 0, double prob = 0}) =>
    HourlyPoint(
      time: time,
      temperatureC: 0,
      precipitationMm: mm,
      rainMm: mm,
      precipitationProbabilityPercent: prob,
      windKmh: 0,
      cloudCoverPercent: 0,
    );

DwdHourlyPoint _dwd(DateTime time, double mm, [int? prob]) => DwdHourlyPoint(
  time: time,
  precipitationMm: mm,
  precipitationProbability: prob,
);

void main() {
  final t0 = DateTime(2026, 7, 5, 18);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  group('alignToTimes', () {
    test('picks the first item within ±30 min, else 0', () {
      final items = [(at(0), 1.0), (at(25), 2.0), (at(120), 3.0)];
      final result = alignToTimes<(DateTime, double)>(
        [at(0), at(30), at(60), at(150)],
        items,
        (item) => item.$1,
        (item) => item.$2,
      );
      expect(result, [1.0, 1.0, 0.0, 3.0]);
    });

    test('returns zeros when there are no items', () {
      expect(
        alignToTimes<HourlyPoint>(
          [at(0), at(60)],
          const [],
          (p) => p.time,
          (p) => p.precipitationMm,
        ),
        [0.0, 0.0],
      );
    });
  });

  group('summarizeDwdWindow', () {
    test('sums mm and takes the max probability inside the window', () {
      final summary = summarizeDwdWindow(
        [
          _dwd(at(-60), 5, 90), // before start
          _dwd(at(0), 0.2, 10),
          _dwd(at(60), 0.3), // null probability counts as 0
          _dwd(at(120), 0.5, 40), // == end, inclusive
          _dwd(at(180), 9, 100), // after end
        ],
        at(0),
        at(120),
      );
      expect(summary, isNotNull);
      expect(summary!.totalMm, closeTo(1.0, 1e-9));
      expect(summary.maxProbability, 40);
      expect(summary.points.length, 3);
    });

    test('returns null if no point lies in the window', () {
      expect(summarizeDwdWindow([_dwd(at(-60), 1)], at(0), at(60)), isNull);
      expect(summarizeDwdWindow(const [], at(0), at(60)), isNull);
    });
  });

  group('buildPrecipSeries', () {
    final hourly = [
      _hourly(at(0), mm: 0.1, prob: 10),
      _hourly(at(60), mm: 0.2, prob: 20),
    ];
    final dwd = [_dwd(at(0), 0.4, 30)];

    test('uses the hourly axis with fewer than two 15-min points', () {
      final s = buildPrecipSeries(
        precip15m: [Precipitation15mPoint(time: at(0), precipitationMm: 9)],
        hourly: hourly,
        dwd: dwd,
      );
      expect(s.has15m, isFalse);
      expect(s.times, [at(0), at(60)]);
      expect(s.openMeteoMm, [0.1, 0.2]);
      expect(s.openMeteoProbability, [10.0, 20.0]);
      expect(s.dwdMm, [0.4, 0.0]);
      expect(s.dwdProbability, [30.0, 0.0]);
    });

    test('uses the sorted 15-min axis and aligns the other series', () {
      final s = buildPrecipSeries(
        precip15m: [
          Precipitation15mPoint(time: at(45), precipitationMm: 0.3),
          Precipitation15mPoint(time: at(0), precipitationMm: 0.1),
          Precipitation15mPoint(time: at(15), precipitationMm: 0.2),
        ],
        hourly: hourly,
        dwd: dwd,
      );
      expect(s.has15m, isTrue);
      expect(s.times, [at(0), at(15), at(45)]);
      expect(s.openMeteoMm, [0.1, 0.2, 0.3]);
      // at(45) is within 30 min of the 60-min hourly point only.
      expect(s.openMeteoProbability, [10.0, 10.0, 20.0]);
      expect(s.dwdMm, [0.4, 0.4, 0.0]);
    });
  });
}
