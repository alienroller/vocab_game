/// XP calculation, level progression, and XP bar helpers.
///
/// XP is earned after every correct answer. Speed bonus rewards fast answers.
/// Streak multiplier rewards consecutive daily play.
/// Level is derived from total XP using a quadratic curve.
class XpService {
  // ─── XP Calculation ───────────────────────────────────────────────

  /// Calculates XP earned for a single question answer.
  ///
  /// [correct] — whether the student answered correctly.
  /// [secondsLeft] — seconds remaining on the timer when they answered.
  /// [maxSeconds] — total timer length for one question (e.g. 20).
  /// [streakDays] — the user's current consecutive day streak.
  ///
  /// Returns 0 for incorrect answers, base+speed+streak for correct ones.
  static int calculateXp({
    required bool correct,
    required int secondsLeft,
    required int maxSeconds,
    required int streakDays,
  }) {
    if (!correct) return 0;

    const int baseXp = 10;

    // Speed bonus: 0 (answered at last second) to 10 (instant answer)
    final double speedRatio =
        maxSeconds > 0 ? secondsLeft / maxSeconds : 0.0;
    final int speedBonus = (speedRatio * 10).round();

    // Streak multiplier
    final int streakMultiplier = _streakMultiplier(streakDays);

    return (baseXp + speedBonus) * streakMultiplier;
  }

  static int _streakMultiplier(int streakDays) {
    if (streakDays >= 30) return 4;
    if (streakDays >= 14) return 3;
    if (streakDays >= 7) return 2;
    return 1;
  }

  // ─── Level System ─────────────────────────────────────────────────

  /// Returns the level for a given total XP.
  ///
  /// Quadratic curve: Level 1 = 0 XP, Level 2 = 50 XP, Level 3 = 200 XP,
  /// Level 4 = 450 XP, Level 5 = 800 XP, etc.
  /// Each level requires: (level-1)² × 50 total XP.
  static int levelFromXp(int xp) {
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// Total XP needed to REACH a given level from zero.
  static int xpRequiredForLevel(int level) {
    return (level - 1) * (level - 1) * 50;
  }

  /// XP earned within the current level (for the progress bar fill).
  static int xpProgressInLevel(int totalXp) {
    final int currentLevel = levelFromXp(totalXp);
    final int xpAtCurrentLevel = xpRequiredForLevel(currentLevel);
    return totalXp - xpAtCurrentLevel;
  }

  /// Total XP span of the current level.
  static int xpNeededForNextLevel(int totalXp) {
    final int currentLevel = levelFromXp(totalXp);
    return xpRequiredForLevel(currentLevel + 1) -
        xpRequiredForLevel(currentLevel);
  }

  /// Progress within the current level as a 0.0–1.0 fraction.
  static double levelProgressPercent(int totalXp) {
    final needed = xpNeededForNextLevel(totalXp);
    if (needed <= 0) return 1.0;
    return xpProgressInLevel(totalXp) / needed;
  }
}
