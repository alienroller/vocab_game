import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_game/services/xp_service.dart';

/// Covers XpService — all pure Dart, no Flutter dependencies needed.
void main() {
  group('XpService.calculateXp', () {
    test('returns 0 for incorrect answers regardless of speed', () {
      expect(
        XpService.calculateXp(
          correct: false,
          secondsLeft: 20,
          maxSeconds: 20,
          streakDays: 30,
        ),
        0,
      );
    });

    test('base XP (10) with no speed and no streak bonus', () {
      // secondsLeft: 0 → no speed bonus. streak 0 → multiplier 1.
      expect(
        XpService.calculateXp(
          correct: true,
          secondsLeft: 0,
          maxSeconds: 20,
          streakDays: 0,
        ),
        10,
      );
    });

    test('instant answer at streak 0 → base + full speed bonus = 20', () {
      expect(
        XpService.calculateXp(
          correct: true,
          secondsLeft: 20,
          maxSeconds: 20,
          streakDays: 0,
        ),
        20,
      );
    });

    test('streak tiers multiply correctly: 7d=x2, 14d=x3, 30d=x4', () {
      int xpAt(int streak) => XpService.calculateXp(
            correct: true,
            secondsLeft: 10,
            maxSeconds: 20,
            streakDays: streak,
          );
      // base 10 + speed 5 = 15
      expect(xpAt(0), 15);
      expect(xpAt(6), 15); // still tier 1
      expect(xpAt(7), 30);
      expect(xpAt(13), 30); // still tier 2
      expect(xpAt(14), 45);
      expect(xpAt(29), 45); // still tier 3
      expect(xpAt(30), 60);
      expect(xpAt(999), 60); // cap at 4x
    });

    test('handles maxSeconds = 0 defensively (no divide-by-zero)', () {
      expect(
        XpService.calculateXp(
          correct: true,
          secondsLeft: 5,
          maxSeconds: 0,
          streakDays: 0,
        ),
        10, // base only — no bonus
      );
    });
  });

  group('XpService.levelFromXp', () {
    test('level progression follows (level-1)² × 50 curve', () {
      expect(XpService.levelFromXp(0), 1);
      expect(XpService.levelFromXp(49), 1);
      expect(XpService.levelFromXp(50), 2); // (2-1)² × 50 = 50
      expect(XpService.levelFromXp(199), 2);
      expect(XpService.levelFromXp(200), 3); // (3-1)² × 50 = 200
      expect(XpService.levelFromXp(449), 3);
      expect(XpService.levelFromXp(450), 4); // (4-1)² × 50 = 450
      expect(XpService.levelFromXp(800), 5); // (5-1)² × 50 = 800
    });

    test('xpRequiredForLevel matches curve', () {
      expect(XpService.xpRequiredForLevel(1), 0);
      expect(XpService.xpRequiredForLevel(2), 50);
      expect(XpService.xpRequiredForLevel(3), 200);
      expect(XpService.xpRequiredForLevel(10), 4050);
    });
  });

  group('XpService.levelProgressPercent', () {
    test('progress within a level is 0..1', () {
      expect(XpService.levelProgressPercent(0), 0.0);
      expect(XpService.levelProgressPercent(25), 0.5); // half of level 1 span
      expect(XpService.levelProgressPercent(50), closeTo(0.0, 0.0001));
    });
  });
}
