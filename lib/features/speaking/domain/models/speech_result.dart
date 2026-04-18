/// Outcome of a single mic attempt — passed to the runner for scoring.
class SpeechResult {
  final String transcript;
  final double score; // 0.0 – 1.0
  final bool passed;
  final bool isEmpty;

  const SpeechResult({
    required this.transcript,
    required this.score,
    required this.passed,
    this.isEmpty = false,
  });

  factory SpeechResult.empty() => const SpeechResult(
        transcript: '',
        score: 0,
        passed: false,
        isEmpty: true,
      );
}

/// Whether the latest attempt passed, needs retry, or was silent.
enum AttemptOutcome {
  /// Score cleared the threshold — show green check, auto-advance.
  pass,

  /// Score too low — red shake, let the user try again.
  retry,

  /// Nothing audible — ask the user to speak up.
  silent,
}

/// Final stats handed to the completion screen.
class LessonStats {
  /// How many phrases the learner attempted.
  final int phrasesAttempted;

  /// How many were passed on first try.
  final int perfectPhrases;

  /// Average score over all scored attempts, 0.0 – 1.0.
  final double averageAccuracy;

  /// Hearts lost during the recall phase (0–3).
  final int heartsLost;

  /// Total wall-clock time in seconds.
  final int totalSeconds;

  /// XP the session earned (base + bonuses).
  final int xpEarned;

  const LessonStats({
    required this.phrasesAttempted,
    required this.perfectPhrases,
    required this.averageAccuracy,
    required this.heartsLost,
    required this.totalSeconds,
    required this.xpEarned,
  });
}
