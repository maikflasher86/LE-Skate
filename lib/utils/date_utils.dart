import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Truncates [dateTime] to midnight (year/month/day only), dropping the
/// time-of-day component. Useful for day-based comparisons such as
/// "how many days ahead is this?".
DateTime dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Formats a time of day as `HH:mm`.
String formatHourMinute(int hour, int minute) =>
    '${_twoDigits(hour)}:${_twoDigits(minute)}';

String formatDateTime(DateTime dateTime) =>
    DateFormat('dd.MM.yyyy HH:mm').format(dateTime.toLocal());

/// Formats a training time range as "dd.MM.yyyy HH:mm – HH:mm Uhr".
/// Both times are formatted as given (no timezone conversion).
String formatTrainingRange(
  DateTime start,
  DateTime end, {
  String separator = ' – ',
}) =>
    '${DateFormat('dd.MM.yyyy HH:mm').format(start)}$separator'
    '${DateFormat('HH:mm').format(end)} Uhr';

/// Whether `intl`'s `de_DE` locale data has been loaded in *this* isolate.
/// `compute()` spawns a fresh background isolate per call, which does not
/// share the initialization done in `main()`'s isolate, so this is tracked
/// (and lazily initialized) separately here.
bool _germanLocaleInitialized = false;

/// Ensures `intl`'s German locale data is loaded in the current isolate.
/// Call this once from `main()` so synchronous label lookups (e.g.
/// [weekdayLabel]) work right away in the UI isolate.
Future<void> ensureGermanLocaleInitialized() async {
  if (_germanLocaleInitialized) return;
  await initializeDateFormatting('de_DE');
  _germanLocaleInitialized = true;
}

/// German weekday name for [date] (e.g. "Montag"), via `intl`. Safe to call
/// from any isolate, including the background isolate spawned by `compute()`.
Future<String> weekdayNameOf(DateTime date) async {
  await ensureGermanLocaleInitialized();
  return DateFormat('EEEE', 'de_DE').format(date);
}

/// A fixed, arbitrary Monday used only to turn a bare weekday number into a
/// [DateTime] for [weekdayLabel]; the calendar date itself is irrelevant.
final DateTime _referenceMonday = DateTime(2024, 1, 1);

/// German label for [weekday] (matches [DateTime.weekday], e.g. 1 = "Montag").
///
/// Synchronous: requires the German locale to already be loaded in this
/// isolate (see [ensureGermanLocaleInitialized]), which `main()` guarantees
/// for the UI isolate. Use [weekdayNameOf] instead when a concrete [DateTime]
/// is available and the call may happen off the main isolate (e.g. inside
/// `compute()`).
String weekdayLabel(int weekday) => DateFormat(
  'EEEE',
  'de_DE',
).format(_referenceMonday.add(Duration(days: weekday - DateTime.monday)));
