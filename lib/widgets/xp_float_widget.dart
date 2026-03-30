import 'package:flutter/material.dart';

/// Animated "+N XP" text that floats upward and fades out.
///
/// Position this over the answer area using a `Stack` and trigger it
/// after each correct answer by adding a new instance with a unique key.
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _position = Tween(begin: Offset.zero, end: const Offset(0, -1.5)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: Text(
          '+${widget.xp} XP',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(0, 1),
              ),
            ],
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
