import 'package:flutter/material.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result emoji
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
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
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 32),

              // Score comparison
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('You',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '$myScore',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: didWin ? Colors.green : null,
                          ),
                        ),
                        Text('/ $totalWords'),
                      ],
                    ),
                    Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Column(
                      children: [
                        Text(opponentUsername,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '$opponentScore',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: !didWin && !isDraw ? Colors.red : null,
                          ),
                        ),
                        Text('/ $totalWords'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // XP gained
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '+$myXpGain XP',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
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
                  child: FilledButton.icon(
                    onPressed: () {
                      // Pop back to lobby to challenge again
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Rematch!',
                        style: TextStyle(fontSize: 18)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
