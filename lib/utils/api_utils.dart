import 'dart:convert';

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

    final allPoints = parseOpenMeteoHourly(hourly, lenient: true).points;
    if (allPoints.isEmpty) {
      return const [];
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
