import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Real-time speech-to-text display with a soft typing effect.
///
/// Shows the interim transcript as the user speaks, providing
/// visual feedback that the app is listening.
class LiveTranscript extends StatelessWidget {
  final String text;
  final bool isListening;
  final bool isFinal;

  const LiveTranscript({
    super.key,
    required this.text,
    required this.isListening,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (text.isEmpty && !isListening) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: text.isNotEmpty || isListening ? 1.0 : 0.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: AppTheme.borderRadiusMd,
          border: Border.all(
            color: isListening
                ? AppTheme.violet.withValues(alpha: 0.3)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            if (isListening && !isFinal) ...[
              const _ListeningDots(),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                text.isEmpty ? 'Listening...' : text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: isFinal ? FontStyle.normal : FontStyle.italic,
                  color: text.isEmpty
                      ? (isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated listening dots indicator.
class _ListeningDots extends StatefulWidget {
  const _ListeningDots();

  @override
  State<_ListeningDots> createState() => _ListeningDotsState();
}

class _ListeningDotsState extends State<_ListeningDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      listenable: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final t = (_controller.value - delay).clamp(0.0, 1.0);
          final scale = 0.6 + 0.4 * _bounce(t);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    AppTheme.violet.withValues(alpha: 0.3 + 0.7 * _bounce(t)),
              ),
            ),
          );
        }),
      ),
    );
  }

  double _bounce(double t) {
    if (t < 0.5) return 4 * t * t * t;
    return 1 - ((-2 * t + 2) * (-2 * t + 2) * (-2 * t + 2)) / 2;
  }
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
