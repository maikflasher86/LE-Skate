import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/utils/forecast_payload_utils.dart';

/// Builds a synthetic Open-Meteo response with hourly data from
/// 2026-11-15 00:00 to 2026-11-17 23:00 (local time strings, no offset).
String _openMeteoFixture() {
  final times = <String>[];
  final temperatures = <double>[];
  final rains = <double>[];
  const rainAt = {
    '2026-11-16T08:00': 0.5, // last rain event (within past 24 h)
    '2026-11-16T10:00': 0.05, // below the 0.1 mm threshold
    '2026-11-16T20:00': 0.08, // below the 0.1 mm threshold
    '2026-11-17T15:00': 0.3, // next rain event, inside 4 h pre-training window
  };
  for (var h = 0; h < 72; h++) {
    final t = DateTime(2026, 11, 15).add(Duration(hours: h));
    final key =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}T'
        '${t.hour.toString().padLeft(2, '0')}:00';
    times.add(key);
    // Only the 19:00 slot on Tuesday lies inside the training window.
    temperatures.add(key == '2026-11-17T19:00' ? 6.0 : 10.0);
    rains.add(rainAt[key] ?? 0.0);
  }
  return jsonEncode({
    'hourly': {
      'time': times,
      'temperature_2m': temperatures,
      'precipitation': rains,
      'rain': rains,
      'precipitation_probability': List.filled(times.length, 20),
      'wind_speed_10m': List.filled(times.length, 12.0),
      'cloud_cover': List.filled(times.length, 50),
    },
    'minutely_15': {
      'time': [
        '2026-11-17T14:15',
        '2026-11-17T14:30',
        '2026-11-17T21:30',
        '2026-11-17T21:45',
      ],
      'precipitation': [0.1, 0.2, 0.3, 0.4],
      'precipitation_probability': [10, 20, 30, 40],
    },
  });
}

