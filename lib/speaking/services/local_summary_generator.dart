import '../models/speaking_models.dart';

/// Generates lesson completion summaries without any API calls.
/// Uses the actual session performance data to personalize the output.
/// Produces varied text via indexed pool arrays — not random (deterministic
/// for same input data, which aids testing).
class LocalSummaryGenerator {
  /// Generate a [LessonSummary] from the completed lesson session.
  static LessonSummary generate({
    required SpeakingLesson lesson,
    required UserProgress progress,
  }) {
    // ── Compute performance metrics ────────────────────────────
    final results = progress.stepResults;
    final xp = progress.totalXpEarned;

    double avgScore = 0.0;
    if (results.isNotEmpty) {
      final scores = results
          .map((r) => r.attempts.isNotEmpty ? r.attempts.last.score : 0.0)
          .toList();
      avgScore = scores.reduce((a, b) => a + b) / scores.length;
    }

    final passedCount = results.where((r) => r.passed).length;
    final totalSteps = results.length;
    final passRate = totalSteps > 0 ? passedCount / totalSteps : 0.0;

    // ── Collect specific mistake issues from failed attempts ───
    final mistakes = results
        .expand((r) => r.attempts)
        .where((a) => a.specificIssue != null && a.score < 0.70)
        .map((a) => a.specificIssue!)
        .toSet()
        .toList();

    // ── Identify strengths from what went well ─────────────────
    final strongSteps = results
        .where((r) => r.attempts.isNotEmpty && r.attempts.last.score >= 0.85)
        .length;

    // ── Build the summary ──────────────────────────────────────
    return LessonSummary(
      headline: _headline(avgScore, xp, lesson.title),
      strength: _strength(avgScore, passRate, strongSteps, totalSteps),
      focusNext: _focusNext(mistakes, lesson.topic, lesson.cefrLevel),
      encouragement: _encouragement(avgScore, passRate),
      badgeEarned: _badge(avgScore, lesson.cefrLevel),
    );
  }

  // ─── Headline (1 sentence, mentions XP) ──────────────────────

  static String _headline(double avg, int xp, String lessonTitle) {
    if (avg >= 0.90) {
      return "Outstanding session on \"$lessonTitle\"! You earned $xp XP 🌟";
    } else if (avg >= 0.78) {
      return "Great work on \"$lessonTitle\"! $xp XP earned 🎉";
    } else if (avg >= 0.65) {
      return "Solid effort on \"$lessonTitle\"! You got $xp XP 💪";
    } else if (avg >= 0.50) {
      return "Good try on \"$lessonTitle\"! $xp XP in the bank. Keep going!";
    } else {
      return "You completed \"$lessonTitle\"! $xp XP earned — every session counts!";
    }
  }

  // ─── Strength (what they did well this session) ───────────────

  static String _strength(
      double avg, double passRate, int strongSteps, int totalSteps) {
    if (avg >= 0.88) {
      return "Excellent pronunciation clarity and strong vocabulary coverage across all steps.";
    } else if (passRate >= 0.80) {
      return "Consistent performance — you passed $strongSteps out of $totalSteps steps on first or second attempt.";
    } else if (avg >= 0.65) {
      return "Good sentence structure. You showed solid understanding of the core vocabulary.";
    } else if (strongSteps > 0) {
      return "You had $strongSteps strong step${strongSteps > 1 ? 's' : ''} this session. Build on those!";
    } else {
      return "Persistence — completing a full lesson, even when challenging, is what builds real fluency.";
    }
  }

  // ─── Focus next (what to practice) ────────────────────────────

  static String _focusNext(
      List<String> mistakes, String topic, CEFRLevel level) {
    if (mistakes.isEmpty) {
      return "Continue with more ${level.label} ${_levelLabel(level)} content to build confidence.";
    }
    // Take the first unique mistake category
    final topMistake = mistakes.first;
    if (topMistake.toLowerCase().contains('gap')) {
      return "Practice fill-in-the-gap exercises: always speak the FULL sentence.";
    } else if (topMistake.toLowerCase().contains('missing')) {
      return "Work on $topic vocabulary. Focus on: ${mistakes.first.replaceAll('Missing words: ', '')}";
    } else if (topMistake.toLowerCase().contains('repetition')) {
      return "Listen and repeat practice: slow down and say each word clearly.";
    } else {
      return "Review $topic vocabulary and try speaking in complete sentences.";
    }
  }

  static String _levelLabel(CEFRLevel level) {
    return switch (level) {
      CEFRLevel.a1 => "beginner",
      CEFRLevel.a2 => "elementary",
      CEFRLevel.b1 => "intermediate",
      CEFRLevel.b2 => "upper-intermediate",
      CEFRLevel.c1 => "advanced",
    };
  }

  // ─── Encouragement (motivational closing line) ─────────────────

  static String _encouragement(double avg, double passRate) {
    // Use pass rate to vary the pool selection so same avg can feel different
    final poolIndex = (passRate * 10).floor() % 3;

    final highPool = [
      "You're progressing fast — keep this momentum going!",
      "Native speakers would have no trouble understanding you!",
      "At this rate, you'll reach the next CEFR level ahead of schedule.",
    ];
    final midPool = [
      "Every lesson you complete builds real, lasting fluency.",
      "You're building a strong foundation. Daily practice will accelerate it.",
      "Progress isn't always visible, but it's always happening.",
    ];
    final lowPool = [
      "Every expert was once exactly where you are now.",
      "The fact that you're showing up and trying is the hardest part — and you're doing it.",
      "Come back tomorrow. It genuinely gets easier with each session.",
    ];

    final pool = avg >= 0.78 ? highPool : avg >= 0.58 ? midPool : lowPool;
    return pool[poolIndex];
  }

  // ─── Badge (earned only on strong performance) ────────────────

  static String? _badge(double avg, CEFRLevel level) {
    if (avg >= 0.88) {
      return '${level.label} Excellence';
    } else if (avg >= 0.78) {
      return '${level.label} Speaker';
    }
    return null; // No badge for average or below performance
  }
}
