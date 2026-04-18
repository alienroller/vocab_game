import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/lesson_runner_controller.dart';
import '../../application/providers.dart';
import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_scenario.dart';
import '../widgets/mic_button.dart';
import '../widgets/phrase_card.dart';

/// The heart of the module — user hears the phrase and repeats it.
///
/// Flow:
/// 1. Auto-play on entry.
/// 2. User taps mic → listen → stop → scoring.
/// 3. On pass → green check, 800 ms delay → `onPass`.
/// 4. On retry → red shake, stay on exercise, reveal phonetic after 2 fails.
class ListenRepeatWidget extends ConsumerStatefulWidget {
  final ListenRepeatExercise exercise;
  final FalouCefr cefr;
  final LessonRunnerController runner;
  final VoidCallback onPass;

  const ListenRepeatWidget({
    super.key,
    required this.exercise,
    required this.cefr,
    required this.runner,
    required this.onPass,
  });

  @override
  ConsumerState<ListenRepeatWidget> createState() => _ListenRepeatWidgetState();
}

class _ListenRepeatWidgetState extends ConsumerState<ListenRepeatWidget> {
  bool _autoplayed = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _autoplayed) return;
      _autoplayed = true;
      await _play();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    await coord.playPhrase(widget.exercise.phrase.l2Text, cefr: widget.cefr);
  }

  Future<void> _onMicTap() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    final runner = widget.runner;
    final state = runner.state.attempt;

    // Toggle: if already listening, stop & submit silent.
    if (state == AttemptState.listening) {
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
          if (scored.passed) _scheduleAdvance();
        },
      );
    } catch (_) {
      if (mounted) runner.submitSpeech('');
    }
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) widget.onPass();
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.runner.state;
    final showPhonetic = snapshot.attemptCount >= 2 &&
        widget.exercise.phrase.phonetic != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Your turn',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 20),
        PhraseCard(
          phrase: widget.exercise.phrase,
          onPlay: _play,
          showPhonetic: showPhonetic,
        ),
        const SizedBox(height: 40),
        FalouMicButton(
          state: snapshot.attempt,
          onTap: _onMicTap,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 22,
          child: _FeedbackLine(state: snapshot),
        ),
      ],
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  final LessonRunnerState state;
  const _FeedbackLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state.attempt;
    final text = switch (s) {
      AttemptState.idle => 'Tap to speak',
      AttemptState.listening => 'Listening…',
      AttemptState.processing => 'Checking…',
      AttemptState.correct => 'Great job!',
      AttemptState.retry => _retryLine(state),
    };
    final color = switch (s) {
      AttemptState.correct => AppTheme.success,
      AttemptState.retry => AppTheme.error,
      _ => AppTheme.textSecondaryLight,
    };
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      child: Text(text),
    );
  }

  String _retryLine(LessonRunnerState s) {
    if (s.lastResult?.isEmpty ?? false) return "Didn't catch that — try again";
    if (s.attemptCount >= 2) return 'Almost! Follow the hint';
    return 'Try again';
  }
}
