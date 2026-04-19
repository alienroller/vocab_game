import 'package:flutter/foundation.dart';

import '../data/speech/pronunciation_scorer.dart';
import '../domain/models/speaking_exercise.dart';
import '../domain/models/speaking_scenario.dart';
import '../domain/models/speech_result.dart';

/// Per-attempt mic state. Owned by the controller so exercise widgets
/// don't each reinvent this lifecycle.
enum AttemptState {
  idle,
  listening,
  processing,
  correct,
  retry,
}

/// Snapshot of runner state the UI renders.
@immutable
class LessonRunnerState {
  /// Current exercise index within `scenario.exercises`.
  final int index;

  /// `scenario.exercises.length`. Cached so the UI avoids a getter chain.
  final int total;

  /// Latest mic lifecycle state.
  final AttemptState attempt;

  /// How many times the learner has tried the current exercise (resets on advance).
  final int attemptCount;

  /// Hearts remaining — only used during `RecallExercise`.
  final int hearts;

  /// True once the full exercise list is done. Triggers completion screen.
  final bool completed;

  /// Most recent scored result for the current exercise, if any.
  final SpeechResult? lastResult;

  /// Accumulated stats, snapshotted lazily on completion.
  final int phrasesAttempted;
  final int perfectPhrases;
  final double scoreSum;
  final int scoreCount;
  final int heartsLost;
  final int startedAtMs;

  const LessonRunnerState({
    required this.index,
    required this.total,
    required this.attempt,
    required this.attemptCount,
    required this.hearts,
    required this.completed,
    required this.lastResult,
    required this.phrasesAttempted,
    required this.perfectPhrases,
    required this.scoreSum,
    required this.scoreCount,
    required this.heartsLost,
    required this.startedAtMs,
  });

  LessonRunnerState copyWith({
    int? index,
    AttemptState? attempt,
    int? attemptCount,
    int? hearts,
    bool? completed,
    SpeechResult? lastResult,
    bool clearResult = false,
    int? phrasesAttempted,
    int? perfectPhrases,
    double? scoreSum,
    int? scoreCount,
    int? heartsLost,
  }) {
    return LessonRunnerState(
      index: index ?? this.index,
      total: total,
      attempt: attempt ?? this.attempt,
      attemptCount: attemptCount ?? this.attemptCount,
      hearts: hearts ?? this.hearts,
      completed: completed ?? this.completed,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      phrasesAttempted: phrasesAttempted ?? this.phrasesAttempted,
      perfectPhrases: perfectPhrases ?? this.perfectPhrases,
      scoreSum: scoreSum ?? this.scoreSum,
      scoreCount: scoreCount ?? this.scoreCount,
      heartsLost: heartsLost ?? this.heartsLost,
      startedAtMs: startedAtMs,
    );
  }
}

/// Drives a scenario's exercises in order. Pure in/out — no audio or
/// mic dependencies so it stays unit-testable. Widgets decide how to
/// capture speech and pass the transcript here via [submitSpeech].
class LessonRunnerController extends ChangeNotifier {
  LessonRunnerController({
    required this.scenario,
    PronunciationScorer? scorer,
    int Function()? clock,
  })  : _scorer = scorer ?? const PronunciationScorer(),
        _clock = clock ?? _wallClockMs,
        _state = LessonRunnerState(
          index: 0,
          total: scenario.exercises.length,
          attempt: AttemptState.idle,
          attemptCount: 0,
          hearts: 3,
          completed: false,
          lastResult: null,
          phrasesAttempted: 0,
          perfectPhrases: 0,
          scoreSum: 0,
          scoreCount: 0,
          heartsLost: 0,
          startedAtMs: (clock ?? _wallClockMs).call(),
        );

  final SpeakingScenario scenario;
  final PronunciationScorer _scorer;
  final int Function() _clock;

  LessonRunnerState _state;
  LessonRunnerState get state => _state;

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  SpeakingExercise get current => scenario.exercises[_state.index];

