import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Animated "+N XP" text that floats upward and fades out with glow effect.
///
/// Triggers haptic feedback on appear.
class XpFloatWidget extends StatefulWidget {
  final int xp;

  const XpFloatWidget({super.key, required this.xp});

  @override
  State<XpFloatWidget> createState() => _XpFloatWidgetState();
}

class _XpFloatWidgetState extends State<XpFloatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_controller);

    _position = Tween(begin: Offset.zero, end: const Offset(0, -1.8)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.5, end: 1.2)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 50),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: ScaleTransition(
          scale: _scale,
          child: Text(
            '+${widget.xp} XP ⚡',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.amber,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  blurRadius: 12,
                  color: AppTheme.amber.withValues(alpha: 0.6),
                  offset: const Offset(0, 0),
                ),
                const Shadow(
                  blurRadius: 4,
                  color: Colors.black26,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
