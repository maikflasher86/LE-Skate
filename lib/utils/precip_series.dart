import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/precipitation_15m_point.dart';

/// Maps each of [targets] to the value of the first item in [items] whose
/// time ([timeOf]) lies within ±30 min of it, or 0.0 if there is none.
List<double> alignToTimes<T>(
  List<DateTime> targets,
  List<T> items,
  DateTime Function(T item) timeOf,
  double Function(T item) selector,
) {
  return targets.map((target) {
    final match = items
        .where((item) => timeOf(item).difference(target).inMinutes.abs() <= 30)
        .firstOrNull;
    return match != null ? selector(match) : 0.0;
  }).toList();
}

typedef DwdWindowSummary = ({
  double totalMm,
  int maxProbability,
  List<DwdHourlyPoint> points,
});

/// Summarizes the DWD [points] between [start] and [end] (inclusive), or
/// returns null if none fall into that window.
DwdWindowSummary? summarizeDwdWindow(
  List<DwdHourlyPoint> points,
  DateTime start,
  DateTime end,
) {
  final during = points
      .where((p) => !p.time.isBefore(start) && !p.time.isAfter(end))
      .toList();
  if (during.isEmpty) return null;
  return (
    totalMm: during.fold(0.0, (sum, p) => sum + p.precipitationMm),
    maxProbability: during
        .map((p) => p.precipitationProbability ?? 0)
        .reduce((a, b) => a > b ? a : b),
    points: during,
  );
}

/// Precipitation chart series on a shared time axis.
typedef PrecipSeries = ({
  /// Whether the 15-minute Open-Meteo data is used as the time axis.
  bool has15m,
  List<DateTime> times,
  List<double> openMeteoMm,
  List<double> openMeteoProbability,
  List<double> dwdMm,
  List<double> dwdProbability,
});

/// Builds the precipitation chart series. The 15-minute Open-Meteo points
/// define the time axis if there are at least two of them, otherwise the
/// hourly points do. Hourly probability and DWD values are aligned to it.
PrecipSeries buildPrecipSeries({
  required List<Precipitation15mPoint> precip15m,
  required List<HourlyPoint> hourly,
  required List<DwdHourlyPoint> dwd,
}) {
  final sorted15m = [...precip15m]..sort((a, b) => a.time.compareTo(b.time));
  final has15m = sorted15m.length >= 2;
  final times = has15m
      ? sorted15m.map((p) => p.time).toList()
      : hourly.map((p) => p.time).toList();
  return (
    has15m: has15m,
    times: times,
    openMeteoMm: has15m
        ? sorted15m.map((p) => p.precipitationMm).toList()
        : hourly.map((p) => p.precipitationMm).toList(),
    openMeteoProbability: has15m
        ? alignToTimes<HourlyPoint>(
            times,
            hourly,
            (p) => p.time,
            (p) => p.precipitationProbabilityPercent,
          )
        : hourly.map((p) => p.precipitationProbabilityPercent).toList(),
    dwdMm: alignToTimes<DwdHourlyPoint>(
      times,
      dwd,
      (d) => d.time,
      (d) => d.precipitationMm,
    ),
    dwdProbability: alignToTimes<DwdHourlyPoint>(
      times,
      dwd,
      (d) => d.time,
      (d) => (d.precipitationProbability ?? 0).toDouble(),
    ),
  );
}
