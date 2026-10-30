import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/utils/session_utils.dart';

TrainingForecast _training(String id, DateTime start) => TrainingForecast(
  id: id,
  title: id,
  trainingName: id,
  start: start,
  end: start.add(const Duration(hours: 2)),
  llmScore: null,
  verdict: 'Go',
  reason: '',
  weather: null,
);

void main() {
  group('visibleTrainings', () {
    final regular = _training('day7_2026-07-05', DateTime(2026, 7, 5, 10));
    final alternative = _training('day5_2026-07-17', DateTime(2026, 7, 17, 19));
    final event = _training('event_2026-07-17_X', DateTime(2026, 7, 17, 19));

    test('precondition: the odd-week Friday is an alternative date', () {
      expect(isAlternativeTrainingDate(alternative.start), isTrue);
      expect(isAlternativeTrainingDate(regular.start), isFalse);
    });

    test('hides alternatives but keeps one-time events', () {
      expect(
        visibleTrainings([
          regular,
          alternative,
          event,
        ], showAlternatives: false),
        [regular, event],
      );
    });

    test('shows everything when alternatives are enabled', () {
      expect(
        visibleTrainings([regular, alternative, event], showAlternatives: true),
        [regular, alternative, event],
      );
    });
  });

  group('nextSessions', () {
    test(
      'suppresses the regular weekday training on a day with a one-time event',
      () async {
        // Sunday 2026-09-20 is both an odd-week regular Sunday training day
        // (Bahn Möckern) and the date of the "Porsche Event" one-time event.
        // The regular training must not be included since it doesn't happen.
        final now = DateTime(2026, 9, 18); // Friday, 2 days before
        final sessions = await nextSessions(
          now,
          activeDays: {1, 2, 3, 4, 5, 6, 7},
          maxCount: 20,
        );

        final sunday = sessions.where(
          (s) =>
              s.start.year == 2026 && s.start.month == 9 && s.start.day == 20,
        );

        expect(sunday.length, 1);
        expect(sunday.single.trainingName, 'Porsche Event');
        expect(sunday.single.location.label, 'Porsche');
      },
    );
  });

  group('effectiveActiveDays', () {
    test(
      'falls back to regular winter days when stored days are summer-only',
      () {
        // The fallback excludes Wednesday (3) because it requires registration.
        // The remaining winter days are Monday, Tuesday, Thursday and Saturday.
        // The summer-only days {5, 7} don't match any winter day.
        final winterDate = DateTime(2026, 11, 15);
        final result = effectiveActiveDays({5, 7}, now: winterDate);

        expect(result, {1, 2, 4, 6});
      },
    );

    test('keeps the stored days when they match the current schedule', () {
      final summerDate = DateTime(2026, 9, 18);
      final result = effectiveActiveDays({1, 3, 5, 7}, now: summerDate);

      expect(result, {1, 3, 5, 7});
    });
  });

  group('locationsForActiveDays', () {
    test(
      'is never empty in winter even with summer-only stored active days',
      () {
        final winterDate = DateTime(2026, 11, 15);
        final storedActiveDays = {5, 7};
        final effective = effectiveActiveDays(
          storedActiveDays,
          now: winterDate,
        );
        final locations = locationsForActiveDays(effective, now: winterDate);

        expect(locations, isNotEmpty);
      },
    );

    test('excludes indoor locations in winter', () {
      final winterDate = DateTime(2026, 11, 15);
      final locations = locationsForActiveDays({1, 2, 6}, now: winterDate);

      expect(locations.keys, contains('Landauer Brücke'));
      expect(
        locations.keys,
        isNot(contains('Evangelisches Schulzentrum (EvaSchulze)')),
      );
      expect(locations.keys, isNot(contains('TH "Am Rabet"')));
    });
  });

  group('forecastDaysPerLocation', () {
    test('does not request weather for the indoor Saturday location', () async {
      final winterDate = DateTime(2026, 11, 15);
      final result = await forecastDaysPerLocation({2, 6}, now: winterDate);

      expect(
        result.keys,
        isNot(contains('Evangelisches Schulzentrum (EvaSchulze)')),
      );
      expect(result.keys, contains('Landauer Brücke'));
    });
  });

  group('nextSessions (winter)', () {
    test('includes the manually activated Wednesday gym session', () async {
      final sessions = await nextSessions(
        DateTime(2026, 11, 16, 12),
        activeDays: {DateTime.wednesday},
        maxCount: 1,
      );

      expect(sessions.single.trainingName, 'Kraftraum RR-Bahn');
      expect(sessions.single.start, DateTime(2026, 11, 18, 18, 30));
      expect(sessions.single.end, DateTime(2026, 11, 18, 20, 30));
      expect(sessions.single.isIndoor, isTrue);
      expect(sessions.single.location.label, 'Kraftraum RR-Bahn');
      expect(sessions.single.location.label, 'Kraftraum RR-Bahn');
      expect(sessions.single.courses.single.category, 'Fitness');
      expect(sessions.single.courses.single.notes, ['Nur nach Voranmeldung']);
    });

    test('starts the 2026 EVS Saturday training on 7 November', () async {
      final sessions = await nextSessions(
        DateTime(2026, 10, 30),
        activeDays: {DateTime.saturday},
        maxCount: 5,
      );

      expect(sessions.map((session) => session.start), [
        DateTime(2026, 11, 7, 14),
        DateTime(2026, 11, 14, 14),
        DateTime(2026, 11, 21, 14),
      ]);
    });

    test('keeps the normal winter Saturday start in later years', () async {
      final sessions = await nextSessions(
        DateTime(2027, 10, 30),
        activeDays: {DateTime.saturday},
        maxCount: 1,
      );

      expect(sessions.single.start, DateTime(2027, 10, 30, 14));
    });

    test('marks the Tuesday outdoor training as non-indoor and Saturday sports-hall training as indoor', () async {
      final winterDate = DateTime(2026, 11, 16); // Monday
      final sessions = await nextSessions(
        winterDate,
        activeDays: {2, 6},
        maxCount: 5,
      );

      final tuesday = sessions.firstWhere((s) => s.start.weekday == 2);
      final saturday = sessions.firstWhere((s) => s.start.weekday == 6);

      expect(tuesday.isIndoor, isFalse);
      expect(saturday.isIndoor, isTrue);
    });
  });
}
