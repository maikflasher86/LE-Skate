import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/utils/dwd_merge_utils.dart';

DwdHourlyPoint _point(DateTime time, double mm) =>
    DwdHourlyPoint(time: time, precipitationMm: mm);

void main() {
  final now = DateTime(2026, 11, 16, 12);

  group('addDwdToPayload', () {
    test('assigns points from 4 h before start to end, skips indoor', () {
      final payload = <String, dynamic>{
        'trainings': [
          {
            'title': 'Montag',
            'start': '2026-11-16T18:30:00.000',
            'end': '2026-11-16T20:15:00.000',
            'location': {'label': 'Halle'},
            'is_indoor': true,
          },
          {
            'title': 'Dienstag',
            'start': '2026-11-17T18:30:00.000',
            'end': '2026-11-17T19:30:00.000',
            'location': {'label': 'Landauer Brücke'},
            'is_indoor': false,
          },
        ],
      };
      final points = [
        _point(DateTime(2026, 11, 17, 14), 0.1), // before window
        _point(DateTime(2026, 11, 17, 14, 30), 0.2), // window start
        _point(DateTime(2026, 11, 17, 19, 30), 0.3), // training end
        _point(DateTime(2026, 11, 17, 20), 0.4), // after end
      ];

      final result = addDwdToPayload(payload, {'Landauer Brücke': points});
      final trainings = (result['trainings'] as List)
          .cast<Map<String, dynamic>>();

      expect(trainings.first.containsKey('dwd_points'), isFalse);
      expect(trainings[1]['dwd_points'], [
        points[1].toJson(),
        points[2].toJson(),
      ]);
    });
  });

  group('mergeRainEventsFromDwd', () {
    test('returns the payload unchanged without DWD points', () {
      final payload = <String, dynamic>{
        'last_rain_event': null,
        'next_rain_event': null,
      };
      expect(mergeRainEventsFromDwd(payload, const [], now: now), {
        'last_rain_event': null,
        'next_rain_event': null,
      });
    });

    test('prefers the most recent past and the most imminent future rain', () {
      final payload = <String, dynamic>{
        'last_rain_event': {
          'time': '2026-11-16T08:00',
          'rain_mm': 0.5,
          'source': 'Open-Meteo',
        },
        'next_rain_event': {
          'time': '2026-11-17T15:00',
          'rain_mm': 0.3,
          'source': 'Open-Meteo',
        },
      };
      final points = [
        _point(DateTime(2026, 11, 15, 11), 2.0), // older than 24 h
        _point(DateTime(2026, 11, 16, 10), 0.4), // later past rain
        _point(DateTime(2026, 11, 16, 11), 0.1), // not above threshold
        _point(DateTime(2026, 11, 17, 18), 0.6), // later than Open-Meteo
      ];

      final result = mergeRainEventsFromDwd(payload, points, now: now);

      expect(result['last_rain_event'], {
        'time': DateTime(2026, 11, 16, 10).toIso8601String(),
        'rain_mm': 0.4,
        'source': 'DWD',
      });
      expect(result['next_rain_event'], {
        'time': '2026-11-17T15:00',
        'rain_mm': 0.3,
        'source': 'Open-Meteo',
      });
    });
  });

  group('pickRainEvent', () {
    final early = {'time': '2026-11-16T08:00'};
    final late = {'time': '2026-11-16T10:00'};

    test('returns the other event when one is null', () {
      expect(pickRainEvent(null, late, preferLater: true), late);
      expect(pickRainEvent(early, null, preferLater: false), early);
      expect(pickRainEvent(null, null, preferLater: true), isNull);
    });

    test('picks the later or earlier event', () {
      expect(pickRainEvent(early, late, preferLater: true), late);
      expect(pickRainEvent(early, late, preferLater: false), early);
    });
  });
}
