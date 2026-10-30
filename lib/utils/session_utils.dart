import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_forecast.dart';
import 'package:inliner2/models/training_session.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/training_schedule.dart';

/// Maximum number of upcoming sessions considered for the forecast.
const int maxForecastSessions = 14;

/// How many days ahead upcoming sessions and one-time events are looked up.
const int _sessionLookaheadDays = 28;

/// Maximum Open-Meteo `forecast_days` (free-tier limit).
const int maxForecastDays = 8;

/// Winter runs from the last Monday of October through the last day of March.
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

/// Public display info for one weekday, used by the training-day planner.
typedef ScheduleDayInfo = ({
  int weekday,
  String trainingTime,
  String? badgeLabel,
  TrainingCategory category,
  WeekParity regularParity,
});

DateTime _at(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

/// Returns display info for every weekday of the current season, ordered Mon–Sun.
List<ScheduleDayInfo> scheduleDayInfoList({DateTime? now}) {
  final schedule = scheduleFor(now ?? DateTime.now());
  return schedule.entries
      .map(
        (e) => (
          weekday: e.key,
          trainingTime:
              '${formatHourMinute(e.value.startHour, e.value.startMinute)}'
              ' – '
              '${formatHourMinute(e.value.endHour, e.value.endMinute)}',
          badgeLabel: e.value.badgeLabel,
          category: e.value.category,
          regularParity: e.value.regularParity,
        ),
      )
      .toList();
}

/// Returns the [oneTimeEvents] that are still relevant: not further away
/// than [_sessionLookaheadDays] and not already over (today's event stays
/// visible even after its end time, mirroring the behavior of recurring
/// sessions).
List<OneTimeEvent> _relevantOneTimeEvents(DateTime now) {
  final todayStart = dateOnly(now);
  return oneTimeEvents.where((event) {
    final daysAhead = dateOnly(event.date).difference(todayStart).inDays;
    if (daysAhead < 0 || daysAhead > _sessionLookaheadDays) return false;
    final end = _at(event.date, event.endHour, event.endMinute);
    if (end.isBefore(now) && daysAhead != 0) return false;
    return true;
  }).toList();
}

/// Resolves the weekdays that are actually usable for the current season's
/// schedule.
///
/// The user's stored [activeDays] may not exist in the current season's
/// schedule. Without this fallback, that mismatch would leave no active days
/// or locations to fetch weather for. Registration-only sessions are excluded
/// from the fallback until the user activates them explicitly.
Set<int> effectiveActiveDays(Set<int> activeDays, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final schedule = scheduleFor(reference);
  final matching = activeDays.where(schedule.containsKey).toSet();
  if (matching.isNotEmpty) return matching;

  final regularDays = schedule.entries
      .where(
        (e) =>
            e.value.category != TrainingCategory.alternative &&
            !e.value.requiresRegistration,
      )
      .map((e) => e.key)
      .toSet();
  return regularDays.isNotEmpty ? regularDays : schedule.keys.toSet();
}

/// Returns unique [Location]s (keyed by label) used by the given active
/// weekdays, plus the locations of any currently relevant one-time events
/// (those are shown regardless of the active-days toggle).
///
/// Indoor-only trainings (see [ScheduleEntry]'s `isIndoor`) are excluded
/// since weather is irrelevant for them and no forecast is fetched for their
/// location.
Map<String, Location> locationsForActiveDays(
  Set<int> activeDays, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final schedule = scheduleFor(reference);
  final result = <String, Location>{};
  for (final day in activeDays) {
    final entry = schedule[day];
    final location = entry?.location;
    if (entry == null || entry.isIndoor || location == null) continue;
    result[location.label] = location;
  }
  for (final event in _relevantOneTimeEvents(reference)) {
    result[event.location.label] = event.location;
  }
  return result;
}

/// Returns the maximum forecast days required per location label,
/// computed dynamically from the actual upcoming session dates.
///
/// For each location the required value is:
///   (calendar days until the farthest session start) + 1
/// so that Open-Meteo's `forecast_days` parameter covers every session.
/// The schedule entry's `forecastDays` is used as a fallback for locations
/// without upcoming sessions, and the result is always capped at
/// [maxForecastDays]. Indoor sessions are skipped entirely since no forecast
/// is fetched for them.
Future<Map<String, int>> forecastDaysPerLocation(
  Set<int> activeDays, {
  DateTime? now,
}) async {
  final reference = now ?? DateTime.now();
  final todayStart = dateOnly(reference);

  final sessions = await nextSessions(
    reference,
    activeDays: activeDays,
    maxCount: maxForecastSessions,
  );

  final result = <String, int>{};

  for (final session in sessions) {
    final location = session.location;
    if (session.isIndoor || location == null) continue;
    final label = location.label;
    final sessionDay = dateOnly(session.start);
    // forecast_days=1 covers today only; +1 for each extra calendar day.
    final required = sessionDay.difference(todayStart).inDays + 1;
    final current = result[label] ?? 0;
    if (required > current) result[label] = required;
  }

  // Fallback for locations that have no upcoming sessions in the window.
  final schedule = scheduleFor(reference);
  for (final day in activeDays) {
    final entry = schedule[day];
    final location = entry?.location;
    if (entry == null || entry.isIndoor || location == null) continue;
    final label = location.label;
    if (!result.containsKey(label)) {
      result[label] = entry.forecastDays;
    }
  }

  return result.map((k, v) => MapEntry(k, v.clamp(1, maxForecastDays)));
}

/// The [trainings] to show: one-time events always, alternative trainings
/// only if [showAlternatives] is set, all others always.
List<TrainingForecast> visibleTrainings(
  List<TrainingForecast> trainings, {
  required bool showAlternatives,
}) {
  return trainings
      .where(
        (t) =>
            isOneTimeEventId(t.id) ||
            showAlternatives ||
            !isAlternativeTrainingDate(t.start),
      )
      .toList();
}

/// Returns the next [maxCount] training sessions for active weekdays, plus
/// any currently relevant one-time events (see [oneTimeEvents]). One-time
/// events are always included, independent of [activeDays].
Future<List<TrainingSession>> nextSessions(
  DateTime now, {
  required Set<int> activeDays,
  int maxCount = 5,
}) async {
  final sessions = <TrainingSession>[];
  final events = _relevantOneTimeEvents(now);

  // Dates on which a one-time event takes place replace the regular
  // weekday training for that date (e.g. the Sunday training doesn't take
  // place because of the Porsche Event), so no weather is fetched for it.
  final oneTimeEventDates = events.map((event) => dateOnly(event.date)).toSet();

  for (
    var daysAhead = 0;
    daysAhead <= _sessionLookaheadDays && sessions.length < maxCount;
    daysAhead++
  ) {
    final date = now.add(Duration(days: daysAhead));
    final weekday = date.weekday;
    if (!activeDays.contains(weekday)) continue;
    if (oneTimeEventDates.contains(dateOnly(date))) continue;

    // Looked up per date: the season may switch within the look-ahead window.
    final entry = scheduleFor(date)[weekday];
    if (entry == null) continue;
    if (date.isBefore(DateTime(2026, 11, 7)) &&
        isWinterSeason(date) &&
        entry.location == sporthalleEvsLocation) {
      continue;
    }

    final start = _at(date, entry.startHour, entry.startMinute);
    final end = _at(date, entry.endHour, entry.endMinute);

    // Keep today's session visible on the home page, even if training time is over.
    if (end.isBefore(now) && daysAhead != 0) continue;

    sessions.add(
      TrainingSession(
        id: 'day${weekday}_${date.toIso8601String().substring(0, 10)}',
        title: await weekdayNameOf(date),
        trainingName: entry.trainingName,
        start: start,
        end: end,
        location: entry.location,
        locationLabel: entry.location?.label ?? 'Unbekannt',
        isIndoor: entry.isIndoor,
        courses: entry.courses,
      ),
    );
  }

  for (final event in events) {
    final start = _at(event.date, event.startHour, event.startMinute);
    final end = _at(event.date, event.endHour, event.endMinute);
    sessions.add(
      TrainingSession(
        id: '$oneTimeEventIdPrefix${start.toIso8601String().substring(0, 10)}_${event.title}',
        title: await weekdayNameOf(start),
        trainingName: event.trainingName,
        start: start,
        end: end,
        location: event.location,
        locationLabel: event.location.label,
      ),
    );
  }

  sessions.sort((a, b) => a.start.compareTo(b.start));
  return sessions.length > maxCount ? sessions.sublist(0, maxCount) : sessions;
}
