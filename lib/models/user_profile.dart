/// Local user profile — the source of truth during gameplay.
/// Supabase is the remote backup synced after each session.
///
/// Fields are stored individually in a Hive box ('userProfile')
/// via the ProfileNotifier provider.
class UserProfile {
  /// UUID — generated once on first launch, stored in SharedPreferences.
  late String id;

  /// Display name chosen during onboarding. Must be unique across all users.
  late String username;

  /// Total XP earned (never resets). Drives level and global leaderboard.
  int xp = 0;

  /// Current level, derived from XP but stored for fast access.
  int level = 1;

  /// Consecutive days played without missing a day.
  int streakDays = 0;

  /// ISO date string "YYYY-MM-DD" of the last game session.
  String? lastPlayedDate;

  /// 6-character class code from a teacher (e.g. "ENG7B").
  String? classCode;

  /// XP earned in the current calendar week. Resets every Monday.
  int weekXp = 0;

  /// Total vocabulary questions answered across all sessions.
  int totalWordsAnswered = 0;

  /// Total correct answers across all sessions.
  int totalCorrect = 0;

  /// Whether the user has completed the onboarding flow.
  bool hasOnboarded = false;

  /// Accuracy percentage (0.0–1.0).
  double get accuracy =>
      totalWordsAnswered > 0 ? totalCorrect / totalWordsAnswered : 0.0;
}
