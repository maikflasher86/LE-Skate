import 'dart:math' as math;

import 'package:inliner2/models/hourly_point.dart';

List<double> toDoubleList(List<dynamic> values) {
  return values.map(toDoubleOrZero).toList();
}

List<double> toDoubleListOrDefault(
  dynamic values, {
  required int fallbackLength,
}) {
  if (values is List<dynamic>) {
    return values.map(toDoubleOrZero).toList();
  }
  return List<double>.filled(fallbackLength, 0);
}

double toDoubleOrZero(dynamic value) {
  return (value as num?)?.toDouble() ?? 0;
}

/// Extracts the `rain` array from an Open-Meteo `hourly` JSON map, falling
/// back to [precipitationFallback] when `rain` is absent or empty (some
/// older/partial API responses omit it).
List<double> _extractRainOrFallback(
  Map<String, dynamic> hourly,
  List<double> precipitationFallback,
) {
  final rainRaw = hourly['rain'] as List<dynamic>?;
  return (rainRaw != null && rainRaw.isNotEmpty)
      ? toDoubleList(rainRaw)
      : precipitationFallback;
}

/// Parsed Open-Meteo `hourly` block. `times[i]` is the raw API time string of
/// `points[i]`.
typedef OpenMeteoHourly = ({List<String> times, List<HourlyPoint> points});

/// Parses the Open-Meteo `hourly` JSON map into [HourlyPoint]s.
///
/// A missing `precipitation_probability` array yields zeros and a missing or
/// empty `rain` array falls back to `precipitation`. Other missing arrays
/// throw, unless [lenient] is set, in which case they yield zeros (and a
/// missing `time` array yields no points). All arrays are truncated to the
/// shortest one.
OpenMeteoHourly parseOpenMeteoHourly(
  Map<String, dynamic> hourly, {
  bool lenient = false,
}) {
  final times = lenient
      ? (hourly['time'] as List<dynamic>? ?? const []).cast<String>()
      : (hourly['time'] as List<dynamic>).cast<String>();
  List<double> series(String key) => lenient
      ? toDoubleListOrDefault(hourly[key], fallbackLength: times.length)
      : toDoubleList(hourly[key] as List<dynamic>);

  final temperature = series('temperature_2m');
  final precipitation = series('precipitation');
  final rain = _extractRainOrFallback(hourly, precipitation);
  final precipitationProbability = toDoubleListOrDefault(
    hourly['precipitation_probability'],
    fallbackLength: times.length,
  );
  final wind = series('wind_speed_10m');
  final cloud = series('cloud_cover');

  final length = [
    times.length,
    temperature.length,
    precipitation.length,
    rain.length,
    precipitationProbability.length,
    wind.length,
    cloud.length,
  ].reduce(math.min);

  return (
    times: times.sublist(0, length),
    points: [
      for (var i = 0; i < length; i++)
        HourlyPoint(
          time: DateTime.parse(times[i]).toLocal(),
          temperatureC: temperature[i],
          precipitationMm: precipitation[i],
          rainMm: rain[i],
          precipitationProbabilityPercent: precipitationProbability[i],
          windKmh: wind[i],
          cloudCoverPercent: cloud[i],
        ),
    ],
  );
}
