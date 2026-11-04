class HourlyPoint {
  const HourlyPoint({
    required this.time,
    required this.temperatureC,
    required this.precipitationMm,
    required this.rainMm,
    required this.precipitationProbabilityPercent,
    required this.windKmh,
    required this.cloudCoverPercent,
    this.snowfallCm = 0,
    this.windGustsKmh = 0,
  });

  final DateTime time;
  final double temperatureC;
  final double precipitationMm;
  final double rainMm;
  final double precipitationProbabilityPercent;
  final double windKmh;
  final double cloudCoverPercent;
  final double snowfallCm;
  final double windGustsKmh;
}
