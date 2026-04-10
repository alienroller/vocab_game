import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/speaking_models.dart';

/// Feedback card displayed after Gemini evaluates an attempt.
///
/// Color psychology (from spec):
/// - "correct"   → Green  — safe, winning
/// - "partial"   → Amber  — growth mindset, not failure
/// - "incorrect" → Soft orange/salmon — NEVER harsh red
///   Red = shame. Orange = "almost, try again"
class FeedbackCard extends StatefulWidget {
  final EvaluationResult result;
  final StepOutcome? outcome;
  final VoidCallback? onContinue;

  const FeedbackCard({
    super.key,
    required this.result,
    this.outcome,
    this.onContinue,
  });

  @override
  State<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<FeedbackCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _FeedbackStyle get _style {
    final score = widget.result.score;
    if (score >= 0.85) return _FeedbackStyle.correct;
    if (score >= 0.5) return _FeedbackStyle.partial;
    return _FeedbackStyle.incorrect;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final style = _style;
    final result = widget.result;
    final outcome = widget.outcome;

    return AnimatedBuilder(
      listenable: _controller,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: Opacity(
          opacity: _fadeAnim.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? style.bgColor.withValues(alpha: 0.15)
                  : style.bgColor.withValues(alpha: 0.08),
              borderRadius: AppTheme.borderRadiusLg,
              border: Border.all(
                color: style.borderColor.withValues(alpha: isDark ? 0.4 : 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with score
                Row(
                  children: [
                    // Score circle
                    _ScoreCircle(score: result.score, color: style.accentColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: style.accentColor,
                            ),
                          ),
                          if (result.celebration != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              result.celebration!,
                              style: TextStyle(
                                fontSize: 13,
                                color: style.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // XP earned
                    if (outcome != null && outcome.xpEarned > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.xpGradient,
                          borderRadius: AppTheme.borderRadiusSm,
                        ),
                        child: Text(
                          '+${outcome.xpEarned} XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Feedback text
                Text(
                  result.feedback,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

                // Model answer
                if (result.modelAnswer != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: AppTheme.borderRadiusSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Example answer:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.modelAnswer!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Correct full sentence (for fill-the-gap)
                if (result.correctFullSentence != null &&
                    result.modelAnswer == null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: AppTheme.borderRadiusSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Correct sentence:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.correctFullSentence!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Hint from outcome
                if (outcome?.hint != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hint: ${outcome!.hint}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Continue button
                if (outcome?.action == StepAction.advance ||
                    outcome?.action == StepAction.showAnswerContinue) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: style.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        outcome?.action == StepAction.advance
                            ? 'Continue'
                            : 'Got it, continue',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Score Circle Widget ─────────────────────────────────────────────

class _ScoreCircle extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreCircle({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(score * 100).round()}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feedback Style ──────────────────────────────────────────────────

enum _FeedbackStyle {
  correct,
  partial,
  incorrect;

  String get title {
    switch (this) {
      case correct:
        return 'Great job! 🎉';
      case partial:
        return 'Almost there! 💪';
      case incorrect:
        return 'Keep trying! 🔄';
    }
  }

  Color get accentColor {
    switch (this) {
      case correct:
        return AppTheme.success;
      case partial:
        return AppTheme.amber;
      case incorrect:
        return const Color(0xFFFF9800); // Soft orange, never red
    }
  }

  Color get bgColor => accentColor;
  Color get borderColor => accentColor;
}

/// Reusable AnimatedWidget that rebuilds on any [Listenable] change.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
