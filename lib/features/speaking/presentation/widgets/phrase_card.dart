import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/models/speaking_phrase.dart';

/// Shared card rendering a phrase — used by nearly every exercise.
///
/// L2 text large, L1 translation small and muted below. A single play
/// button lets the learner replay the audio. Phonetic hint is hidden
/// by default; caller can flip [showPhonetic] after repeated fails.
class PhraseCard extends StatelessWidget {
  final SpeakingPhrase phrase;

  /// Hide the L2 text — used by the recall challenge.
  final bool obscureL2;

  /// Play the target phrase audio.
  final VoidCallback? onPlay;

  /// Whether to show the phonetic hint line.
  final bool showPhonetic;

  const PhraseCard({
    super.key,
    required this.phrase,
    this.obscureL2 = false,
    this.onPlay,
    this.showPhonetic = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient:
            isDark ? AppTheme.darkGlassGradient : AppTheme.lightGlassGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.violet.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (obscureL2)
            Text(
              '• • • • •',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            )
          else
            Text(
              phrase.l2Text,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            phrase.l1Text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              height: 1.3,
            ),
          ),
          if (showPhonetic && phrase.phonetic != null) ...[
            const SizedBox(height: 8),
            Text(
              phrase.phonetic!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: AppTheme.violet.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (onPlay != null)
            _PlayButton(onTap: onPlay!, isDark: isDark),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _PlayButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.violet.withValues(alpha: isDark ? 0.25 : 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.volume_up_rounded,
              color: AppTheme.violet, size: 26),
        ),
      ),
    );
  }
}