  /// Called by widgets when the mic starts capturing.
  void markListening() {
    _state = _state.copyWith(attempt: AttemptState.listening);
    notifyListeners();
  }

  /// Called when recording stops and evaluation is in flight.
  void markProcessing() {
    _state = _state.copyWith(attempt: AttemptState.processing);
    notifyListeners();
  }

  /// Score a transcription against the current exercise's target phrase.
  /// Returns the evaluated [SpeechResult]; widgets then decide to auto-advance.
  SpeechResult submitSpeech(String transcript) {
    final target = current.phrase.l2Text;
    if (transcript.trim().isEmpty) {
      final empty = SpeechResult.empty();
      _state = _state.copyWith(
        attempt: AttemptState.retry,
        lastResult: empty,
      );
      notifyListeners();
      return empty;
    }

    final score = _scorer.score(transcript, target);
    final passed = _scorer.passes(transcript, target);
    final result = SpeechResult(
      transcript: transcript,
      score: score,
      passed: passed,
    );

    final nextAttemptCount = _state.attemptCount + 1;
    final isRecall = current is RecallExercise;
    final newHearts =
        (!passed && isRecall) ? (_state.hearts - 1).clamp(0, 3) : _state.hearts;
    final newHeartsLost =
        (!passed && isRecall) ? _state.heartsLost + 1 : _state.heartsLost;

    _state = _state.copyWith(
      attempt: passed ? AttemptState.correct : AttemptState.retry,
      attemptCount: nextAttemptCount,
      lastResult: result,
      scoreSum: _state.scoreSum + score,
      scoreCount: _state.scoreCount + 1,
      perfectPhrases: (passed && nextAttemptCount == 1)
          ? _state.perfectPhrases + 1
          : _state.perfectPhrases,
      hearts: newHearts,
      heartsLost: newHeartsLost,
    );
    notifyListeners();
    return result;
  }

  /// Listen-only exercises just call this to advance with no scoring.
  void markListenComplete() {
    _state = _state.copyWith(
      attempt: AttemptState.correct,
      attemptCount: _state.attemptCount + 1,
    );
    notifyListeners();
  }

  /// Advance to the next exercise, or mark the lesson complete.
  /// Safe to call multiple times at the end — it's idempotent.
  void advance() {
    if (_state.completed) return;
    final nextIndex = _state.index + 1;
    final wasMicExercise = current is! ListenExercise;

    // Recall hearts: if user blew all 3, still advance (don't gate progress).
    if (nextIndex >= scenario.exercises.length) {
      _state = _state.copyWith(
        completed: true,
        attempt: AttemptState.idle,
        attemptCount: 0,
        clearResult: true,
        phrasesAttempted:
            wasMicExercise ? _state.phrasesAttempted + 1 : _state.phrasesAttempted,
      );
    } else {
      _state = _state.copyWith(
        index: nextIndex,
        attempt: AttemptState.idle,
        attemptCount: 0,
        clearResult: true,
        phrasesAttempted:
            wasMicExercise ? _state.phrasesAttempted + 1 : _state.phrasesAttempted,
      );
    }
    notifyListeners();
  }

  /// Skip the current exercise. Treated as a non-pass but still advances.
  void skip() {
    if (_state.completed) return;
    advance();
  }

  /// Compute final stats for the completion screen.
  LessonStats buildStats() {
    final elapsed = (_clock() - _state.startedAtMs) / 1000;
    final avg = _state.scoreCount == 0
        ? 0.0
        : (_state.scoreSum / _state.scoreCount).clamp(0.0, 1.0);
    final baseXp = scenario.xpReward;
    final perfectBonus = _state.perfectPhrases * 5;
    final recallBonus = _state.heartsLost == 0 ? 10 : 0;
    return LessonStats(
      phrasesAttempted: _state.phrasesAttempted,
      perfectPhrases: _state.perfectPhrases,
      averageAccuracy: avg,
      heartsLost: _state.heartsLost,
      totalSeconds: elapsed.round(),
      xpEarned: baseXp + perfectBonus + recallBonus,
    );
  }
}
