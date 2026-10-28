import 'package:flutter/foundation.dart';
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/utils/forecast_constants.dart';
import 'package:inliner2/utils/rain_event_utils.dart';

/// Assigns per-location DWD precipitation points (pre-training window start
/// to training end) to each outdoor training as `dwd_points`.
Map<String, dynamic> addDwdToPayload(
  Map<String, dynamic> payload,
  Map<String, List<DwdHourlyPoint>> dwdByLocation,
) {
  if (dwdByLocation.isEmpty) {
    debugPrint(
      '[DWD] dwdByLocation is empty – skipping dwd_points assignment',
    );
    return payload;
  }
  final trainings = (payload['trainings'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final training in trainings) {
    if (training['is_indoor'] == true) continue;
    final locationLabel =
        (training['location'] as Map<String, dynamic>?)?['label']
            as String? ??
        dwdByLocation.keys.first;
    final dwdPoints =
        dwdByLocation[locationLabel] ?? dwdByLocation.values.first;
    debugPrint(
      '[DWD] Training "${training['title']} ${training['start']}" '
      '→ location "$locationLabel"',
    );
    if (dwdPoints.isEmpty) {
      debugPrint('[DWD]   └─ no points, skipping');
      continue;
    }
    final start = DateTime.parse(training['start'] as String).toLocal();
    final end = DateTime.parse(training['end'] as String).toLocal();
    final windowStart = start.subtract(preTrainingWindow);
    final filtered = dwdPoints
        .where((p) => !p.time.isBefore(windowStart) && !p.time.isAfter(end))
        .toList();
    debugPrint(
      '[DWD]   └─ window ${windowStart.toIso8601String()} … ${end.toIso8601String()} → ${filtered.length} matching points',
    );
    training['dwd_points'] = filtered.map((p) => p.toJson()).toList();
  }
  return payload;
}

/// Merges the DWD rain events into the payload.
///
/// DWD (BrightSky) and Open-Meteo regularly disagree: DWD may report a dry
/// evening while Open-Meteo predicts rain. Instead of letting DWD replace the
/// Open-Meteo events (which could silently drop an imminent rain event), the
/// more relevant event wins: the most recent one for the past, the most
/// imminent one for the future.
Map<String, dynamic> mergeRainEventsFromDwd(
  Map<String, dynamic> payload,
  List<DwdHourlyPoint> dwdPoints, {
  required DateTime now,
}) {
  if (dwdPoints.isEmpty) return payload;
  final samples = <RainSample>[
    for (final p in dwdPoints)
      (
        time: p.time,
        timeJson: p.time.toIso8601String(),
        rainMm: p.precipitationMm,
      ),
  ];

  payload['last_rain_event'] = pickRainEvent(
    payload['last_rain_event'] as Map<String, dynamic>?,
    findLastRainEvent(samples, now: now, source: 'DWD'),
    preferLater: true,
  );
  payload['next_rain_event'] = pickRainEvent(
    payload['next_rain_event'] as Map<String, dynamic>?,
    findNextRainEvent(samples, now: now, source: 'DWD'),
    preferLater: false,
  );
  return payload;
}

/// Returns the event that matters more to the user: for past events
/// ([preferLater]) the most recent one, for future events the one occurring
/// first. On equal times, [a] wins.
Map<String, dynamic>? pickRainEvent(
  Map<String, dynamic>? a,
  Map<String, dynamic>? b, {
  required bool preferLater,
}) {
  if (a == null) return b;
  if (b == null) return a;
  final timeA = DateTime.parse(a['time'] as String);
  final timeB = DateTime.parse(b['time'] as String);
  final takeB = preferLater ? timeB.isAfter(timeA) : timeB.isBefore(timeA);
  return takeB ? b : a;
}
