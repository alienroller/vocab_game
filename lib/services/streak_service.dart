import 'package:intl/intl.dart';

import '../models/user_profile.dart';

/// Manages daily streak tracking.
///
/// A streak increments when the user plays on consecutive calendar days.
/// It resets to 0 if they miss a day (or to 1 on their next play day).
///
/// Note: This service mutates the profile object in-place. The caller
/// (ProfileNotifier) is responsible for persisting changes to Hive.
class StreakService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  static String _today() => _dateFormat.format(DateTime.now());

  static String _yesterday() =>
      _dateFormat.format(DateTime.now().subtract(const Duration(days: 1)));

  /// Call this at the START of every game session (before showing questions).
  ///
  /// Returns `true` if the streak was just incremented (show a celebration).
  /// The caller must persist the profile after calling this.
  static bool checkAndUpdateStreak(UserProfile profile) {
    final String today = _today();
    final String? lastPlayed = profile.lastPlayedDate;

    if (lastPlayed == today) {
      // Already played today — streak is fine, do nothing
      return false;
    }

    if (lastPlayed == _yesterday()) {
      // Played yesterday — increment streak
      profile.streakDays += 1;
      profile.lastPlayedDate = today;
      return true; // show streak celebration
    }

    // Missed a day (or first time playing)
    profile.streakDays = 1; // reset to 1 (today counts)
    profile.lastPlayedDate = today;
    return false;
  }

  /// Call this ONCE when the app opens (in the root widget or splash screen)
  /// to detect if a streak was broken while the app was closed.
  /// The caller must persist the profile after calling this.
  static void checkStreakOnAppOpen(UserProfile profile) {
    final String today = _today();
    final String? lastPlayed = profile.lastPlayedDate;

    if (lastPlayed == null ||
        lastPlayed == today ||
        lastPlayed == _yesterday()) {
      // Fine — no action needed
      return;
    }

    // They missed more than 1 day — streak is broken
    profile.streakDays = 0;
  }

  /// Returns a milestone message if the streak hits a notable number.
  /// Returns null if no milestone was reached.
  static String? milestoneMessage(int streakDays) {
    return switch (streakDays) {
      3 => "You're on a roll! 🔥 3-day streak!",
      7 => 'One week strong! 💪 You\'re a habit now.',
      14 => 'Two weeks! 🏆 You\'re in the top players.',
      30 => 'One month! 👑 You are legendary.',
      _ => null,
    };
  }
}
