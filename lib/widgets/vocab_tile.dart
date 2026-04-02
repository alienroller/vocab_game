import 'package:flutter/material.dart';

import '../models/vocab.dart';
import '../theme/app_theme.dart';

/// Glassmorphism vocabulary tile with swipe-to-delete and language indicators.
class VocabTile extends StatelessWidget {
  final Vocab vocab;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const VocabTile({
    super.key,
    required this.vocab,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('dismiss_${vocab.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.transparent, AppTheme.error],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: AppTheme.borderRadiusMd,
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
        ),
        child: Container(
          decoration: AppTheme.glassCard(isDark: isDark),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: AppTheme.borderRadiusMd,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Language indicator
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.violet.withValues(alpha: 0.15),
                            AppTheme.violet.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: AppTheme.borderRadiusSm,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vocab.english,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text('🇺🇿 ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight)),
                              Expanded(
                                child: Text(
                                  vocab.uzbek,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppTheme.textSecondaryDark.withValues(alpha: 0.5)
                          : AppTheme.textSecondaryLight.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
