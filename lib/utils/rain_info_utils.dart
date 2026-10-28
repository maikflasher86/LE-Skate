import 'package:inliner2/models/forecast_response.dart';
import 'package:inliner2/utils/date_utils.dart';
import 'package:intl/intl.dart';

/// Formats a rain event time relative to [now]: "heute/gestern/morgen HH:mm
/// Uhr", otherwise "dd.MM. HH:mm Uhr".
String formatRainTime(DateTime time, {required DateTime now}) {
  final today = dateOnly(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));
  final eventDay = dateOnly(time);
  final timeStr = DateFormat('HH:mm').format(time);
  if (eventDay == today) return 'heute $timeStr Uhr';
  if (eventDay == yesterday) return 'gestern $timeStr Uhr';
  if (eventDay == tomorrow) return 'morgen $timeStr Uhr';
  return '${DateFormat('dd.MM.').format(time)} $timeStr Uhr';
}

/// German intensity label for a rain amount in mm/h.
String rainIntensityLabel(double rainMm) => rainMm < 0.5
    ? 'leichter Regen'
    : rainMm < 2.0
    ? 'mäßiger Regen'
    : 'starker Regen';

/// Intensity, amount and (if known) source, e.g.
/// "leichter Regen (0.3 mm/h) · DWD".
String rainEventDetails(LastRainEvent event) {
  final intensity =
      '${rainIntensityLabel(event.rainMm)} (${event.rainMm.toStringAsFixed(1)} mm/h)';
  return event.source == null ? intensity : '$intensity · ${event.source}';
}

/// [event] if it lies in the past and at most 24 h before [now], else null.
/// Compared in UTC to avoid timezone bugs.
LastRainEvent? validLastRainEvent(
  LastRainEvent? event, {
  required DateTime now,
}) {
  if (event == null) return null;
  final nowUtc = now.toUtc();
  final time = event.time.toUtc();
  return time.isBefore(nowUtc) && nowUtc.difference(time).inHours <= 24
      ? event
      : null;
}

/// [event] if it lies after [now], else null. Compared in UTC.
LastRainEvent? validNextRainEvent(
  LastRainEvent? event, {
  required DateTime now,
}) {
  if (event == null) return null;
  return event.time.toUtc().isAfter(now.toUtc()) ? event : null;
}
