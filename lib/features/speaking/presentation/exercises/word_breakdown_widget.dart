import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/lesson_runner_controller.dart';
import '../../application/providers.dart';
import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_scenario.dart';
import '../widgets/mic_button.dart';

/// Word-by-word breakdown: learner taps each chip to hear that word,
/// then says the whole phrase into the mic.
///
/// The chips gradually light up violet as each is tapped at least once,
/// giving a tiny progress cue without getting in the way.
class WordBreakdownWidget extends ConsumerStatefulWidget {
  final WordBreakdownExercise exercise;
  final FalouCefr cefr;
  final LessonRunnerController runner;
  final VoidCallback onPass;

  const WordBreakdownWidget({
    super.key,
    required this.exercise,
    required this.cefr,
    required this.runner,
    required this.onPass,
  });

  @override
  ConsumerState<WordBreakdownWidget> createState() =>
      _WordBreakdownWidgetState();
}

class _WordBreakdownWidgetState extends ConsumerState<WordBreakdownWidget> {
  final Set<int> _tapped = <int>{};
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _playWord(int i, String word) async {
    setState(() => _tapped.add(i));
    final coord = ref.read(falouSpeechCoordinatorProvider);
    await coord.playWord(word);
  }

  Future<void> _playFull() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    await coord.playPhrase(widget.exercise.phrase.l2Text, cefr: widget.cefr);
  }

  Future<void> _onMicTap() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    final runner = widget.runner;
    if (runner.state.attempt == AttemptState.listening) {
      await coord.stopListening();
      runner.markProcessing();
      return;
    }
    runner.markListening();
    try {
      await coord.startListening(
        languageCode: 'en-US',
        onFinal: (result) {
          if (!mounted) return;
          runner.markProcessing();
          final scored = runner.submitSpeech(result.transcript);
          if (scored.passed) {
            _advanceTimer?.cancel();
            _advanceTimer = Timer(const Duration(milliseconds: 800), () {
              if (mounted) widget.onPass();
            });
          }
        },
      );
    } catch (_) {
      if (mounted) runner.submitSpeech('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrase = widget.exercise.phrase;
    final tokens = phrase.effectiveTokens;
    final snapshot = widget.runner.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Tap each word',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < tokens.length; i++)
              _WordChip(
                word: tokens[i],
                tapped: _tapped.contains(i),
                isDark: isDark,
                onTap: () => _playWord(i, tokens[i]),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _playFull,
          icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.violet),
          label: const Text(
            'Play full phrase',
            style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          phrase.l1Text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 32),
        FalouMicButton(
          state: snapshot.attempt,
          onTap: _onMicTap,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 22,
          child: Text(
            _feedback(snapshot),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _feedbackColor(snapshot.attempt),
            ),
          ),
        ),
      ],
    );
  }

  String _feedback(LessonRunnerState s) {
    return switch (s.attempt) {
      AttemptState.idle => 'Now say the whole phrase',
      AttemptState.listening => 'Listening…',
      AttemptState.processing => 'Checking…',
      AttemptState.correct => 'Nice!',
      AttemptState.retry =>
        (s.lastResult?.isEmpty ?? false) ? 'Try once more' : 'Almost — try again',
    };
  }

  Color _feedbackColor(AttemptState s) {
    return switch (s) {
      AttemptState.correct => AppTheme.success,
      AttemptState.retry => AppTheme.error,
      _ => AppTheme.textSecondaryLight,
    };
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool tapped;
  final bool isDark;
  final VoidCallback onTap;

  const _WordChip({
    required this.word,
    required this.tapped,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = tapped
        ? AppTheme.violet.withValues(alpha: isDark ? 0.35 : 0.18)
        : (isDark ? const Color(0xFF2A2D50) : const Color(0xFFF0F1F8));
    final fg = tapped
        ? AppTheme.violet
        : (isDark ? Colors.white : const Color(0xFF22253F));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tapped
                  ? AppTheme.violet.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tapped ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
