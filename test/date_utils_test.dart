import 'package:flutter_test/flutter_test.dart';
import 'package:inliner2/utils/date_utils.dart';

void main() {
  group('formatTrainingRange', () {
    test('formats start date/time and end time', () {
      expect(
        formatTrainingRange(
          DateTime(2026, 11, 21, 14),
          DateTime(2026, 11, 21, 16, 5),
        ),
        '21.11.2026 14:00 – 16:05 Uhr',
      );
    });

    test('supports a custom separator', () {
      expect(
        formatTrainingRange(
          DateTime(2026, 7, 5, 9),
          DateTime(2026, 7, 5, 11),
          separator: '  –  ',
        ),
        '05.07.2026 09:00  –  11:00 Uhr',
      );
    });
  });
}
