import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Premium leaderboard row with avatar initials, animated rank badges,
/// and glassmorphism card styling.
class LeaderboardRowWidget extends StatelessWidget {
  final int rank;
  final String username;
  final int level;
  final int score;
  final String scoreLabel;
  final bool isCurrentUser;
  final bool isHallOfFamer;
  final bool showChallengeButton;
  final VoidCallback? onChallenge;

  const LeaderboardRowWidget({
    super.key,
    required this.rank,
    required this.username,
    required this.level,
    required this.score,
    this.scoreLabel = 'XP',
    this.isCurrentUser = false,
    this.isHallOfFamer = false,
    this.showChallengeButton = false,
    this.onChallenge,
  });

  String get _medal => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '',
      };

  List<Color> get _avatarGradient => switch (rank) {
        1 => [const Color(0xFFFFD700), const Color(0xFFFFA000)],
        2 => [const Color(0xFFC0C0C0), const Color(0xFF9E9E9E)],
        3 => [const Color(0xFFCD7F32), const Color(0xFFA0522D)],
        _ => [AppTheme.violet, AppTheme.violetDark],
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: isCurrentUser
            ? LinearGradient(
                colors: [
                  AppTheme.violet.withValues(alpha: isDark ? 0.15 : 0.08),
                  AppTheme.violet.withValues(alpha: isDark ? 0.08 : 0.03),
                ],
              )
            : (isDark ? AppTheme.darkGlassGradient : AppTheme.lightGlassGradient),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.violet.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: rank <= 3
                  ? Text(_medal, style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center)
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 12),
            // Avatar circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _avatarGradient,
                ),
                boxShadow: rank <= 3
                    ? [
                        BoxShadow(
                          color: _avatarGradient.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Username + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: TextStyle(
                            fontWeight:
                                isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 15,
                            color: isCurrentUser
                                ? AppTheme.violet
                                : theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHallOfFamer) ...[
                        const SizedBox(width: 4),
                        const Text('🏆', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Level $level',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            // Challenge button
            if (showChallengeButton && !isCurrentUser) ...[
              IconButton(
                icon: Icon(Icons.sports_kabaddi,
                    color: AppTheme.fire.withValues(alpha: 0.8), size: 20),
                tooltip: 'Challenge to duel',
                onPressed: onChallenge,
              ),
            ],
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppTheme.violet.withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$score $scoreLabel',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isCurrentUser
                      ? AppTheme.violet
                      : AppTheme.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
