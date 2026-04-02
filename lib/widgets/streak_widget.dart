import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Premium streak display with gradient background and smooth animations.
class StreakWidget extends StatefulWidget {
  final int streakDays;

  const StreakWidget({super.key, required this.streakDays});

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

    if (widget.streakDays > 0) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streakDays > 0 && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.streakDays == 0 && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = widget.streakDays > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  AppTheme.fire.withValues(alpha: isDark ? 0.2 : 0.12),
                  AppTheme.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                ],
              )
            : null,
        color: isActive
            ? null
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(24),
        border: isActive
            ? Border.all(
                color: AppTheme.fire.withValues(alpha: isDark ? 0.3 : 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: isActive
                ? _scaleAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: Text(
              '🔥',
              style: TextStyle(fontSize: isActive ? 20 : 16),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.streakDays}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: isActive
                  ? AppTheme.fire
                  : (isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            widget.streakDays == 1 ? 'day' : 'days',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppTheme.fire.withValues(alpha: 0.8)
                  : (isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight),
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
