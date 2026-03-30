import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/profile_provider.dart';
import '../services/xp_service.dart';
import '../widgets/xp_bar_widget.dart';
import '../widgets/streak_widget.dart';

/// User profile screen showing stats, XP details, streak, and class info.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final profileBox = Hive.box('userProfile');
    final theme = Theme.of(context);

    final username =
        profile?.username ?? profileBox.get('username', defaultValue: '') as String;
    final xp = profile?.xp ?? profileBox.get('xp', defaultValue: 0) as int;
    final level =
        profile?.level ?? profileBox.get('level', defaultValue: 1) as int;
    final streakDays =
        profile?.streakDays ?? profileBox.get('streakDays', defaultValue: 0) as int;
    final classCode = profile?.classCode ?? profileBox.get('classCode') as String?;
    final totalAnswered = profile?.totalWordsAnswered ??
        profileBox.get('totalWordsAnswered', defaultValue: 0) as int;
    final totalCorrect = profile?.totalCorrect ??
        profileBox.get('totalCorrect', defaultValue: 0) as int;
    final accuracy =
        totalAnswered > 0 ? (totalCorrect / totalAnswered * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── Avatar & Username ──────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              username,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (classCode != null && classCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Class: $classCode',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ─── XP Bar ─────────────────────────────────────────
            XpBarWidget(totalXp: xp),
            const SizedBox(height: 24),

            // ─── Streak ─────────────────────────────────────────
            StreakWidget(streakDays: streakDays),
            const SizedBox(height: 32),

            // ─── Stats Cards ────────────────────────────────────
            Row(
              children: [
                _StatCard(
                  icon: Icons.star,
                  label: 'Level',
                  value: '$level',
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.bolt,
                  label: 'Total XP',
                  value: '$xp',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.check_circle,
                  label: 'Accuracy',
                  value: '$accuracy%',
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.quiz,
                  label: 'Answered',
                  value: '$totalAnswered',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── XP Level Progress Details ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      'Current: Level $level (${XpService.xpRequiredForLevel(level)} XP)'),
                  Text(
                      'Next: Level ${level + 1} (${XpService.xpRequiredForLevel(level + 1)} XP)'),
                  Text(
                      'Remaining: ${XpService.xpNeededForNextLevel(xp) - XpService.xpProgressInLevel(xp)} XP'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
