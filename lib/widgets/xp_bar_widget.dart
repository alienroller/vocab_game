import 'package:flutter/material.dart';

import '../services/xp_service.dart';

/// Displays the user's current level and XP progress within that level.
///
/// Shows a level badge, progress bar, and "X / Y XP" label.
class XpBarWidget extends StatelessWidget {
  final int totalXp;

  const XpBarWidget({super.key, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final int level = XpService.levelFromXp(totalXp);
    final double progress = XpService.levelProgressPercent(totalXp);
    final int xpInLevel = XpService.xpProgressInLevel(totalXp);
    final int xpNeeded = XpService.xpNeededForNextLevel(totalXp);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'Lvl $level',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$xpInLevel / $xpNeeded XP',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
          ),
        ),
      ],
    );
  }
}
