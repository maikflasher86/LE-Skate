import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/utils/session_utils.dart';
import 'package:inliner2/utils/training_schedule.dart';

void main() {
  group('isWinterSeason', () {
    // The last Monday of October 2026 is the 26th.
    test('is summer on the day before the last Monday of October', () {
      expect(isWinterSeason(DateTime(2026, 10, 25, 12)), isFalse);
    });

    test('is winter on the last Monday of October', () {
      expect(isWinterSeason(DateTime(2026, 10, 26)), isTrue);
    });

    test('is winter on 31 March', () {
      expect(isWinterSeason(DateTime(2026, 3, 31, 23, 59)), isTrue);
    });

    test('is summer on 1 April', () {
      expect(isWinterSeason(DateTime(2026, 4, 1)), isFalse);
    });

    test('is winter in November–February and summer in April–September', () {
      expect(isWinterSeason(DateTime(2026, 11, 15)), isTrue);
      expect(isWinterSeason(DateTime(2027, 1, 15)), isTrue);
      expect(isWinterSeason(DateTime(2026, 7, 15)), isFalse);
      expect(isWinterSeason(DateTime(2026, 9, 30)), isFalse);
    });
  });

  group('isoWeekOf', () {
    test('returns week 53 for years with 53 ISO weeks', () {
      expect(isoWeekOf(DateTime(2026, 12, 31)), 53);
      expect(isoWeekOf(DateTime(2020, 12, 31)), 53);
      // 1 January 2027 (Friday) still belongs to week 53 of 2026.
      expect(isoWeekOf(DateTime(2027, 1, 1)), 53);
    });

    test('returns week 1 at the start of the ISO year', () {
      expect(isoWeekOf(DateTime(2026, 1, 1)), 1);
      // Monday 30 December 2024 belongs to week 1 of 2025.
      expect(isoWeekOf(DateTime(2024, 12, 30)), 1);
    });

    test('returns the correct week for a summer date with a time of day', () {
      expect(isoWeekOf(DateTime(2026, 7, 5, 10)), 27);
      expect(isoWeekOf(DateTime(2026, 7, 10, 19)), 28);
    });

    test('returns the correct week for summer dates at midnight', () {
      // Regression: DST must not shift the result to the previous week.
      expect(isoWeekOf(DateTime(2026, 7, 1)), 27);
      expect(isoWeekOf(DateTime(2026, 6, 29)), 27);
      expect(isoWeekOf(DateTime(2026, 7, 6)), 28);
    });
  });

  group('categoryForDate', () {
    test('Wednesday Technik in summer is a regular day', () {
      expect(
        categoryForDate(DateTime(2026, 7, 8, 19)),
        TrainingCategory.regular,
      );
    });

    test('Friday in an even week is regular, in an odd week alternative', () {
      // 2026-07-10 is week 28, 2026-07-03 is week 27.
      expect(
        categoryForDate(DateTime(2026, 7, 10, 19)),
        TrainingCategory.regular,
      );
      expect(
        categoryForDate(DateTime(2026, 7, 3, 19)),
        TrainingCategory.alternative,
      );
    });

    test('Tuesday in summer is an alternative day', () {
      expect(
        categoryForDate(DateTime(2026, 7, 7, 19)),
        TrainingCategory.alternative,
      );
    });

    test('Monday Cossi in summer is a special day', () {
      expect(
        categoryForDate(DateTime(2026, 7, 6, 18)),
        TrainingCategory.special,
      );
    });

    test(
      'winter Monday is regular, a weekday without schedule is alternative',
      () {
        expect(
          categoryForDate(DateTime(2026, 11, 16, 18)),
          TrainingCategory.regular,
        );
        expect(
          categoryForDate(DateTime(2026, 11, 20, 18)),
          TrainingCategory.alternative,
        );
      },
    );
  });
}
