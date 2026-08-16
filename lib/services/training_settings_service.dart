import 'package:shared_preferences/shared_preferences.dart';

/// Manages active training days (1=Mon … 7=Sun).
class TrainingSettingsService {
  static const _key = 'active_training_days';
  static const _showAlternativesKey = 'show_alternative_trainings';

  /// Default activated week-days
  static const defaultDays = {1, 3, 5, 7};

  /// Default: show alternative trainings (Fri/Sun outside calendar week rule).
  static const defaultShowAlternatives = false;

  static Future<Set<int>> loadActiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored == null || stored.isEmpty) return Set<int>.from(defaultDays);
    return stored.map(int.parse).toSet();
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
