import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../services/streak_service.dart';

/// Shared streak integration logic for all game screens.
///
/// Call [checkAndShowStreak] in `initState` of any game screen
/// to update the streak and optionally show a milestone celebration.
mixin GameStreakMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Checks the streak, persists changes, and shows a milestone dialog if hit.
  void checkAndShowStreak() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final oldStreak = profile.streakDays;
    final oldDate = profile.lastPlayedDate;

    final incremented = StreakService.checkAndUpdateStreak(profile);

    // Persist whenever the profile was actually modified
    final changed =
        profile.streakDays != oldStreak || profile.lastPlayedDate != oldDate;
    if (changed) {
      // Persist to Hive
      final box = Hive.box('userProfile');
      box.put('streakDays', profile.streakDays);
      box.put('lastPlayedDate', profile.lastPlayedDate);
      ref.read(profileProvider.notifier).updateStreak(
            profile.streakDays,
            profile.lastPlayedDate ?? '',
          );
    }

    // Show milestone celebration if the streak continued
    if (incremented) {
      final milestone = StreakService.milestoneMessage(profile.streakDays);
      if (milestone != null && mounted) {
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
