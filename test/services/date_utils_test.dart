import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_game/services/date_utils.dart';

void main() {
  group('AppDateUtils.isoWeekKey', () {
    test('Monday and Sunday of the same ISO week yield identical keys', () {
      // 2026-04-13 (Mon) and 2026-04-19 (Sun) → both ISO week 16.
      final monday = DateTime(2026, 4, 13);
      final sunday = DateTime(2026, 4, 19);
      expect(AppDateUtils.isoWeekKey(monday),
          AppDateUtils.isoWeekKey(sunday));
    });

    test('Sunday before a Monday yields an earlier week', () {
      // Sunday 2026-04-12 → week 15, Monday 2026-04-13 → week 16.
      expect(AppDateUtils.isoWeekKey(DateTime(2026, 4, 12)), '2026-W15');
      expect(AppDateUtils.isoWeekKey(DateTime(2026, 4, 13)), '2026-W16');
    });

    test('ISO year boundary: Jan 1 in previous ISO year', () {
      // 2023-01-01 is a Sunday and belongs to ISO week 52 of 2022.
      expect(AppDateUtils.isoWeekKey(DateTime(2023, 1, 1)), '2022-W52');
      // 2021-01-01 is a Friday in ISO week 53 of 2020.
      expect(AppDateUtils.isoWeekKey(DateTime(2021, 1, 1)), '2020-W53');
    });

    test('Leap-year mid-year week count', () {
      // 2024 is a leap year — pick a mid-year Wednesday and verify the key.
      expect(AppDateUtils.isoWeekKey(DateTime(2024, 7, 10)), '2024-W28');
    });

    test('key is stable across time-of-day', () {
      final morning = DateTime(2026, 4, 15, 6, 0);
      final night = DateTime(2026, 4, 15, 23, 59);
      expect(
        AppDateUtils.isoWeekKey(morning),
        AppDateUtils.isoWeekKey(night),
      );
    });
  });

  group('AppDateUtils.ymd', () {
    test('pads month and day', () {
      expect(AppDateUtils.ymd(DateTime(2026, 1, 3)), '2026-01-03');
      expect(AppDateUtils.ymd(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
