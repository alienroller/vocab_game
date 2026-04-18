import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../../application/lesson_runner_controller.dart';

/// Falou-style hero mic button.
///
/// One surface, five visual states:
/// - idle: violet, pulses gently to invite a tap
/// - listening: red, pulses aggressively while recording
/// - processing: spinner ring, input locked
/// - correct: green with a big check, triggers auto-advance
/// - retry: red outline, user can tap to try again
class FalouMicButton extends StatefulWidget {
  final AttemptState state;
  final VoidCallback? onTap;
  final double size;

  const FalouMicButton({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 96,
  });

  @override
  State<FalouMicButton> createState() => _FalouMicButtonState();
}

class _FalouMicButtonState extends State<FalouMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  AttemptState? _previous;

  @override
  void didUpdateWidget(covariant FalouMicButton old) {
    super.didUpdateWidget(old);
    if (_previous != widget.state) {
      _previous = widget.state;
      _fireHaptic(widget.state);
    }
  }

  void _fireHaptic(AttemptState state) {
    switch (state) {
      case AttemptState.listening:
        HapticFeedback.lightImpact();
      case AttemptState.correct:
        HapticFeedback.mediumImpact();
      case AttemptState.retry:
        HapticFeedback.heavyImpact();
      case AttemptState.idle:
      case AttemptState.processing:
        break;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final disabled =
        s == AttemptState.processing || s == AttemptState.correct;

    return GestureDetector(
      onTap: disabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final pulse = s == AttemptState.listening
              ? 1.0 + _ctrl.value * 0.12
              : s == AttemptState.idle
                  ? 1.0 + _ctrl.value * 0.04
                  : 1.0;
          return Transform.scale(
            scale: pulse,
            child: _buildSurface(s),
          );
        },
      ),
    );
  }

  Widget _buildSurface(AttemptState s) {
    final color = switch (s) {
      AttemptState.idle => AppTheme.violet,
      AttemptState.listening => AppTheme.error,
      AttemptState.processing => AppTheme.violetLight,
      AttemptState.correct => AppTheme.success,
      AttemptState.retry => AppTheme.error,
    };

    final icon = switch (s) {
      AttemptState.idle => Icons.mic_rounded,
      AttemptState.listening => Icons.mic_rounded,
      AttemptState.processing => null,
      AttemptState.correct => Icons.check_rounded,
      AttemptState.retry => Icons.refresh_rounded,
    };

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.95), color],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: s == AttemptState.listening ? 24 : 14,
            spreadRadius: s == AttemptState.listening ? 4 : 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: s == AttemptState.processing
          ? const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(icon, color: Colors.white, size: widget.size * 0.45),
    );
  }
}
