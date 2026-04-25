import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_game/services/streak_calculator.dart';

void main() {
  group('StreakCalculator.evaluate (read path)', () {
    test('null lastPlayedDate → broken, displayCount 0', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 0,
        lastPlayedDate: null,
        longestStreak: 0,
        now: DateTime(2026, 4, 25, 10),
      );
      expect(s.status, StreakStatus.broken);
      expect(s.displayCount, 0);
    });

    test('played today → completedToday, displayCount preserved', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 5,
        lastPlayedDate: '2026-04-25',
        longestStreak: 12,
        now: DateTime(2026, 4, 25, 18),
      );
      expect(s.status, StreakStatus.completedToday);
      expect(s.displayCount, 5);
      expect(s.longest, 12);
    });

    test('played yesterday → atRisk, displayCount preserved', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 4,
        lastPlayedDate: '2026-04-24',
        longestStreak: 4,
        now: DateTime(2026, 4, 25, 8),
      );
      expect(s.status, StreakStatus.atRisk);
      expect(s.displayCount, 4);
    });

    test('played 2 days ago → broken, displayCount 0', () {
      // Reproduces the user-reported bug: stored count of 4 must NOT show
      // when the streak has actually died.
      final s = StreakCalculator.evaluate(
        storedStreakDays: 4,
        lastPlayedDate: '2026-04-23',
        longestStreak: 4,
        now: DateTime(2026, 4, 25, 8),
      );
      expect(s.status, StreakStatus.broken);
      expect(s.displayCount, 0);
      expect(s.longest, 4);
    });

    test('played 30 days ago → broken regardless of stored count', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 99,
        lastPlayedDate: '2026-03-25',
        longestStreak: 99,
        now: DateTime(2026, 4, 25),
      );
      expect(s.status, StreakStatus.broken);
      expect(s.displayCount, 0);
    });

    test('time-of-day does not change status (calendar day, not 24h)', () {
      // Played 2026-04-24 at 11:55 PM. At 12:01 AM on 2026-04-25,
      // status must be atRisk (1 calendar day later, not "0 days" by .inDays).
      final s = StreakCalculator.evaluate(
        storedStreakDays: 3,
        lastPlayedDate: '2026-04-24',
        longestStreak: 3,
        now: DateTime(2026, 4, 25, 0, 1),
      );
      expect(s.status, StreakStatus.atRisk);
    });

    test('month boundary: yesterday is end of previous month', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 7,
        lastPlayedDate: '2026-03-31',
        longestStreak: 7,
        now: DateTime(2026, 4, 1, 9),
      );
      expect(s.status, StreakStatus.atRisk);
      expect(s.displayCount, 7);
    });

    test('year boundary: Dec 31 → Jan 1 is consecutive', () {
      final s = StreakCalculator.evaluate(
        storedStreakDays: 100,
        lastPlayedDate: '2025-12-31',
        longestStreak: 100,
        now: DateTime(2026, 1, 1, 10),
      );
      expect(s.status, StreakStatus.atRisk);
    });
  });

  group('StreakCalculator.nextStreakOnPlay (write path)', () {
    test('first time playing → 1', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 0,
        lastPlayedDate: null,
        now: DateTime(2026, 4, 25),
      );
      expect(n, 1);
    });

    test('idempotent: same day re-play returns previous', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 4,
        lastPlayedDate: '2026-04-25',
        now: DateTime(2026, 4, 25, 22),
      );
      expect(n, 4);
    });

    test('played yesterday → previous + 1', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 4,
        lastPlayedDate: '2026-04-24',
        now: DateTime(2026, 4, 25, 8),
      );
      expect(n, 5);
    });

    test('missed a day → resets to 1', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 9,
        lastPlayedDate: '2026-04-23',
        now: DateTime(2026, 4, 25),
      );
      expect(n, 1);
    });

    test('missed many days → resets to 1', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 50,
        lastPlayedDate: '2026-01-01',
        now: DateTime(2026, 4, 25),
      );
      expect(n, 1);
    });

    test('month boundary: played March 31, plays April 1 → +1', () {
      final n = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 6,
        lastPlayedDate: '2026-03-31',
        now: DateTime(2026, 4, 1, 9),
      );
      expect(n, 7);
    });
  });

  group('integration: read after write yields completedToday', () {
    test('play resets atRisk to completedToday with incremented count', () {
      const yesterday = '2026-04-24';
      final now = DateTime(2026, 4, 25, 14);

      // Before play: at risk with stored count 4.
      final before = StreakCalculator.evaluate(
        storedStreakDays: 4,
        lastPlayedDate: yesterday,
        longestStreak: 4,
        now: now,
      );
      expect(before.status, StreakStatus.atRisk);
      expect(before.displayCount, 4);

      // Apply write path.
      final next = StreakCalculator.nextStreakOnPlay(
        previousStreakDays: 4,
        lastPlayedDate: yesterday,
        now: now,
      );
      expect(next, 5);

      // After play: completed today with new count 5.
      final after = StreakCalculator.evaluate(
        storedStreakDays: next,
        lastPlayedDate: '2026-04-25',
        longestStreak: 5,
        now: now,
      );
      expect(after.status, StreakStatus.completedToday);
      expect(after.displayCount, 5);
    });
  });
}
