import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/utils/rain_info_utils.dart';

void main() {
  final now = DateTime(2026, 7, 5, 12);

  group('formatRainTime', () {
    test('uses relative day names around now', () {
      expect(
        formatRainTime(DateTime(2026, 7, 5, 9, 5), now: now),
        'heute 09:05 Uhr',
      );
      expect(
        formatRainTime(DateTime(2026, 7, 4, 23), now: now),
        'gestern 23:00 Uhr',
      );
      expect(
        formatRainTime(DateTime(2026, 7, 6, 0, 30), now: now),
        'morgen 00:30 Uhr',
      );
      expect(
        formatRainTime(DateTime(2026, 7, 8, 14), now: now),
        '08.07. 14:00 Uhr',
      );
    });
  });

  group('rainIntensityLabel', () {
    test('maps thresholds 0.5 and 2.0', () {
      expect(rainIntensityLabel(0.49), 'leichter Regen');
      expect(rainIntensityLabel(0.5), 'mäßiger Regen');
      expect(rainIntensityLabel(1.99), 'mäßiger Regen');
      expect(rainIntensityLabel(2.0), 'starker Regen');
    });
  });

  group('rainEventDetails', () {
    test('appends the source if known', () {
      expect(
        rainEventDetails(LastRainEvent(time: now, rainMm: 0.34)),
        'leichter Regen (0.3 mm/h)',
      );
      expect(
        rainEventDetails(LastRainEvent(time: now, rainMm: 3, source: 'DWD')),
        'starker Regen (3.0 mm/h) · DWD',
      );
    });
  });

  group('validLastRainEvent', () {
    LastRainEvent event(DateTime time) => LastRainEvent(time: time, rainMm: 1);

    test('accepts past events up to 24 h old', () {
      final e = event(now.subtract(const Duration(hours: 24)));
      expect(validLastRainEvent(e, now: now), same(e));
    });

    test('rejects older, future and missing events', () {
      expect(
        validLastRainEvent(
          event(now.subtract(const Duration(hours: 25))),
          now: now,
        ),
        isNull,
      );
      expect(
        validLastRainEvent(event(now.add(const Duration(hours: 1))), now: now),
        isNull,
      );
      expect(validLastRainEvent(null, now: now), isNull);
    });
  });

  group('validNextRainEvent', () {
    test('accepts only future events', () {
      final future = LastRainEvent(
        time: now.add(const Duration(minutes: 1)),
        rainMm: 1,
      );
      expect(validNextRainEvent(future, now: now), same(future));
      expect(
        validNextRainEvent(LastRainEvent(time: now, rainMm: 1), now: now),
        isNull,
      );
      expect(validNextRainEvent(null, now: now), isNull);
    });
  });
}
