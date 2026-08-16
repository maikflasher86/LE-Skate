class Precipitation15mPoint {
  const Precipitation15mPoint({
    required this.time,
    required this.precipitationMm,
  });

  factory Precipitation15mPoint.fromJson(Map<String, dynamic> json) {
    return Precipitation15mPoint(
      time: DateTime.parse(json['time'] as String).toLocal(),
      precipitationMm: (json['precipitation_mm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final DateTime time;
  final double precipitationMm;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'precipitation_mm': precipitationMm,
  };
}
