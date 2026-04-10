import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/speaking_models.dart';

/// The hero component — a large, animated microphone button with 7 states.
///
/// Each state has a distinct color, label, and animation.
/// Rule: the user must NEVER be unsure what the mic is doing.
class MicButton extends StatefulWidget {
  final MicState state;
  final VoidCallback? onTap;
  final double soundLevel;

  const MicButton({
    super.key,
    required this.state,
    this.onTap,
    this.soundLevel = 0.0,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == MicState.ready ||
        widget.state == MicState.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _bgColor(bool isDark) {
    switch (widget.state) {
      case MicState.idle:
        return isDark ? const Color(0xFF2A2D50) : const Color(0xFFE8E9F0);
      case MicState.ready:
        return AppTheme.violet;
      case MicState.countdown:
        return AppTheme.violet.withValues(alpha: 0.8);
      case MicState.recording:
        return const Color(0xFFFF4444);
      case MicState.processing:
        return AppTheme.violet.withValues(alpha: 0.6);
      case MicState.success:
        return AppTheme.success;
      case MicState.error:
        return const Color(0xFFFF9800);
    }
  }

  Color _glowColor() {
    switch (widget.state) {
      case MicState.ready:
        return AppTheme.violet.withValues(alpha: 0.4);
      case MicState.recording:
        return const Color(0xFFFF4444).withValues(alpha: 0.5);
      case MicState.success:
        return AppTheme.success.withValues(alpha: 0.4);
      case MicState.error:
        return const Color(0xFFFF9800).withValues(alpha: 0.4);
      default:
        return Colors.transparent;
    }
  }

  IconData _icon() {
    switch (widget.state) {
      case MicState.idle:
      case MicState.ready:
      case MicState.countdown:
        return Icons.mic_rounded;
      case MicState.recording:
        return Icons.stop_rounded;
      case MicState.processing:
        return Icons.hourglass_top_rounded;
      case MicState.success:
        return Icons.check_rounded;
      case MicState.error:
        return Icons.refresh_rounded;
    }
  }

  String _label() {
    switch (widget.state) {
      case MicState.idle:
        return '';
      case MicState.ready:
        return 'Tap to speak';
      case MicState.countdown:
        return 'Get ready...';
      case MicState.recording:
        return 'Listening...';
      case MicState.processing:
        return 'Evaluating...';
      case MicState.success:
        return '';
      case MicState.error:
        return 'Try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _label();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mic button
        GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () => _scaleController.reverse(),
          child: _AnimBuilder(
            listenable: Listenable.merge([_pulseController, _scaleController]),
            builder: (context, child) {
              final pulse = widget.state == MicState.ready ||
                      widget.state == MicState.recording
                  ? _pulseAnim.value
                  : 1.0;
              final scale = _scaleAnim.value * pulse;
              final soundExtra = widget.state == MicState.recording
                  ? (widget.soundLevel / 30.0).clamp(0.0, 0.15)
                  : 0.0;

              return Transform.scale(
                scale: scale + soundExtra,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bgColor(isDark),
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor(),
                        blurRadius: widget.state == MicState.recording
                            ? 30 + widget.soundLevel
                            : 20,
                        spreadRadius: widget.state == MicState.recording
                            ? 4 + (widget.soundLevel / 10)
                            : 2,
                      ),
                    ],
                  ),
                  child: widget.state == MicState.processing
                      ? const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Icon(
                          _icon(),
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              );
            },
          ),
        ),
        // Label
        if (label.isNotEmpty) ...[
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Reusable AnimatedWidget that rebuilds on any [Listenable] change.
class _AnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const _AnimBuilder({
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
