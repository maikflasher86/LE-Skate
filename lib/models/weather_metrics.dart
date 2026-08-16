import 'package:inliner2/utils/parsing_utils.dart';

class WeatherMetrics {
  WeatherMetrics({
    required this.temperatureC,
    required this.windKmh,
    required this.precipitationMm,
    required this.rainMm,
    required this.precipitationProbabilityPercent,
    required this.cloudCoverPercent,
  });

  factory WeatherMetrics.fromJson(Map<String, dynamic> json) {
    return WeatherMetrics(
      temperatureC: toDoubleOrZero(json['temperature_c']),
      windKmh: toDoubleOrZero(json['wind_kmh']),
      precipitationMm: toDoubleOrZero(json['precipitation_mm']),
      rainMm: toDoubleOrZero(json['rain_mm']),
      precipitationProbabilityPercent: toDoubleOrZero(
        json['precipitation_probability_percent'],
      ),
      cloudCoverPercent: toDoubleOrZero(json['cloud_cover_percent']),
    );
  }

  final double temperatureC;
  final double windKmh;
  final double precipitationMm;
  final double rainMm;
  final double precipitationProbabilityPercent;
  final double cloudCoverPercent;
}
