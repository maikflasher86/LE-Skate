import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inliner2/services/training_settings_service.dart';

void main() {
  final winterDate = DateTime(2026, 11, 15);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'does not migrate a legacy summer Wednesday selection to winter',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_training_days': ['3', '5', '7'],
      });

      expect(await TrainingSettingsService.loadActiveDays(now: winterDate), {
        1,
        2,
        4,
        6,
      });
    },
  );

  test('keeps a Wednesday selection explicitly saved for winter', () async {
    await TrainingSettingsService.saveActiveDays({3}, now: winterDate);

    expect(await TrainingSettingsService.loadActiveDays(now: winterDate), {3});
  });
}
