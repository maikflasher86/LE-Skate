/// Precipitation strictly above this amount (mm per hour) counts as rain.
const double _rainThresholdMm = 0.1;

/// Look-back period for the rain history and the last rain event.
const Duration rainHistoryWindow = Duration(hours: 24);

/// One precipitation value at a point in time, from any weather source.
///
/// [timeJson] is the time exactly as it should appear in the payload (the raw
/// API string for Open-Meteo, an ISO string for DWD).
typedef RainSample = ({DateTime time, String timeJson, double rainMm});

Map<String, dynamic> _rainEvent(RainSample sample, String source) => {
  'time': sample.timeJson,
  'rain_mm': sample.rainMm,
  'source': source,
};

/// The most recent rain (> [_rainThresholdMm]) within the last
/// [rainHistoryWindow] up to [now], or null. [samples] must be sorted by time.
Map<String, dynamic>? findLastRainEvent(
  List<RainSample> samples, {
  required DateTime now,
  required String source,
}) {
  final windowStart = now.subtract(rainHistoryWindow);
  for (var i = samples.length - 1; i >= 0; i--) {
    final s = samples[i];
    if (!s.time.isBefore(windowStart) &&
        !s.time.isAfter(now) &&
        s.rainMm > _rainThresholdMm) {
      return _rainEvent(s, source);
    }
  }
  return null;
}

/// The first rain (> [_rainThresholdMm]) after [now], or null. [samples] must
/// be sorted by time.
Map<String, dynamic>? findNextRainEvent(
  List<RainSample> samples, {
  required DateTime now,
  required String source,
}) {
  for (final s in samples) {
    if (s.time.isAfter(now) && s.rainMm > _rainThresholdMm) {
      return _rainEvent(s, source);
    }
  }
  return null;
}
