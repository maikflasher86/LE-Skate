import 'dart:convert';

import 'package:inliner2/models/training_session.dart';
import 'package:inliner2/utils/evaluation_utils.dart';
import 'package:inliner2/utils/forecast_constants.dart';
import 'package:inliner2/utils/parsing_utils.dart';
import 'package:inliner2/utils/rain_event_utils.dart';
import 'package:inliner2/utils/session_utils.dart';

// ---------------------------------------------------------------------------
// Parsed weather data for one location.
// ---------------------------------------------------------------------------
typedef _LocationWeather = ({
  OpenMeteoHourly hourly,
  List<String> times15m,
  List<double> precipitation15m,
  List<double> probability15m,
});

_LocationWeather _parseBody(String rawBody) {
  final jsonMap = jsonDecode(rawBody) as Map<String, dynamic>;
  final hourly = jsonMap['hourly'] as Map<String, dynamic>?;
  if (hourly == null) {
    throw Exception('Invalid weather response: hourly missing.');
  }
  final parsedHourly = parseOpenMeteoHourly(hourly);

  // 15-minute precipitation + probability (optional)
  final minutely15 = jsonMap['minutely_15'] as Map<String, dynamic>?;
  final times15m = minutely15 != null
      ? (minutely15['time'] as List<dynamic>? ?? []).cast<String>()
      : <String>[];
  final precipitation15m = minutely15 != null
      ? toDoubleList(minutely15['precipitation'] as List<dynamic>? ?? const [])
      : <double>[];
  final probability15m = minutely15 != null
      ? toDoubleListOrDefault(
          minutely15['precipitation_probability'],
          fallbackLength: times15m.length,
        )
      : <double>[];

  return (
    hourly: parsedHourly,
    times15m: times15m,
    precipitation15m: precipitation15m,
    probability15m: probability15m,
  );
}

// An empty stand-in used when no weather data at all was fetched (e.g. only
// indoor trainings are active), so `primary` lookups never crash.
const _LocationWeather _emptyLocationWeather = (
  hourly: (times: [], points: []),
  times15m: [],
  precipitation15m: [],
  probability15m: [],
);

// ---------------------------------------------------------------------------

/// Hourly `{time, rain_mm}` entries of [w] whose local time satisfies [test].
List<Map<String, dynamic>> _rainEntries(
  _LocationWeather w,
  bool Function(DateTime time) test,
) => [
  for (var i = 0; i < w.hourly.points.length; i++)
    if (test(w.hourly.points[i].time))
      {'time': w.hourly.times[i], 'rain_mm': w.hourly.points[i].rainMm},
];

/// Builds the payload entry for one [session], evaluated on the weather [w]
/// of its location.
Map<String, dynamic> _buildTrainingEntry(
  TrainingSession session,
  _LocationWeather w,
) {
  final base = <String, dynamic>{
    'id': session.id,
    'title': session.title,
    'training_name': session.trainingName,
    'start': session.start.toIso8601String(),
    'end': session.end.toIso8601String(),
    'location': session.location.toJson(),
    'is_indoor': session.isIndoor,
    'score': null,
    'llm_score': null,
    'verdict': 'Indoor',
    'reason': '',
    'recommendation': null,
    'weather': null,
    'rain_before_training': <Map<String, dynamic>>[],
    'precipitation_15m': <Map<String, dynamic>>[],
  };
  // Indoor training (e.g. sports hall): weather is irrelevant, so no
  // weather/evaluation is computed at all, only day/time are shown.
  if (session.isIndoor) return base;

  // Rain in the pre-training window (asphalt drying period)
  final windowStart = session.start.subtract(preTrainingWindow);
  final rainBeforeTraining = _rainEntries(
    w,
    (t) => !t.isBefore(windowStart) && t.isBefore(session.start),
  );

  // 15-minute precipitation: pre-training window start to 2h after end
  // (same window as rain_before_training, plus training + buffer)
  // Contains precipitation_mm AND precipitation_probability for LLM
  final window15mEnd = session.end.add(const Duration(hours: 2));
  final precip15mWindow = <Map<String, dynamic>>[];
  for (
    var i = 0;
    i < w.times15m.length && i < w.precipitation15m.length;
    i++
  ) {
    final t = DateTime.parse(w.times15m[i]).toLocal();
    if (!t.isBefore(windowStart) && !t.isAfter(window15mEnd)) {
      precip15mWindow.add({
        'time': w.times15m[i],
        'precipitation_mm': w.precipitation15m[i],
        'precipitation_probability': i < w.probability15m.length
            ? w.probability15m[i].toInt()
            : 0,
      });
    }
  }

  final metrics = aggregateMetrics(
    w.hourly.points,
    start: session.start,
    end: session.end,
  );
  final evaluation = evaluate(metrics);

  return {
    ...base,
    'score': evaluation.score,
    'verdict': evaluation.verdict,
    'reason': evaluation.reason,
    'weather': metrics,
    'rain_before_training': rainBeforeTraining,
    'precipitation_15m': precip15mWindow,
  };
}

Future<Map<String, dynamic>> buildForecastPayload(
  Map<String, dynamic> input, {
  DateTime? now,
}) async {
  // bodies: Map<locationLabel, rawJsonBody>
  final rawBodies = (input['bodies'] as Map).cast<String, String>();
  final activeDays = (input['active_days'] as List<dynamic>)
      .cast<int>()
      .toSet();

  // Parse all bodies.
  final weatherByLocation = rawBodies.map(
    (label, body) => MapEntry(label, _parseBody(body)),
  );

  // First available location is used for global stats (rain history, next/last rain).
  // May be empty when only indoor trainings are active (no weather fetched at all).
  final primaryKey = weatherByLocation.keys.firstOrNull;
  final primary = primaryKey != null
      ? weatherByLocation[primaryKey]!
      : _emptyLocationWeather;

  final reference = now ?? DateTime.now();
  final oneWeekAhead = reference.add(const Duration(days: 7));
  final sessions = await nextSessions(
    reference,
    activeDays: activeDays,
    maxCount: maxForecastSessions,
  );
  // All sessions within the next 7 days
  final limitedSessions = sessions
      .where((s) => !s.start.isAfter(oneWeekAhead))
      .toList();

  // Rain history for LLM context (primary location)
  final historyStart = reference.subtract(rainHistoryWindow);
  final rainHistory24h = _rainEntries(
    primary,
    (t) => !t.isBefore(historyStart) && !t.isAfter(reference),
  );

  final trainings = [
    for (final session in limitedSessions)
      _buildTrainingEntry(
        session,
        // Pick the weather data for this session's location; fall back to primary.
        weatherByLocation[session.location.label] ?? primary,
      ),
  ]..sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));

  final rainSamples = <RainSample>[
    for (var i = 0; i < primary.hourly.points.length; i++)
      (
        time: primary.hourly.points[i].time,
        timeJson: primary.hourly.times[i],
        rainMm: primary.hourly.points[i].rainMm,
      ),
  ];

  return {
    'fetched_at': reference.toIso8601String(),
    'trainings': trainings,
    // Raw JSON of the primary location only (used for the hourly charts).
    'raw_api_json': rawBodies[primaryKey] ?? rawBodies.values.firstOrNull ?? '',
    'rain_history_24h': rainHistory24h,
    'last_rain_event': findLastRainEvent(
      rainSamples,
      now: reference,
      source: 'Open-Meteo',
    ),
    'next_rain_event': findNextRainEvent(
      rainSamples,
      now: reference,
      source: 'Open-Meteo',
    ),
  };
}
