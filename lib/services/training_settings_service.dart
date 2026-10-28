import 'package:inliner2/utils/session_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages active training days (1=Mon … 7=Sun).
class TrainingSettingsService {
  static const _key = 'active_training_days';
  static const _showAlternativesKey = 'show_alternative_trainings';

  /// Default activated week-days in the summer season.
  static const defaultDays = {1, 3, 5, 7};

  /// Default activated week-days in the winter season (Mon, Thu).
  static const defaultWinterDays = {1, 4};

  /// Default: hide alternative trainings (Fri/Sun outside calendar week rule).
  static const defaultShowAlternatives = false;

  static Set<int> defaultDaysFor(DateTime date) => Set<int>.from(
    isWinterSeason(date) ? defaultWinterDays : defaultDays,
  );

  static Future<Set<int>> loadActiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_key) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    return days.isEmpty ? defaultDaysFor(DateTime.now()) : days;
  }

  static Future<void> saveActiveDays(Set<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, days.map((d) => '$d').toList());
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
