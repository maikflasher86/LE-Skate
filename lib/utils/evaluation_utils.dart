import 'package:inliner2/models/hourly_point.dart';

import 'dart:math' show max, min;

/// Aggregates the [points] within [start, end) into the payload metrics map,
/// or returns null when no point lies in that window.
Map<String, double>? aggregateMetrics(
  List<HourlyPoint> points, {
  required DateTime start,
  required DateTime end,
}) {
  final selected = points
      .where((p) => !p.time.isBefore(start) && p.time.isBefore(end))
      .toList();

  if (selected.isEmpty) {
    return null;
  }

  double avg(double Function(HourlyPoint) value) =>
      selected.map(value).reduce((a, b) => a + b) / selected.length;

  double peak(double Function(HourlyPoint) value) =>
      selected.map(value).reduce((a, b) => a > b ? a : b);

  final peakRain = peak((p) => p.rainMm);
  return {
    'temperature_c': double.parse(
      avg((p) => p.temperatureC).toStringAsFixed(2),
    ),
    'wind_kmh': double.parse(avg((p) => p.windKmh).toStringAsFixed(2)),
    // Peak instead of average, so short rain in slot doesn't get smoothed out.
    // Use max from precipitation and rain for best accuracy
    'precipitation_mm': double.parse(
      max(peak((p) => p.precipitationMm), peakRain).toStringAsFixed(2),
    ),
    'rain_mm': double.parse(peakRain.toStringAsFixed(2)),
    'precipitation_probability_percent': double.parse(
      peak((p) => p.precipitationProbabilityPercent).toStringAsFixed(2),
    ),
    'cloud_cover_percent': double.parse(
      avg((p) => p.cloudCoverPercent).toStringAsFixed(2),
    ),
    // Extremes matter for ice, snow and storm (winter outdoor trainings).
    'temperature_min_c': double.parse(
      selected.map((p) => p.temperatureC).reduce(min).toStringAsFixed(2),
    ),
    'wind_gusts_kmh': double.parse(
      peak((p) => p.windGustsKmh).toStringAsFixed(2),
    ),
    'snowfall_cm': double.parse(peak((p) => p.snowfallCm).toStringAsFixed(2)),
  };
}
