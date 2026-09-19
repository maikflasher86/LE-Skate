import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/utils/session_utils.dart';

void main() {
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
}
