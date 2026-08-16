import 'package:inliner2/models/evaluation.dart';
import 'dart:math' show max;

Evaluation evaluate(Map<String, double>? metrics) {
  if (metrics == null) {
    return const Evaluation(
      score: 40,
      verdict: 'Maybe',
      reason: 'Noch keine Forecast-Daten für diesen Termin verfügbar.',
    );
  }

  var score = 100;
  final temperature = metrics['temperature_c']!;
  final precipitation = metrics['precipitation_mm']!;
  final rain = metrics['rain_mm'] ?? 0;
  final precipitationProbability =
      metrics['precipitation_probability_percent'] ?? 0;
  final wind = metrics['wind_kmh']!;
  final cloud = metrics['cloud_cover_percent']!;

  if (temperature < 7) {
    score -= 30;
  } else if (temperature < 12) {
    score -= 12;
  } else if (temperature > 30) {
    score -= 28;
  } else if (temperature > 25) {
    score -= 10;
  }

  if (precipitation > 1.2) {
    score -= 45;
  } else if (precipitation > 0.4) {
    score -= 25;
  } else if (precipitation > 0.1) {
    score -= 8;
  }

  if (wind > 30) {
    score -= 30;
  } else if (wind > 22) {
    score -= 16;
  } else if (wind > 16) {
    score -= 8;
  }

  if (cloud > 95) {
    score -= 7;
  }

  score = score.clamp(0, 100);
  final verdict = score >= 75
      ? 'Go'
      : score >= 50
      ? 'Maybe'
      : 'No';

  return Evaluation(
    score: score,
    verdict: verdict,
    reason:
        'Temp ${temperature.toStringAsFixed(1)} °C, Regen ${precipitation.toStringAsFixed(2)} mm/h, '
        'Niederschlagswahrscheinlichkeit. ${precipitationProbability.toStringAsFixed(0)} %, '
        'Rain ${rain.toStringAsFixed(2)} mm/h, '
        'Wind ${wind.toStringAsFixed(1)} km/h, Wolken ${cloud.toStringAsFixed(0)} %.',
  );
}

Map<String, double>? aggregateMetrics({
  required List<String> times,
  required List<double> temperatures,
  required List<double> precipitations,
  required List<double> rains,
  required List<double> precipitationProbabilities,
  required List<double> winds,
  required List<double> clouds,
  required DateTime start,
  required DateTime end,
}) {
  final indices = <int>[];
  for (var i = 0; i < times.length; i++) {
    final point = DateTime.parse(times[i]).toLocal();
    if ((point.isAtSameMomentAs(start) || point.isAfter(start)) &&
        point.isBefore(end)) {
      indices.add(i);
    }
  }

  if (indices.isEmpty) {
    return null;
  }

  double avg(List<double> values) {
    final selected = indices.map((index) => values[index]).toList();
    return selected.reduce((a, b) => a + b) / selected.length;
  }

  double peak(List<double> values) {
    final selected = indices.map((index) => values[index]).toList();
    return selected.reduce((a, b) => a > b ? a : b);
  }

  return {
    'temperature_c': double.parse(avg(temperatures).toStringAsFixed(2)),
    'wind_kmh': double.parse(avg(winds).toStringAsFixed(2)),
    // Peak instead of average, so short rain in slot doesn't get smoothed out.
    // Use max from precipitation and rain for best accuracy
    'precipitation_mm': double.parse(
      max(peak(precipitations), peak(rains)).toStringAsFixed(2),
    ),
    'rain_mm': double.parse(peak(rains).toStringAsFixed(2)),
    'precipitation_probability_percent': double.parse(
      peak(precipitationProbabilities).toStringAsFixed(2),
    ),
    'cloud_cover_percent': double.parse(avg(clouds).toStringAsFixed(2)),
  };
}
