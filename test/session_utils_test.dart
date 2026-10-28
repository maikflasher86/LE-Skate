import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/utils/season_utils.dart';
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
        visibleTrainings([regular, alternative, event], showAlternatives: false),
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
      'falls back to the winter schedule when stored days are summer-only',
      () {
        // Mid-November: winter season, whose schedule defines Monday (1),
        // Tuesday (2), Thursday (4) and Saturday (6). The summer-only days
        // {3, 5, 7} don't match any winter day at all.
        final winterDate = DateTime(2026, 11, 15);
        final result = effectiveActiveDays({3, 5, 7}, now: winterDate);

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
        final storedActiveDays = {3, 5, 7};
        final effective = effectiveActiveDays(
          storedActiveDays,
          now: winterDate,
        );
        final locations = locationsForActiveDays(effective, now: winterDate);

        expect(locations, isNotEmpty);
      },
    );

    test(
      'excludes the indoor sports-hall locations in winter',
      () {
        final winterDate = DateTime(2026, 11, 15);
        final locations = locationsForActiveDays({1, 2, 6}, now: winterDate);

        expect(locations.keys, contains('Landauer Brücke'));
        expect(locations.keys, isNot(contains('Sporthalle EVS')));
        expect(locations.keys, isNot(contains('Sporthalle Rabet')));
      },
    );
  });

  group('forecastDaysPerLocation', () {
    test('does not request weather for the indoor Saturday location', () async {
      final winterDate = DateTime(2026, 11, 15);
      final result = await forecastDaysPerLocation({2, 6}, now: winterDate);

      expect(result.keys, isNot(contains('Sporthalle EVS')));
      expect(result.keys, contains('Landauer Brücke'));
    });
  });

  group('nextSessions (winter)', () {
    test(
      'marks the Tuesday outdoor training as non-indoor and Saturday sports-hall training as indoor',
      () async {
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
      },
    );
  });
}
