import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/profile_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/speaking_scenario.dart';
import '../../domain/models/speech_result.dart';

/// Celebratory completion screen: stats + primary CTA back to the
/// scenario list. XP gets recorded through the existing gamification
/// engine so streaks, badges and leaderboards update.
class ScenarioCompleteScreen extends ConsumerStatefulWidget {
  final SpeakingScenario scenario;
  final LessonStats stats;

  const ScenarioCompleteScreen({
    super.key,
    required this.scenario,
    required this.stats,
  });

  @override
  ConsumerState<ScenarioCompleteScreen> createState() =>
      _ScenarioCompleteScreenState();
}

class _ScenarioCompleteScreenState
    extends ConsumerState<ScenarioCompleteScreen> {
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordStats());
  }

  Future<void> _recordStats() async {
    if (_recorded) return;
    _recorded = true;
    final stats = widget.stats;
    if (stats.xpEarned <= 0) return;
    await ref.read(profileProvider.notifier).recordGameSession(
          xpGained: stats.xpEarned,
          totalQuestions: stats.phrasesAttempted,
          correctAnswers: stats.perfectPhrases,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = widget.stats;
    final accuracyPct = (stats.averageAccuracy * 100).round();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppTheme.successGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.shadowGlow(AppTheme.success),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Scenario complete!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.scenario.titleEn,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppTheme.darkGlassGradient
                        : AppTheme.lightGlassGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.violet
                          .withValues(alpha: isDark ? 0.22 : 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(
                            icon: Icons.bolt_rounded,
                            label: 'XP',
                            value: '+${stats.xpEarned}',
                            color: AppTheme.amberDark,
                          ),
                          _Stat(
                            icon: Icons.gps_fixed_rounded,
                            label: 'Accuracy',
                            value: '$accuracyPct%',
                            color: AppTheme.violet,
                          ),
                          _Stat(
                            icon: Icons.star_rounded,
                            label: 'Perfect',
                            value:
                                '${stats.perfectPhrases}/${stats.phrasesAttempted}',
                            color: AppTheme.successDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        color: AppTheme.violet.withValues(alpha: 0.15),
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(
                            icon: Icons.favorite_rounded,
                            label: 'Hearts lost',
                            value: '${stats.heartsLost}',
                            color: AppTheme.error,
                          ),
                          _Stat(
                            icon: Icons.timer_rounded,
                            label: 'Time',
                            value: _formatSeconds(stats.totalSeconds),
                            color: AppTheme.textSecondaryLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => context.go('/speaking'),
                    child: const Text('Back to scenarios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return '${m}m ${r}s';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
