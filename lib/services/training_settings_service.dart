import 'package:inliner2/utils/session_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages active training days (1=Mon … 7=Sun).
class TrainingSettingsService {
  static const _key = 'active_training_days';
  static const _winterDaysKey = 'active_training_days_winter';
  static const _showAlternativesKey = 'show_alternative_trainings';

  /// Default activated week-days in the summer season.
  static const defaultDays = {1, 3, 5, 7};

  /// Default activated week-days in the winter season (Mon, Thu).
  static const defaultWinterDays = {1, 4};

  /// Default: hide alternative trainings (Fri/Sun outside calendar week rule).
  static const defaultShowAlternatives = false;

  static Set<int> defaultDaysFor(DateTime date) =>
      Set<int>.from(isWinterSeason(date) ? defaultWinterDays : defaultDays);

  static Future<Set<int>> loadActiveDays({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final isWinter = isWinterSeason(reference);
    final winterDays = isWinter ? prefs.getStringList(_winterDaysKey) : null;
    final days = (winterDays ?? prefs.getStringList(_key) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    if (isWinter && winterDays == null) {
      days.removeWhere(
        (day) => scheduleFor(reference)[day]?.requiresRegistration ?? false,
      );
    }
    return effectiveActiveDays(
      days.isEmpty ? defaultDaysFor(reference) : days,
      now: reference,
    );
  }

  static Future<void> saveActiveDays(Set<int> days, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final values = days.map((d) => '$d').toList();
    await prefs.setStringList(_key, values);
    if (isWinterSeason(now ?? DateTime.now())) {
      await prefs.setStringList(_winterDaysKey, values);
    }
  }

  static Future<bool> loadShowAlternatives() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAlternativesKey) ?? defaultShowAlternatives;
  }

  static Future<void> saveShowAlternatives(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAlternativesKey, value);
  }
}
