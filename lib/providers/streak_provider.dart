import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/streak_calculator.dart';
import 'profile_provider.dart';

/// Single source of truth for streak state in the UI.
///
/// Derives the live `(displayCount, longest, status)` snapshot from the
/// stored `streakDays` + `lastPlayedDate` every time it's read. This is the
/// fix for the bug where a stored "4-day streak" kept showing on days the
/// user hadn't played: the count was correct in storage, but no one was
/// asking "is this streak still alive?" at render time.
///
/// **All UI code should consume this provider** rather than reading
/// `profile.streakDays` directly. Reading `streakDays` shows history,
/// not the live state.
final streakProvider = Provider<StreakSnapshot>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) {
    return const StreakSnapshot(
      displayCount: 0,
      longest: 0,
      status: StreakStatus.broken,
    );
  }
  return StreakCalculator.evaluate(
    storedStreakDays: profile.streakDays,
    lastPlayedDate: profile.lastPlayedDate,
    longestStreak: profile.longestStreak,
  );
});
