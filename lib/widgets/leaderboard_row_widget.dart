import 'package:flutter/material.dart';

/// A reusable leaderboard row widget with rank medal/number, username,
/// level badge, XP score, optional Hall of Fame trophy, and optional
/// challenge button.
///
/// Used across leaderboard tabs and the Hall of Fame screen.
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
        _ => '$rank',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 36,
          child: Center(
            child: Text(
              _medal,
              style: TextStyle(
                fontSize: rank <= 3 ? 24 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                username,
                style: TextStyle(
                  fontWeight:
                      isCurrentUser ? FontWeight.bold : FontWeight.normal,
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
        subtitle: Text('Level $level'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showChallengeButton && !isCurrentUser)
              IconButton(
                icon: Icon(Icons.sports_kabaddi,
                    color: Colors.red.shade400, size: 20),
                tooltip: 'Challenge to duel',
                onPressed: onChallenge,
              ),
            Text(
              '$score $scoreLabel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isCurrentUser ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
