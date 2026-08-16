/// Hourly precipitation data point from DWD (via BrightSky API).
class DwdHourlyPoint {
  const DwdHourlyPoint({
    required this.time,
    required this.precipitationMm,
    this.precipitationProbability,
  });

  /// Parses a data point from the BrightSky API response (key: `timestamp`).
  factory DwdHourlyPoint.fromBrightSky(Map<String, dynamic> json) {
    return DwdHourlyPoint(
      time: DateTime.parse(json['timestamp'] as String).toLocal(),
      precipitationMm: (json['precipitation'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: (json['precipitation_probability'] as num?)
          ?.toInt(),
    );
  }

  /// Parses a data point from our internal payload format (key: `time`).
  factory DwdHourlyPoint.fromJson(Map<String, dynamic> json) {
    return DwdHourlyPoint(
      time: DateTime.parse(json['time'] as String).toLocal(),
      precipitationMm: (json['precipitation_mm'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: (json['precipitation_probability'] as num?)
          ?.toInt(),
    );
  }

  final DateTime time;

  /// Precipitation in mm (last hour).
  final double precipitationMm;

  /// Precipitation probability in percent (only for forecasts).
  final int? precipitationProbability;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'precipitation_mm': precipitationMm,
    'precipitation_probability': precipitationProbability,
  };
}
