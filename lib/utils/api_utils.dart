import 'dart:convert';
import 'dart:math' as math;

import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/models/training_period_points.dart';
import 'package:inliner2/utils/parsing_utils.dart';

List<TrainingPeriodPoints> extractHourlyPointsByTraining(
  String rawJson,
  List<TrainingForecast> trainings,
) {
  if (rawJson.isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final hourly = decoded['hourly'] as Map<String, dynamic>?;
    if (hourly == null) {
      return const [];
    }

    final times = (hourly['time'] as List<dynamic>? ?? const []).cast<String>();
    final fallbackLength = times.length;
    final temperature = toDoubleListOrDefault(
      hourly['temperature_2m'],
      fallbackLength: fallbackLength,
    );
    final precipitation = toDoubleListOrDefault(
      hourly['precipitation'],
      fallbackLength: fallbackLength,
    );
    // Use 'rain' if available and not empty, otherwise fallback to 'precipitation'
    final rain = extractRainOrFallback(hourly, precipitation);
    final precipitationProbability = toDoubleListOrDefault(
      hourly['precipitation_probability'],
      fallbackLength: fallbackLength,
    );
    final wind = toDoubleListOrDefault(
      hourly['wind_speed_10m'],
      fallbackLength: fallbackLength,
    );
    final cloud = toDoubleListOrDefault(
      hourly['cloud_cover'],
      fallbackLength: fallbackLength,
    );

    final length = [
      times.length,
      temperature.length,
      precipitation.length,
      rain.length,
      precipitationProbability.length,
      wind.length,
      cloud.length,
    ].reduce(math.min);
    if (length == 0) {
      return const [];
    }

    final allPoints = <HourlyPoint>[];
    for (var i = 0; i < length; i++) {
      allPoints.add(
        HourlyPoint(
          time: DateTime.parse(times[i]).toLocal(),
          temperatureC: temperature[i],
          precipitationMm: precipitation[i],
          rainMm: rain[i],
          precipitationProbabilityPercent: precipitationProbability[i],
          windKmh: wind[i],
          cloudCoverPercent: cloud[i],
        ),
      );
    }

    final result = <TrainingPeriodPoints>[];
    for (final training in trainings) {
      final dayStart = DateTime(
        training.start.year,
        training.start.month,
        training.start.day,
        7,
      );
      final dayEnd = DateTime(
        training.start.year,
        training.start.month,
        training.start.day,
        22,
      );

      final periodPoints = allPoints
          .where(
            (point) =>
                !point.time.isBefore(dayStart) && point.time.isBefore(dayEnd),
          )
          .toList();
      if (periodPoints.length >= 2) {
        result.add(
          TrainingPeriodPoints(training: training, points: periodPoints),
        );
      }
    }

    return result;
  } catch (_) {
    return const [];
  }
}
