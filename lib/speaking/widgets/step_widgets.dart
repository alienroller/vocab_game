import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/speaking_models.dart';

/// Individual step type renderers.
///
/// Each widget displays the exercise content for its step type
/// above the mic button. The mic button and feedback card are
/// managed by the parent [SpeakingLessonScreen].

// ─── Step 1: Listen & Repeat ────────────────────────────────────────

class ListenAndRepeatStep extends StatelessWidget {
  final LessonStep step;
  final bool hasPlayed;
  final VoidCallback onPlayAudio;

  const ListenAndRepeatStep({
    super.key,
    required this.step,
    required this.hasPlayed,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Instruction
        Text(
          step.instruction,
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Play audio button
        GestureDetector(
          onTap: onPlayAudio,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkGlassGradient
                  : AppTheme.lightGlassGradient,
              borderRadius: AppTheme.borderRadiusLg,
              border: Border.all(
                color: AppTheme.violet.withValues(alpha: 0.3),
              ),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    step.targetPhrase ?? '',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!hasPlayed) ...[
          const SizedBox(height: 12),
          Text(
            '👆 Tap to listen first',
            style: TextStyle(
              color: AppTheme.violet.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Step 2: Read & Speak ───────────────────────────────────────────

class ReadAndSpeakStep extends StatelessWidget {
  final LessonStep step;

  const ReadAndSpeakStep({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          step.instruction,
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Display the phrase to read
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkGlassGradient
                : AppTheme.lightGlassGradient,
            borderRadius: AppTheme.borderRadiusLg,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: AppTheme.shadowSoft,
          ),
          child: Column(
            children: [
              const Text('📖', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(
                step.targetPhrase ?? '',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 3: Prompt & Response ──────────────────────────────────────

class PromptResponseStep extends StatelessWidget {
  final LessonStep step;
  final bool hasPlayedQuestion;
  final VoidCallback onPlayQuestion;

  const PromptResponseStep({
    super.key,
    required this.step,
    required this.hasPlayedQuestion,
    required this.onPlayQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          step.instruction,
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Question card
        GestureDetector(
          onTap: onPlayQuestion,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkGlassGradient
                  : AppTheme.lightGlassGradient,
              borderRadius: AppTheme.borderRadiusLg,
              border: Border.all(
                color: AppTheme.amber.withValues(alpha: 0.3),
              ),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.amber.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: AppTheme.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    step.promptQuestion ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                Icon(
                  Icons.volume_up_rounded,
                  color: AppTheme.amber.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        if (step.expectedKeywords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: step.expectedKeywords.map((word) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      AppTheme.violet.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: AppTheme.borderRadiusSm,
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.violet.withValues(alpha: 0.8),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Step 4: Fill the Gap ───────────────────────────────────────────

class FillTheGapStep extends StatelessWidget {
  final LessonStep step;

  const FillTheGapStep({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final phrase = step.targetPhrase ?? '';

    // Split the phrase at ___ to highlight the gap
    final parts = phrase.split(RegExp(r'_+'));

    return Column(
      children: [
        Text(
          step.instruction,
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkGlassGradient
                : AppTheme.lightGlassGradient,
            borderRadius: AppTheme.borderRadiusLg,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: AppTheme.shadowSoft,
          ),
          child: Column(
            children: [
              const Text('✏️', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  children: [
                    if (parts.isNotEmpty)
                      TextSpan(text: parts[0]),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        width: 80,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.violet,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (parts.length > 1)
                      TextSpan(text: parts[1]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Say the complete sentence with the missing word',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 5: Free Conversation ──────────────────────────────────────

class FreeConversationStep extends StatelessWidget {
  final LessonStep step;
  final List<ConversationTurn> history;

  const FreeConversationStep({
    super.key,
    required this.step,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          step.instruction,
          style: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(isDark: isDark),
          child: Column(
            children: [
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Say hello to start!',
                    style: TextStyle(
                      color: AppTheme.violet,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ...history.map((turn) {
                final isUser = turn.role == ConversationRole.user;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.violet.withValues(alpha: 0.2),
                          child: const Text('🤖', style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser 
                                ? AppTheme.violet 
                                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: (!isUser && turn == history.last)
                              ? _TypewriterText(
                                  text: turn.text,
                                  style: TextStyle(
                                    color: (isDark ? Colors.white : Colors.black87),
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                )
                              : Text(
                                  turn.text,
                                  style: TextStyle(
                                    color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TypewriterText({required this.text, required this.style});

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    // Determine speed: faster for longer texts, but cap it so it stays readable.
    final speedMs = (widget.text.length > 50) ? 20 : 35;
    
    _timer = Timer.periodic(Duration(milliseconds: speedMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
