import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_session.dart';
import 'package:inliner2/utils/training_locations.dart';

/// Classifies a training session.
///
/// - [regular]: regular session (core program)
/// - [alternative]: alternative session (only visible if toggle is active)
/// - [special]: special session with its own category (e.g. Cossi Training)
enum TrainingCategory { regular, alternative, special }

/// Describes in which calendar weeks a weekday is considered "regular".
enum WeekParity {
  /// Every week.
  any,

  /// Only odd weeks (1, 3, 5, ...).
  odd,

  /// Only even weeks (2, 4, 6, ...).
  even,
}

typedef _ScheduleEntry = ({
  String weekdayName,
  String trainingName,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
  Location location,
  TrainingCategory category,

  /// In which weeks [category] applies (default: any).
  /// Used for [TrainingCategory.regular]: Outside this parity,
  /// the appointment is automatically treated as [TrainingCategory.alternative].
  WeekParity regularParity,

  /// Optional badge label shown in the training-day planner UI.
  String? badgeLabel,

  /// How many days ahead weather data is needed for this weekday.
  /// Used to limit API requests (e.g. 1 for Cossi = only today needed).
  int forecastDays,
});

/// Public display info for one weekday, used by the training-day planner.
typedef ScheduleDayInfo = ({
  int weekday,
  String weekdayName,
  String trainingTime,
  String? badgeLabel,
  TrainingCategory category,
  WeekParity regularParity,
});

String _twoDigit(int n) => n.toString().padLeft(2, '0');

/// German weekday name for [DateTime.weekday] (1 = Montag … 7 = Sonntag).
const List<String> _weekdayNames = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

String _weekdayNameOf(DateTime date) => _weekdayNames[date.weekday - 1];

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
Map<int, _ScheduleEntry> _scheduleFor(DateTime date) =>
    isWinterSeason(date) ? _winterSchedule : _summerSchedule;

/// Returns display info for every weekday of the current season, ordered Mon–Sun.
List<ScheduleDayInfo> scheduleDayInfoList({DateTime? now}) {
  final schedule = _scheduleFor(now ?? DateTime.now());
  return schedule.entries
      .map(
        (e) => (
          weekday: e.key,
          weekdayName: e.value.weekdayName,
          trainingTime:
              '${_twoDigit(e.value.startHour)}:${_twoDigit(e.value.startMinute)}'
              ' – '
              '${_twoDigit(e.value.endHour)}:${_twoDigit(e.value.endMinute)}',
          badgeLabel: e.value.badgeLabel,
          category: e.value.category,
          regularParity: e.value.regularParity,
        ),
      )
      .toList();
}

/// Summer training data per weekday (April–last Monday of October).
const Map<int, _ScheduleEntry> _summerSchedule = {
  1: (
    weekdayName: 'Montag',
    trainingName: 'Cossi',
    startHour: 18,
    startMinute: 00, // Summer: 18:30
    endHour: 19,
    endMinute: 30, // Summer: 20:00
    location: cossiLocation,
    category: TrainingCategory.special,
    regularParity: WeekParity.any,
    badgeLabel: 'Cossi',
    forecastDays: 1, // Cossi training is always Monday – no multi-day forecast needed
  ),
  2: (
    weekdayName: 'Dienstag',
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
  ),
  3: (
    weekdayName: 'Mittwoch',
    trainingName: 'Technik',
    startHour: 19,
    startMinute: 0,
    endHour: 20,
    endMinute: 30,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Technik',
    forecastDays: 8,
  ),
  4: (
    weekdayName: 'Donnerstag',
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
  ),
  5: (
    weekdayName: 'Freitag',
    trainingName: 'Training',
    startHour: 19,
    startMinute: 0,
    endHour: 21,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.even,
    badgeLabel: 'gerade KW',
    forecastDays: 8,
  ),
  6: (
    weekdayName: 'Samstag',
    trainingName: 'Training',
    startHour: 10,
    startMinute: 0,
    endHour: 12,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.alternative,
    regularParity: WeekParity.any,
    badgeLabel: null,
    forecastDays: 8,
  ),
  7: (
    weekdayName: 'Sonntag',
    trainingName: 'Training',
    startHour: 10,
    startMinute: 0,
    endHour: 12,
    endMinute: 0,
    location: moeckernTrackLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.odd,
    badgeLabel: 'ungerade KW',
    forecastDays: 8,
  ),
};

