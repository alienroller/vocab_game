import 'date_utils.dart';

/// Live state of a user's streak as observed at a given moment.
///
/// The streak number stored in Hive/Supabase is just history — the **active**
/// state must be derived from `lastPlayedDate` vs `today`. This enum captures
/// the three states a streak can be in right now.
enum StreakStatus {
  /// User played today. Streak is locked in for the day.
  completedToday,

  /// User played yesterday but not yet today. Streak is alive but at risk —
  /// will break if they don't play before midnight.
  atRisk,

  /// User missed a day (or has never played). The stored count is no longer
  /// valid; UI should display 0 or the longest-streak record instead.
  broken,
}

/// Snapshot of streak state to render in the UI.
class StreakSnapshot {
  /// The number to display. Equals stored `streakDays` when active or at risk;
  /// 0 when broken.
  final int displayCount;

  /// The user's all-time best streak.
  final int longest;

  /// Live state — drives icon color and the "play today!" banner.
  final StreakStatus status;

  const StreakSnapshot({
    required this.displayCount,
    required this.longest,
    required this.status,
  });
}

/// Pure, side-effect-free streak math. Used by both the read path
/// (UI display via `streakProvider`) and the write path
/// (`ProfileNotifier._evaluateStreak`).
class StreakCalculator {
  const StreakCalculator._();

  /// Computes the current streak state from stored history.
  ///
  /// - [storedStreakDays]: the count persisted at the last play (Hive/Supabase).
  /// - [lastPlayedDate]: ISO `YYYY-MM-DD` of the last game session, or null.
  /// - [longestStreak]: the user's all-time best.
  /// - [now]: the moment of evaluation (defaults to `DateTime.now()`).
  ///
  /// The returned `displayCount` is **derived**, not stored — so a stale Hive
  /// value can never paint an "alive" streak after the user missed a day.
  static StreakSnapshot evaluate({
    required int storedStreakDays,
    required String? lastPlayedDate,
    required int longestStreak,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final status = _statusFor(lastPlayedDate, today);
    final displayCount =
        status == StreakStatus.broken ? 0 : storedStreakDays;
    return StreakSnapshot(
      displayCount: displayCount,
      longest: longestStreak,
      status: status,
    );
  }

  /// Computes the new streak count after a play has just occurred.
  ///
  /// Idempotent within a calendar day: playing N games on the same day yields
  /// the same count as playing once.
  ///
  /// - Returns the same count if `lastPlayedDate == today`.
  /// - Returns `previous + 1` if last play was yesterday.
  /// - Returns `1` on first play, or after a missed day.
  static int nextStreakOnPlay({
    required int previousStreakDays,
    required String? lastPlayedDate,
    required DateTime now,
  }) {
    final todayStr = AppDateUtils.ymd(now);
    if (lastPlayedDate == todayStr) return previousStreakDays;
    if (lastPlayedDate == null) return 1;
    return _isYesterday(lastPlayedDate, now) ? previousStreakDays + 1 : 1;
  }

  static StreakStatus _statusFor(String? lastPlayedDate, DateTime now) {
    if (lastPlayedDate == null) return StreakStatus.broken;
    final todayStr = AppDateUtils.ymd(now);
    if (lastPlayedDate == todayStr) return StreakStatus.completedToday;
    return _isYesterday(lastPlayedDate, now)
        ? StreakStatus.atRisk
        : StreakStatus.broken;
  }

  /// Compares calendar dates, not 24-hour windows. Avoids `inDays` truncation
  /// surprises when a user plays late one night and early the next morning.
  static bool _isYesterday(String dateStr, DateTime now) {
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return dateStr == AppDateUtils.ymd(yesterday);
  }
}
