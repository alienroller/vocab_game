import 'package:flutter/material.dart';

import '../services/streak_calculator.dart';
import '../theme/app_theme.dart';

/// Premium streak display with three visual states:
/// - **completedToday** — vibrant orange flame, pulsing animation.
/// - **atRisk** — amber flame, slow pulse, prompts the user to play today.
/// - **broken** — muted grey, no animation. Shows the longest-streak record
///   so the user still has something to chase.
class StreakWidget extends StatefulWidget {
  /// Live snapshot from `streakProvider` — the only thing this widget reads.
  final StreakSnapshot snapshot;

  const StreakWidget({super.key, required this.snapshot});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.status != oldWidget.snapshot.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final shouldAnimate = widget.snapshot.status != StreakStatus.broken;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = widget.snapshot.status;

    // Broken: show the user's longest streak as a "personal best" badge,
    // not their dead current streak.
    final isBroken = status == StreakStatus.broken;
    final count = isBroken ? widget.snapshot.longest : widget.snapshot.displayCount;
    final showLongestLabel = isBroken && widget.snapshot.longest > 0;

    final accent = switch (status) {
      StreakStatus.completedToday => AppTheme.fire,
      StreakStatus.atRisk => AppTheme.amber,
      StreakStatus.broken => isDark
          ? AppTheme.textSecondaryDark
          : AppTheme.textSecondaryLight,
    };

    final emoji = switch (status) {
      StreakStatus.completedToday => '🔥',
      StreakStatus.atRisk => '🔥',
      StreakStatus.broken => '💤',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: !isBroken
            ? LinearGradient(
                colors: [
                  accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  AppTheme.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                ],
              )
            : null,
        color: isBroken
            ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04))
            : null,
        borderRadius: BorderRadius.circular(24),
        border: !isBroken
            ? Border.all(color: accent.withValues(alpha: isDark ? 0.3 : 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: !isBroken
                ? _scaleAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: Text(
              emoji,
              style: TextStyle(fontSize: !isBroken ? 20 : 16),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            showLongestLabel ? 'best' : (count == 1 ? 'day' : 'days'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
