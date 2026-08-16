import 'dart:convert';

import 'package:inliner2/utils/evaluation_utils.dart';
import 'package:inliner2/utils/parsing_utils.dart';
import 'package:inliner2/utils/session_utils.dart';

// ---------------------------------------------------------------------------
// Parsed weather arrays for one location.
// ---------------------------------------------------------------------------
typedef _LocationWeather = ({
  List<String> times,
  List<double> temperatures,
  List<double> precipitations,
  List<double> rains,
  List<double> precipProbabilities,
  List<double> winds,
  List<double> clouds,
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

  final times = (hourly['time'] as List<dynamic>).cast<String>();
  final fallbackLength = times.length;
  final temperatures = toDoubleList(hourly['temperature_2m'] as List<dynamic>);
  final precipitations = toDoubleList(hourly['precipitation'] as List<dynamic>);
  // Use 'rain' if available, otherwise fallback to 'precipitation'
  final rains = extractRainOrFallback(hourly, precipitations);
  final precipProbabilities = toDoubleListOrDefault(
    hourly['precipitation_probability'],
    fallbackLength: fallbackLength,
  );
  final winds = toDoubleList(hourly['wind_speed_10m'] as List<dynamic>);
  final clouds = toDoubleList(hourly['cloud_cover'] as List<dynamic>);

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
    times: times,
    temperatures: temperatures,
    precipitations: precipitations,
    rains: rains,
    precipProbabilities: precipProbabilities,
    winds: winds,
    clouds: clouds,
    times15m: times15m,
    precipitation15m: precipitation15m,
    probability15m: probability15m,
  );
}

// ---------------------------------------------------------------------------

Map<String, dynamic> buildForecastPayload(Map<String, dynamic> input) {
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
  final primaryKey = weatherByLocation.keys.first;
  final primary = weatherByLocation[primaryKey]!;

  final now = DateTime.now();
  final oneWeekAhead = now.add(const Duration(days: 7));
  final sessions = nextSessions(now, activeDays: activeDays, maxCount: 14)
    ..sort((a, b) => a.start.compareTo(b.start));
  // All sessions within the next 7 days
  final limitedSessions = sessions
      .where((s) => !s.start.isAfter(oneWeekAhead))
      .toList();

  // Rain history from last 24h for LLM context (primary location)
  final history24hStart = now.subtract(const Duration(hours: 24));
  final rainHistory24h = <Map<String, dynamic>>[];
  for (var i = 0; i < primary.times.length; i++) {
    final t = DateTime.parse(primary.times[i]).toLocal();
    if (!t.isBefore(history24hStart) && !t.isAfter(now)) {
      rainHistory24h.add({
        'time': primary.times[i],
        'rain_mm': primary.rains[i],
      });
    }
  }

  final trainings = limitedSessions.map((session) {
    // Pick the weather data for this session's location; fall back to primary.
    final w = weatherByLocation[session.location.label] ?? primary;

    // Calculate rain 4h before training start (asphalt drying period)
    final window4hStart = session.start.subtract(const Duration(hours: 4));
    final rainBeforeTraining = <Map<String, dynamic>>[];
    for (var i = 0; i < w.times.length; i++) {
      final t = DateTime.parse(w.times[i]).toLocal();
      if (!t.isBefore(window4hStart) && t.isBefore(session.start)) {
        rainBeforeTraining.add({'time': w.times[i], 'rain_mm': w.rains[i]});
      }
    }

    // 15-minute precipitation: 4h before start to 2h after end
    // (same window as rain_before_training, plus training + buffer)
    // Contains precipitation_mm AND precipitation_probability for LLM
    final window15mStart = session.start.subtract(const Duration(hours: 4));
    final window15mEnd = session.end.add(const Duration(hours: 2));
    final precip15mWindow = <Map<String, dynamic>>[];
    for (
      var i = 0;
      i < w.times15m.length && i < w.precipitation15m.length;
      i++
    ) {
      final t = DateTime.parse(w.times15m[i]).toLocal();
      if (!t.isBefore(window15mStart) && !t.isAfter(window15mEnd)) {
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
      times: w.times,
      temperatures: w.temperatures,
      precipitations: w.precipitations,
      rains: w.rains,
      precipitationProbabilities: w.precipProbabilities,
      winds: w.winds,
      clouds: w.clouds,
      start: session.start,
      end: session.end,
    );

    final evaluation = evaluate(metrics);

    return {
      'id': session.id,
      'title': session.title,
      'training_name': session.trainingName,
      'start': session.start.toIso8601String(),
      'end': session.end.toIso8601String(),
      'location': {
        'lat': session.location.lat,
        'lon': session.location.lon,
        'label': session.location.label,
      },
      'score': evaluation.score,
      'llm_score': null,
      'verdict': evaluation.verdict,
      'reason': evaluation.reason,
      'recommendation': null,
      'weather': metrics,
      'rain_before_training': rainBeforeTraining,
      'precipitation_15m': precip15mWindow,
    };
  }).toList()..sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));

  // Determine last rain event from past 24h
  Map<String, dynamic>? lastRainEvent;
  for (var i = rainHistory24h.length - 1; i >= 0; i--) {
    final entry = rainHistory24h[i];
    if ((entry['rain_mm'] as double) > 0.1) {
      lastRainEvent = entry;
      break;
    }
  }

  // Determine next rain event in future
  Map<String, dynamic>? nextRainEvent;
  for (var i = 0; i < primary.times.length; i++) {
    final t = DateTime.parse(primary.times[i]).toLocal();
    if (t.isAfter(now) && primary.rains[i] > 0.1) {
      nextRainEvent = {'time': primary.times[i], 'rain_mm': primary.rains[i]};
      break;
    }
  }

  return {
    'fetched_at': now.toIso8601String(),
    'trainings': trainings,
    // Serialise all location bodies for debug purposes.
    'raw_api_json': rawBodies[primaryKey] ?? rawBodies.values.first,
    'rain_history_24h': rainHistory24h,
    'last_rain_event': lastRainEvent,
    'next_rain_event': nextRainEvent,
  };
}
