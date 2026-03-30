import 'package:flutter/material.dart';

/// Streak display widget with flame icon and day count.
///
/// Shows a pulsing animation when the streak is active (> 0 days).
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
    final isActive = widget.streakDays > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.orange.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: isActive ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
            child: Text(
              '🔥',
              style: TextStyle(fontSize: isActive ? 20 : 16),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.streakDays}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isActive
                  ? Colors.orange.shade800
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            widget.streakDays == 1 ? 'day' : 'days',
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? Colors.orange.shade700
                  : theme.colorScheme.onSurfaceVariant,
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
