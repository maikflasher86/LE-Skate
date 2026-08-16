class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperatureC,
    required this.precipitationMm,
    required this.rainMm,
    required this.precipitationProbabilityPercent,
    required this.windKmh,
    required this.cloudCoverPercent,
  });

  final DateTime time;
  final double temperatureC;
  final double precipitationMm;
  final double rainMm;
  final double precipitationProbabilityPercent;
  final double windKmh;
  final double cloudCoverPercent;
}
