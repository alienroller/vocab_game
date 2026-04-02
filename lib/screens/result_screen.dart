import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Result screen with animated score ring, XP display, and confetti-like
/// celebration particles.
class ResultScreen extends ConsumerStatefulWidget {
  final int score;
  final int total;
  final String gameName;
  final String gameRoute;
  final int xpGained;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.gameName,
    required this.gameRoute,
    this.xpGained = 0,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with TickerProviderStateMixin {
  bool _synced = false;
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  late AnimationController _countCtrl;
  late Animation<int> _countAnim;
  late AnimationController _celebCtrl;

  @override
  void initState() {
    super.initState();
    _syncProfile();

    final percent = widget.score / widget.total;

    // Ring animation
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim = Tween(begin: 0.0, end: percent).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic),
    );

    // Score counter
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _countAnim = IntTween(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic),
    );

    // Celebration particles
    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ringCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _countCtrl.forward();
    });
    if (percent >= 0.7) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _celebCtrl.forward();
      });
    }
  }

  Future<void> _syncProfile() async {
    if (_synced) return;
    _synced = true;
    final notifier = ref.read(profileProvider.notifier);
    await notifier.recordGameSession(
      xpGained: widget.xpGained,
      totalQuestions: widget.total,
      correctAnswers: widget.score,
    );
    await NotificationService.cancelStreakWarning();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _countCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSuccess = (widget.score / widget.total) >= 0.7;

    final successColor = AppTheme.success;
    final tryAgainColor = AppTheme.amber;
    final accentColor = isSuccess ? successColor : tryAgainColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.gameName} Results'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Celebration particles
              if (isSuccess)
                AnimatedBuilder(
                  animation: _celebCtrl,
                  builder: (context, _) => CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _CelebrationPainter(
                      progress: _celebCtrl.value,
                      color1: AppTheme.violet,
                      color2: AppTheme.amber,
                      color3: AppTheme.success,
                    ),
                  ),
                ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Animated score ring
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: AnimatedBuilder(
                        animation: _ringAnim,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ScoreRingPainter(
                              progress: _ringAnim.value,
                              color: accentColor,
                              isDark: isDark,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSuccess ? '🏆' : '💪',
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedBuilder(
                                    animation: _countAnim,
                                    builder: (context, _) => Text(
                                      '${_countAnim.value}/${widget.total}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      isSuccess ? 'Great Job!' : 'Good Effort!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(widget.score / widget.total * 100).round()}% correct',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),

                    // XP gained
                    if (widget.xpGained > 0) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.amber.withValues(alpha: 0.15),
                              AppTheme.amber.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(
                              color: AppTheme.amber.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: AppTheme.amber, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              '+${widget.xpGained} XP',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Share
                    if (widget.xpGained > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: _shareScore,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share Score'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                          ),
                        ),
                      ),

                    // Play Again
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: AppTheme.borderRadiusMd,
                          boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                        ),
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.pushReplacement(widget.gameRoute),
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Play Again'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.borderRadiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Back to Home'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
    final text = '⚡ I just scored ${widget.score}/${widget.total} and earned '
        '+${widget.xpGained} XP on VocabGame!$streakText\n'
        'Try to beat me! 📚';
    Share.share(text);
  }
}

// ─── Score Ring Painter ───────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Progress arc
    final sweepAngle = 2 * pi * progress;
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + sweepAngle,
      colors: [color.withValues(alpha: 0.6), color],
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    // Glow at tip
    if (progress > 0.05) {
      final tipAngle = -pi / 2 + sweepAngle;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);

      canvas.drawCircle(
        Offset(tipX, tipY),
        6,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress;
}

// ─── Celebration Painter ──────────────────────────────────────────────

class _CelebrationPainter extends CustomPainter {
  final double progress;
  final Color color1, color2, color3;

  _CelebrationPainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final random = Random(42); // Fixed seed for consistent particles
    final colors = [color1, color2, color3, AppTheme.fire, AppTheme.amber];

    for (int i = 0; i < 30; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height * (0.3 + random.nextDouble() * 0.7);
      final drift = (random.nextDouble() - 0.5) * 100;

      final particleProgress = (progress * 1.5 - i * 0.02).clamp(0.0, 1.0);
      final opacity = particleProgress < 0.7
          ? 1.0
          : 1.0 - ((particleProgress - 0.7) / 0.3);

      final x = startX + drift * particleProgress;
      final y = startY + (endY - startY) * particleProgress;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity * 0.7)
        ..style = PaintingStyle.fill;

      final particleSize = 3.0 + random.nextDouble() * 5;
      if (i % 3 == 0) {
        canvas.drawCircle(Offset(x, y), particleSize, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(x, y),
                width: particleSize * 1.5,
                height: particleSize),
            Radius.circular(particleSize / 3),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) =>
      old.progress != progress;
}
