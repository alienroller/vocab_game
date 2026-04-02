import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Duel results screen — shown after both players finish.
///
/// Displays winner/loser, scores, XP gained, and rematch option.
class DuelResultsScreen extends StatelessWidget {
  final int myScore;
  final int opponentScore;
  final int totalWords;
  final int myXpGain;
  final bool didWin;
  final bool isDraw;
  final String opponentUsername;

  const DuelResultsScreen({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.totalWords,
    required this.myXpGain,
    required this.didWin,
    required this.isDraw,
    required this.opponentUsername,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String title;
    final String emoji;
    final Color accentColor;

    if (isDraw) {
      title = "It's a Draw!";
      emoji = '🤝';
      accentColor = Colors.orange;
    } else if (didWin) {
      title = 'You Won!';
      emoji = '🏆';
      accentColor = Colors.green;
    } else {
      title = 'You Lost';
      emoji = '😤';
      accentColor = Colors.red;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result emoji with gradient ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.3),
                      accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 32),

              // Score comparison — glass card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.glassCard(isDark: isDark),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('You',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          '$myScore',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: didWin ? AppTheme.success : null,
                          ),
                        ),
                        Text('/ $totalWords',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            )),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.fireGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'VS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(opponentUsername,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          '$opponentScore',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: !didWin && !isDraw ? AppTheme.error : null,
                          ),
                        ),
                        Text('/ $totalWords',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // XP gained — gradient badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                      AppTheme.amber.withValues(alpha: isDark ? 0.08 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: AppTheme.amber, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '+$myXpGain XP',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Rematch button (for loser or draw)
              if (!didWin || isDraw) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.fireGradient,
                      borderRadius: AppTheme.borderRadiusMd,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.fire.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.replay),
                      label: const Text('Rematch!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Back to Home
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
