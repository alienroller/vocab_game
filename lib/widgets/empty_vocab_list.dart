import 'package:flutter/material.dart';
import 'package:vocab_game/theme/app_theme.dart';

class EmptyVocabList extends StatelessWidget {
  const EmptyVocabList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.violet.withValues(alpha: isDark ? 0.1 : 0.06),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: AppTheme.violet.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No vocabulary yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the + button to add your first words!',
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