void main() {
  // Monday in winter: Monday = indoor (TH "Am Rabet"),
  // Tuesday = outdoor (Landauer Brücke).
  final now = DateTime(2026, 11, 16, 12);

  group('buildForecastPayload', () {
    late Map<String, dynamic> payload;
    late String body;

    setUp(() async {
      body = _openMeteoFixture();
      payload = await buildForecastPayload({
        'bodies': {'Landauer Brücke': body},
        'active_days': [1, 2],
      }, now: now);
    });

    List<Map<String, dynamic>> trainings() =>
        (payload['trainings'] as List).cast<Map<String, dynamic>>();

    test('contains the sessions of the next 7 days sorted by start', () {
      expect(payload['fetched_at'], '2026-11-16T12:00:00.000');
      expect(trainings().map((t) => t['id']), [
        'day1_2026-11-16',
        'day2_2026-11-17',
      ]);
      expect(payload['raw_api_json'], body);
    });

    test('indoor session carries no weather or evaluation', () {
      final indoor = trainings().first;
      expect(indoor['title'], 'Montag');
      expect(indoor['training_name'], 'Rabet');
      expect(indoor['start'], '2026-11-16T18:30:00.000');
      expect(indoor['end'], '2026-11-16T20:15:00.000');
      expect((indoor['location'] as Map)['label'], 'TH "Am Rabet"');
      final parsedIndoor = TrainingForecast.fromJson(indoor);
      expect(parsedIndoor.locationLabel, 'TH "Am Rabet"');
      expect(parsedIndoor.courses.single.category, 'Fitness');
      expect((indoor['courses'] as List).single, {
        'category': 'Fitness',
        'instructors': ['Annett Marien', 'Michael Marien', 'Annett Voigt'],
        'content': 'Athletik + Spiel',
        'equipment': 'Turnschuh',
        'notes': [],
      });
      expect(indoor['is_indoor'], isTrue);
      expect(indoor['score'], isNull);
      expect(indoor['llm_score'], isNull);
      expect(indoor['verdict'], 'Indoor');
      expect(indoor['reason'], '');
      expect(indoor['recommendation'], isNull);
      expect(indoor['weather'], isNull);
      expect(indoor['rain_before_training'], isEmpty);
      expect(indoor['precipitation_15m'], isEmpty);
    });

    test('outdoor session is evaluated from the training window', () {
      final outdoor = trainings()[1];
      expect(outdoor['title'], 'Dienstag');
      expect(outdoor['training_name'], 'Landauer Brücke');
      expect(outdoor['start'], '2026-11-17T18:30:00.000');
      expect(outdoor['end'], '2026-11-17T19:30:00.000');
      expect(outdoor['is_indoor'], isFalse);
      expect(outdoor['weather'], {
        'temperature_c': 6.0,
        'wind_kmh': 12.0,
        'precipitation_mm': 0.0,
        'rain_mm': 0.0,
        'precipitation_probability_percent': 20.0,
        'cloud_cover_percent': 50.0,
      });
      expect(outdoor['score'], 70);
      expect(outdoor['llm_score'], isNull);
      expect(outdoor['verdict'], 'Maybe');
      expect(
        outdoor['reason'],
        'Temp 6.0 °C, Regen 0.00 mm/h, '
        'Niederschlagswahrscheinlichkeit. 20 %, '
        'Rain 0.00 mm/h, Wind 12.0 km/h, Wolken 50 %.',
      );
      expect(outdoor['recommendation'], isNull);
    });

    test('rain_before_training covers the 4 h before start', () {
      final outdoor = trainings()[1];
      expect(outdoor['rain_before_training'], [
        {'time': '2026-11-17T15:00', 'rain_mm': 0.3},
        {'time': '2026-11-17T16:00', 'rain_mm': 0.0},
        {'time': '2026-11-17T17:00', 'rain_mm': 0.0},
        {'time': '2026-11-17T18:00', 'rain_mm': 0.0},
      ]);
    });

    test('precipitation_15m covers 4 h before start to 2 h after end', () {
      final outdoor = trainings()[1];
      expect(outdoor['precipitation_15m'], [
        {
          'time': '2026-11-17T14:30',
          'precipitation_mm': 0.2,
          'precipitation_probability': 20,
        },
        {
          'time': '2026-11-17T21:30',
          'precipitation_mm': 0.3,
          'precipitation_probability': 30,
        },
      ]);
    });

    test('rain history spans the past 24 h inclusive', () {
      final history = (payload['rain_history_24h'] as List)
          .cast<Map<String, dynamic>>();
      expect(history.length, 25);
      expect(history.first['time'], '2026-11-15T12:00');
      expect(history.last['time'], '2026-11-16T12:00');
    });

    test('last and next rain events use the 0.1 mm threshold', () {
      expect(payload['last_rain_event'], {
        'time': '2026-11-16T08:00',
        'rain_mm': 0.5,
        'source': 'Open-Meteo',
      });
      expect(payload['next_rain_event'], {
        'time': '2026-11-17T15:00',
        'rain_mm': 0.3,
        'source': 'Open-Meteo',
      });
    });
  });

  test('works without any weather body (indoor only)', () async {
    final payload = await buildForecastPayload({
      'bodies': <String, String>{},
      'active_days': [1],
    }, now: now);

    final trainings = (payload['trainings'] as List)
        .cast<Map<String, dynamic>>();
    expect(trainings.map((t) => t['id']), ['day1_2026-11-16']);
    expect(trainings.single['is_indoor'], isTrue);
    expect(payload['raw_api_json'], '');
    expect(payload['rain_history_24h'], isEmpty);
    expect(payload['last_rain_event'], isNull);
    expect(payload['next_rain_event'], isNull);
  });

  test(
    'includes both Saturday categories without duplicating the session',
    () async {
      final payload = await buildForecastPayload({
        'bodies': <String, String>{},
        'active_days': [6],
      }, now: DateTime(2026, 11, 16, 12));
      final trainings = (payload['trainings'] as List)
          .cast<Map<String, dynamic>>();
      final saturday = trainings.firstWhere(
        (training) => training['title'] == 'Samstag',
      );

      expect(saturday['start'], '2026-11-21T14:00:00.000');
      final courses = (saturday['courses'] as List)
          .cast<Map<String, dynamic>>();
      expect(courses.map((course) => course['category']), ['Fitness', 'Kurs']);
      expect(courses[1]['instructors'], ['Sven Knauer-Goldschmidt']);
      expect(courses[1]['notes'], ['Nur nach Voranmeldung']);
    },
  );

  test('uses the gym venue label as location', () async {
    final payload = await buildForecastPayload({
      'bodies': <String, String>{},
      'active_days': [3],
    }, now: now);
    final training = (payload['trainings'] as List)
        .cast<Map<String, dynamic>>()
        .single;

    expect(
      TrainingForecast.fromJson(training).locationLabel,
      'Kraftraum RR-Bahn',
    );
  });
}
