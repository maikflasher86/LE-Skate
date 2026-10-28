import 'package:inliner2/utils/training_schedule.dart';

/// Returns true when [date] falls within the winter training season.
///
/// Winter runs from the last Monday of October through the last day of March.
/// Specifically: month >= 11, or month <= 3, or (month == 10 && day >= lastMondayOfOctober).
bool isWinterSeason(DateTime date) {
  final m = date.month;
  if (m >= 4 && m <= 9) return false;
  if (m >= 11 || m <= 3) return true;
  // month == 10: winter starts on the last Monday of October
  final lastMonday = _lastMondayOfOctober(date.year);
  return date.day >= lastMonday;
}

int _lastMondayOfOctober(int year) {
  // Start from Oct 31 and go back until we hit a Monday (weekday == 1).
  var d = DateTime(year, 10, 31);
  while (d.weekday != DateTime.monday) {
    d = d.subtract(const Duration(days: 1));
  }
  return d.day;
}

/// Returns the active schedule for [date] (summer or winter).
Map<int, ScheduleEntry> scheduleFor(DateTime date) =>
    isWinterSeason(date) ? winterSchedule : summerSchedule;

/// ISO calendar week of a date.
///
/// Computed on UTC calendar dates so DST shifts can't shorten the day
/// difference.
int isoWeekOf(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  final firstThursday = jan1.add(Duration(days: (4 - jan1.weekday + 7) % 7));
  return (thursday.difference(firstThursday).inDays / 7).floor() + 1;
}

bool _parityMatches(WeekParity parity, int isoWeek) {
  switch (parity) {
    case WeekParity.any:
      return true;
    case WeekParity.odd:
      return isoWeek.isOdd;
    case WeekParity.even:
      return isoWeek.isEven;
  }
}

/// Determines the category of a training session based on the active schedule.
///
/// - [TrainingCategory.regular] remains regular only if the week parity matches;
///   otherwise the session is automatically treated as [TrainingCategory.alternative].
/// - [TrainingCategory.alternative] and [TrainingCategory.special] are passed through as-is.
TrainingCategory categoryForDate(DateTime date) {
  final entry = scheduleFor(date)[date.weekday];
  if (entry == null) return TrainingCategory.alternative;
  switch (entry.category) {
    case TrainingCategory.regular:
      final matches = _parityMatches(entry.regularParity, isoWeekOf(date));
      return matches ? TrainingCategory.regular : TrainingCategory.alternative;
    case TrainingCategory.alternative:
      return TrainingCategory.alternative;
    case TrainingCategory.special:
      return TrainingCategory.special;
  }
}

bool isAlternativeTrainingDate(DateTime date) =>
    categoryForDate(date) == TrainingCategory.alternative;
