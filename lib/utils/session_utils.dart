import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_session.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:inliner2/utils/training_locations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

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
  String trainingTime,
  String? badgeLabel,
  TrainingCategory category,
  WeekParity regularParity,
});

String _twoDigit(int n) => n.toString().padLeft(2, '0');

/// Whether `intl`'s `de_DE` locale data has been loaded in *this* isolate.
/// `compute()` spawns a fresh background isolate per call, which does not
/// share the initialization done in `main()`'s isolate, so this is tracked
/// (and lazily initialized) separately here.
bool _germanLocaleInitialized = false;

Future<void> _ensureGermanLocaleInitialized() async {
  if (_germanLocaleInitialized) return;
  await initializeDateFormatting('de_DE');
  _germanLocaleInitialized = true;
}

/// Ensures `intl`'s German locale data is loaded in the current isolate.
/// Call this once from `main()` so synchronous label lookups (e.g.
/// [weekdayLabel]) work right away in the UI isolate.
Future<void> ensureGermanLocaleInitialized() => _ensureGermanLocaleInitialized();

/// German weekday name for [date] (e.g. "Montag"), via `intl`. Safe to call
/// from any isolate, including the background isolate spawned by `compute()`.
Future<String> _weekdayNameOf(DateTime date) async {
  await _ensureGermanLocaleInitialized();
  return DateFormat('EEEE', 'de_DE').format(date);
}

/// A fixed, arbitrary Monday used only to turn a bare weekday number into a
/// [DateTime] for [weekdayLabel]; the calendar date itself is irrelevant.
final DateTime _referenceMonday = DateTime(2024, 1, 1);

/// German label for [weekday] (matches [DateTime.weekday], e.g. 1 = "Montag").
///
/// Synchronous: requires the German locale to already be loaded in this
/// isolate (see [ensureGermanLocaleInitialized]), which `main()` guarantees
/// for the UI isolate. Use [_weekdayNameOf] instead when a concrete [DateTime]
/// is available and the call may happen off the main isolate (e.g. inside
/// `compute()`).
String weekdayLabel(int weekday) => DateFormat(
  'EEEE',
  'de_DE',
).format(_referenceMonday.add(Duration(days: weekday - DateTime.monday)));

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
    // Monday
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
    // Tuesday
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
    // Wednesday
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
    // Thursday
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
    // Friday
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
    // Saturday
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
    // Sunday
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
  DateTime date,
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
final List<_OneTimeEvent> _oneTimeEvents = [
  (
    date: DateTime(2026, 9, 20),
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
  final todayStart = dateOnly(now);
  return _oneTimeEvents.where((event) {
    final eventDay = dateOnly(event.date);
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
    // Tuesday
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
    // Saturday
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

/// Resolves the weekdays that are actually usable for the current season's
/// schedule.
///
/// The user's stored [activeDays] (e.g. the summer default `{1, 3, 5, 7}`)
/// may not exist at all in the other season's schedule (winter only defines
/// Tuesday and Saturday). Without this fallback that mismatch would leave
/// zero active days, and in turn zero locations to fetch weather for, e.g.
/// right after the season switches to winter. In that case, fall back to
/// the current season's own regular (non-alternative) training days instead
/// of ending up with no data at all.
Set<int> effectiveActiveDays(Set<int> activeDays, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final schedule = _scheduleFor(reference);
  final matching = activeDays.where(schedule.containsKey).toSet();
  if (matching.isNotEmpty) return matching;

  final regularDays = schedule.entries
      .where((e) => e.value.category != TrainingCategory.alternative)
      .map((e) => e.key)
      .toSet();
  return regularDays.isNotEmpty ? regularDays : schedule.keys.toSet();
}

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
Future<Map<String, int>> forecastDaysPerLocation(
  Set<int> activeDays, {
  DateTime? now,
}) async {
  final reference = now ?? DateTime.now();
  final todayStart = dateOnly(reference);

  // Use the same maxCount cap used elsewhere (14 sessions / 28-day window).
  final sessions = await nextSessions(
    reference,
    activeDays: activeDays,
    maxCount: 14,
  );

  final result = <String, int>{};

  for (final session in sessions) {
    final label = session.location.label;
    final sessionDay = dateOnly(session.start);
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
Future<List<TrainingSession>> nextSessions(
  DateTime now, {
  required Set<int> activeDays,
  int maxCount = 5,
}) async {
  final sessions = <TrainingSession>[];

  // Dates on which a one-time event takes place replace the regular
  // weekday training for that date (e.g. the Sunday training doesn't take
  // place because of the Porsche Event), so no weather is fetched for it.
  final oneTimeEventDates = _relevantOneTimeEvents(
    now,
  ).map((event) => dateOnly(event.date)).toSet();

  for (
    var daysAhead = 0;
    daysAhead <= 28 && sessions.length < maxCount;
    daysAhead++
  ) {
    final date = now.add(Duration(days: daysAhead));
    final weekday = date.weekday;
    if (!activeDays.contains(weekday)) continue;
    if (oneTimeEventDates.contains(dateOnly(date))) continue;

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
        title: await _weekdayNameOf(date),
        trainingName: entry.trainingName,
        start: start,
        end: end,
        location: entry.location,
      ),
    );
  }

  for (final event in _relevantOneTimeEvents(now)) {
    final start = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.startHour,
      event.startMinute,
    );
    final end = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.endHour,
      event.endMinute,
    );
    sessions.add(
      TrainingSession(
        id: '$oneTimeEventIdPrefix${start.toIso8601String().substring(0, 10)}_${event.title}',
        title: await _weekdayNameOf(start),
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
