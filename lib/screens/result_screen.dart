import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import '../widgets/custom_button.dart';

/// Result screen shown after a game session.
///
/// Now integrates with the competitive system: displays XP earned,
/// syncs profile to Supabase, and cancels streak warnings.
class ResultScreen extends ConsumerStatefulWidget {
  final int score;
  final int total;
  final String gameName;
  final VoidCallback onPlayAgain;
  final int xpGained;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.gameName,
    required this.onPlayAgain,
    this.xpGained = 0,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _syncProfile();
  }

  Future<void> _syncProfile() async {
    if (_synced) return;
    _synced = true;

    final notifier = ref.read(profileProvider.notifier);

    // Single atomic call: adds XP + records per-word accuracy + syncs
    await notifier.recordGameSession(
      xpGained: widget.xpGained,
      totalQuestions: widget.total,
      correctAnswers: widget.score,
    );

    // Cancel streak warning — they played today
    await NotificationService.cancelStreakWarning();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = (widget.score / widget.total) >= 0.7;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gameName} Results'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'game_icon',
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isSuccess ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.emoji_events : Icons.thumb_up,
                    size: 64,
                    color: isSuccess ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isSuccess ? 'Great Job!' : 'Good Effort!',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You scored:',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '${widget.score} / ${widget.total}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              // XP gained display
              if (widget.xpGained > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt,
                          color: Colors.amber.shade700, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.xpGained} XP',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              // ─── Share Score (viral loop) ───────────────────
              if (widget.xpGained > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _shareScore,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Score'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              CustomButton(
                text: 'Play Again',
                icon: Icons.replay,
                isFullWidth: true,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onPlayAgain();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.list),
                label: const Text('Back to Games'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareScore() {
    final streakDays =
        Hive.box('userProfile').get('streakDays', defaultValue: 0) as int;
    final streakText = streakDays > 1 ? ' | 🔥 $streakDays-day streak!' : '';
    final text =
        '⚡ I just scored ${widget.score}/${widget.total} and earned '
        '+${widget.xpGained} XP on VocabGame!$streakText\n'
        'Try to beat me! 📚';
    Share.share(text);
  }
}
