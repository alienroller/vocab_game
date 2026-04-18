import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/lesson_runner_controller.dart';
import '../../application/providers.dart';
import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_scenario.dart';
import '../widgets/hearts_indicator.dart';
import '../widgets/mic_button.dart';
import '../widgets/phrase_card.dart';

/// End-of-scenario recall: learner sees only the L1 prompt and must
/// produce the L2 phrase from memory.
///
/// - Shows 3 hearts; losing all still advances (we don't gate progress).
/// - L2 text stays hidden until attempt #3, then reveals with a gentle tap.
class RecallWidget extends ConsumerStatefulWidget {
  final RecallExercise exercise;
  final FalouCefr cefr;
  final LessonRunnerController runner;
  final VoidCallback onDone;

  const RecallWidget({
    super.key,
    required this.exercise,
    required this.cefr,
    required this.runner,
    required this.onDone,
  });

  @override
  ConsumerState<RecallWidget> createState() => _RecallWidgetState();
}

class _RecallWidgetState extends ConsumerState<RecallWidget> {
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
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
          if (scored.passed || runner.state.hearts == 0) {
            _advanceTimer?.cancel();
            _advanceTimer = Timer(
              Duration(milliseconds: scored.passed ? 800 : 1200),
              () {
                if (mounted) widget.onDone();
              },
            );
          }
        },
      );
    } catch (_) {
      if (mounted) runner.submitSpeech('');
    }
  }

  Future<void> _playHint() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    await coord.playPhrase(widget.exercise.phrase.l2Text, cefr: widget.cefr);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.runner.state;
    // Reveal after 2 failed tries (attemptCount counts submissions).
    final reveal = snapshot.attemptCount >= 2;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HeartsIndicator(hearts: snapshot.hearts),
        const SizedBox(height: 14),
        Text(
          'Say it from memory',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 20),
        PhraseCard(
          phrase: widget.exercise.phrase,
          obscureL2: !reveal,
          onPlay: reveal ? _playHint : null,
          showPhonetic: reveal && widget.exercise.phrase.phonetic != null,
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
            _feedback(snapshot, reveal),
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

  String _feedback(LessonRunnerState s, bool reveal) {
    if (s.hearts == 0 && s.attempt != AttemptState.correct) {
      return 'No hearts left — moving on';
    }
    return switch (s.attempt) {
      AttemptState.idle =>
        reveal ? 'Revealed! Say it now' : 'Tap the mic when ready',
      AttemptState.listening => 'Listening…',
      AttemptState.processing => 'Checking…',
      AttemptState.correct => 'Got it!',
      AttemptState.retry =>
        (s.lastResult?.isEmpty ?? false) ? 'Try again' : 'Close — try once more',
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
