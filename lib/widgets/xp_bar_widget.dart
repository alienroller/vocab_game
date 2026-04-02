import 'package:flutter/material.dart';

import '../services/xp_service.dart';
import '../theme/app_theme.dart';

/// Animated gradient XP progress bar with level badge and glow effect.
class XpBarWidget extends StatefulWidget {
  final int totalXp;

  const XpBarWidget({super.key, required this.totalXp});

  @override
  State<XpBarWidget> createState() => _XpBarWidgetState();
}

class _XpBarWidgetState extends State<XpBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  double _oldProgress = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final progress = XpService.levelProgressPercent(widget.totalXp);
    _progressAnim = Tween(begin: 0.0, end: progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _oldProgress = progress;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(XpBarWidget old) {
    super.didUpdateWidget(old);
    if (old.totalXp != widget.totalXp) {
      final newProgress = XpService.levelProgressPercent(widget.totalXp);
      _progressAnim = Tween(begin: _oldProgress, end: newProgress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _oldProgress = newProgress;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int level = XpService.levelFromXp(widget.totalXp);
    final int xpInLevel = XpService.xpProgressInLevel(widget.totalXp);
    final int xpNeeded = XpService.xpNeededForNextLevel(widget.totalXp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppTheme.xpGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amber.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Lvl $level',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$xpInLevel / $xpNeeded XP',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Animated gradient progress bar
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (context, _) {
            final value = _progressAnim.value.clamp(0.0, 1.0);
            return Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: AppTheme.xpGradient,
                    boxShadow: value > 0.8
                        ? [
                            BoxShadow(
                              color: AppTheme.amber.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
