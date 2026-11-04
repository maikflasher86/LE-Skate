import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/utils/evaluation_utils.dart';

void main() {
  group('aggregateMetrics', () {
    HourlyPoint point(
      int hour, {
      required double temperature,
      required double precipitation,
      required double rain,
      required double probability,
      required double wind,
      required double cloud,
    }) => HourlyPoint(
      time: DateTime(2026, 7, 5, hour),
      temperatureC: temperature,
      precipitationMm: precipitation,
      rainMm: rain,
      precipitationProbabilityPercent: probability,
      windKmh: wind,
      cloudCoverPercent: cloud,
    );

    final points = [
      point(9, temperature: 10, precipitation: 5, rain: 5, probability: 90, wind: 50, cloud: 100),
      point(10, temperature: 18, precipitation: 0.2, rain: 0.4, probability: 20, wind: 10, cloud: 30),
      point(11, temperature: 20, precipitation: 0.6, rain: 0.1, probability: 40, wind: 14, cloud: 50),
      point(12, temperature: 30, precipitation: 5, rain: 5, probability: 90, wind: 50, cloud: 100),
    ];

    Map<String, double>? aggregate(DateTime start, DateTime end) =>
        aggregateMetrics(points, start: start, end: end);

    test('averages and peaks values within [start, end)', () {
      final result = aggregate(
        DateTime(2026, 7, 5, 10),
        DateTime(2026, 7, 5, 12),
      );

      expect(result, {
        'temperature_c': 19.0,
        'wind_kmh': 12.0,
        // max(peak precipitation, peak rain)
        'precipitation_mm': 0.6,
        'rain_mm': 0.4,
        'precipitation_probability_percent': 40.0,
        'cloud_cover_percent': 40.0,
      });
    });

    test('returns null when no data point lies in the window', () {
      expect(
        aggregate(DateTime(2026, 7, 6, 10), DateTime(2026, 7, 6, 12)),
        isNull,
      );
    });
  });
}
