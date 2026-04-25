import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';

/// Shared streak integration logic for all game screens.
///
/// This mixin does not mutate streak state — that lives entirely in
/// `ProfileNotifier._evaluateStreak()`, which is called from
/// `recordGameSession()`. This mixin only renders the milestone celebration.
mixin GameStreakMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  static String? _milestoneMessage(int streakDays) {
    return switch (streakDays) {
      3 => "You're on a roll! 🔥 3-day streak!",
      7 => "One week strong! 💪 You're a habit now.",
      14 => "Two weeks! 🏆 You're in the top players.",
      30 => 'One month! 👑 You are legendary.',
      _ => null,
    };
  }

  /// Shows a streak milestone celebration dialog if a milestone was just hit.
  /// Call after recordGameSession() to give the user visual feedback.
  void checkAndShowStreak() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // Only show celebration on milestone streaks
    final milestone = _milestoneMessage(profile.streakDays);
    if (milestone != null && mounted) {
      // Prevent showing the same milestone twice per session
      final box = Hive.box('userProfile');
      final lastMilestoneShown =
          box.get('lastMilestoneStreakShown', defaultValue: 0) as int;
      if (lastMilestoneShown >= profile.streakDays) return;
      box.put('lastMilestoneStreakShown', profile.streakDays);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  milestone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${profile.streakDays}-day streak!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep going! 💪'),
              ),
            ],
          ),
        );
      });
    }
  }

  /// Shows standard confirmation dialog when trying to exit an active game
  Future<bool?> showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Are you sure you want to quit? You will lose this game\'s progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }
}
