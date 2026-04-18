import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Row of hearts shown during the recall phase.
///
/// Renders three slots; the rightmost `3 - hearts` turn grey to show losses.
class HeartsIndicator extends StatelessWidget {
  final int hearts;
  const HeartsIndicator({super.key, required this.hearts});

  @override
  Widget build(BuildContext context) {
    final lost = 3 - hearts.clamp(0, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              Icons.favorite_rounded,
              size: 22,
              color: i < (3 - lost)
                  ? AppTheme.error
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