/// A single event that is shown only once on a specific calendar date,
/// e.g. an external event or exhibition, independent of the weekday schedule
/// and the active-days toggle.
typedef _OneTimeEvent = ({
  int year,
  int month,
  int day,
  String title,
  String trainingName,
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
  Location location,
});

/// One-off special events. Add new entries here to show a single event on a
/// specific date; it disappears automatically once it is over.
const List<_OneTimeEvent> _oneTimeEvents = [
  (
    year: 2026,
    month: 9,
    day: 20,
    title: 'Porsche Event',
    trainingName: 'Porsche Event',
    startHour: 11,
    startMinute: 45,
    endHour: 17,
    endMinute: 0,
    location: porscheLocation,
  ),
];

/// Returns the `_oneTimeEvents` that are still relevant: not further away
/// than [windowDays] and not already over (today's event stays visible even
/// after its end time, mirroring the behavior of recurring sessions).
List<_OneTimeEvent> _relevantOneTimeEvents(
  DateTime now, {
  int windowDays = 28,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  return _oneTimeEvents.where((event) {
    final eventDay = DateTime(event.year, event.month, event.day);
    final daysAhead = eventDay.difference(todayStart).inDays;
    if (daysAhead < 0 || daysAhead > windowDays) return false;
    final end = DateTime(
      eventDay.year,
      eventDay.month,
      eventDay.day,
      event.endHour,
      event.endMinute,
    );
    if (end.isBefore(now) && daysAhead != 0) return false;
    return true;
  }).toList();
}

/// Winter training data per weekday (last Monday of October – end of March).
const Map<int, _ScheduleEntry> _winterSchedule = {
  2: (
    weekdayName: 'Dienstag',
    trainingName: 'Outdoor',
    startHour: 18,
    startMinute: 30,
    endHour: 19,
    endMinute: 30,
    location: landauerBrueckeLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Outdoor',
    forecastDays: 8,
  ),
  6: (
    weekdayName: 'Samstag',
    trainingName: 'Sporthalle',
    startHour: 14,
    startMinute: 0,
    endHour: 16,
    endMinute: 0,
    location: sporthalleEvsLocation,
    category: TrainingCategory.regular,
    regularParity: WeekParity.any,
    badgeLabel: 'Indoor',
    forecastDays: 8,
  ),
};

/// ISO calendar week of a date.
int isoWeekOf(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstThursday = DateTime(
    thursday.year,
    1,
    1,
  ).add(Duration(days: (4 - DateTime(thursday.year, 1, 1).weekday + 7) % 7));
  return ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
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
  final entry = _scheduleFor(date)[date.weekday];
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

bool isRegularTrainingDate(DateTime date) =>
    categoryForDate(date) == TrainingCategory.regular;

bool isSpecialTrainingDate(DateTime date) =>
    categoryForDate(date) == TrainingCategory.special;

/// Prefix used for the synthetic session id of one-time events (see
/// `_oneTimeEvents`). Used to recognize such sessions later in the pipeline
/// (e.g. JSON payload, UI) without relying on weekday/date-based rules,
/// which don't apply to one-off events.
const String oneTimeEventIdPrefix = 'event_';

/// Whether [id] (a [TrainingSession.id] / training id) belongs to a one-time
/// event. Such sessions are never "Alternativ" and are always shown,
/// independent of the "Alternative Trainings anzeigen" toggle.
bool isOneTimeEventId(String id) => id.startsWith(oneTimeEventIdPrefix);

/// Returns unique [Location]s (keyed by label) used by the given active
/// weekdays, plus the locations of any currently relevant one-time events
/// (those are shown regardless of the active-days toggle).
Map<String, Location> locationsForActiveDays(Set<int> activeDays, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final schedule = _scheduleFor(reference);
  final result = <String, Location>{};
  for (final day in activeDays) {
    final loc = schedule[day]?.location;
    if (loc != null) {
      result[loc.label] = loc;
    }
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
/// The [staticFallback] of the schedule entry is used when no sessions are
/// found, and the result is always capped at 8.
Map<String, int> forecastDaysPerLocation(
  Set<int> activeDays, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final todayStart = DateTime(
    reference.year,
    reference.month,
    reference.day,
  );

  // Use the same maxCount cap used elsewhere (14 sessions / 28-day window).
  final sessions = nextSessions(
    reference,
    activeDays: activeDays,
    maxCount: 14,
  );

  final result = <String, int>{};

  for (final session in sessions) {
    final label = session.location.label;
    final sessionDay = DateTime(
      session.start.year,
      session.start.month,
      session.start.day,
    );
    // forecast_days=1 covers today only; +1 for each extra calendar day.
    final required =
        sessionDay.difference(todayStart).inDays + 1;
    final current = result[label] ?? 0;
    if (required > current) result[label] = required;
  }

  // Fallback for locations that have no upcoming sessions in the window.
  for (final day in activeDays) {
    final entry = _scheduleFor(reference)[day];
    if (entry == null) continue;
    final label = entry.location.label;
    if (!result.containsKey(label)) {
      result[label] = entry.forecastDays;
    }
  }

  // Cap at 8 days (Open-Meteo free-tier limit).
  return result.map((k, v) => MapEntry(k, v.clamp(1, 8)));
}

/// Returns the next [maxCount] training sessions for active weekdays, plus
/// any currently relevant one-time events (see `_oneTimeEvents`). One-time
/// events are always included, independent of [activeDays].
List<TrainingSession> nextSessions(
  DateTime now, {
  required Set<int> activeDays,
  int maxCount = 5,
}) {
  final sessions = <TrainingSession>[];

  for (
    var daysAhead = 0;
    daysAhead <= 28 && sessions.length < maxCount;
    daysAhead++
  ) {
    final date = now.add(Duration(days: daysAhead));
    final weekday = date.weekday;
    if (!activeDays.contains(weekday)) continue;

    final entry = _scheduleFor(date)[weekday];
    if (entry == null) continue;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      entry.startHour,
      entry.startMinute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      entry.endHour,
      entry.endMinute,
    );

    // Keep today's session visible on the home page, even if training time is over.
    if (end.isBefore(now) && daysAhead != 0) continue;

    sessions.add(
      TrainingSession(
        id: 'day${weekday}_${date.toIso8601String().substring(0, 10)}',
        title: entry.weekdayName,
        trainingName: entry.trainingName,
        start: start,
        end: end,
        location: entry.location,
      ),
    );
  }

  for (final event in _relevantOneTimeEvents(now)) {
    final start = DateTime(
      event.year,
      event.month,
      event.day,
      event.startHour,
      event.startMinute,
    );
    final end = DateTime(
      event.year,
      event.month,
      event.day,
      event.endHour,
      event.endMinute,
    );
    sessions.add(
      TrainingSession(
        id: '$oneTimeEventIdPrefix${start.toIso8601String().substring(0, 10)}_${event.title}',
        title: _weekdayNameOf(start),
        trainingName: event.trainingName,
        start: start,
        end: end,
        location: event.location,
      ),
    );
  }

  sessions.sort((a, b) => a.start.compareTo(b.start));
  return sessions.length > maxCount
      ? sessions.sublist(0, maxCount)
      : sessions;
}
