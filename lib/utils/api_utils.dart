import 'dart:convert';

import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/utils/parsing_utils.dart';

/// Hourly points of [day] between 07:00 and 22:00, or none if fewer than two.
List<HourlyPoint> hourlyPointsOfDay(String rawJson, DateTime day) {
  if (rawJson.isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final hourly = decoded['hourly'] as Map<String, dynamic>?;
    if (hourly == null) {
      return const [];
    }

    final dayStart = DateTime(day.year, day.month, day.day, 7);
    final dayEnd = DateTime(day.year, day.month, day.day, 22);
    final points = parseOpenMeteoHourly(hourly, lenient: true).points
        .where(
          (point) =>
              !point.time.isBefore(dayStart) && point.time.isBefore(dayEnd),
        )
        .toList();
    return points.length >= 2 ? points : const [];
  } catch (_) {
    return const [];
  }
}
