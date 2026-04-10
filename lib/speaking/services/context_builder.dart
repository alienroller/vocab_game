import '../models/speaking_models.dart';

/// Builds and serializes the session context that gets prepended
/// to every single Gemini prompt.
///
/// This is the **entire secret** behind reliable Gemini evaluations:
/// always give it the full picture — learner level, lesson topic,
/// previous mistakes, attempt number, etc.
class ContextBuilder {
  ContextBuilder._();

  /// Build session context from lesson, progress, and current step.
  static GeminiSessionContext build({
    required SpeakingLesson lesson,
    required UserProgress progress,
    required LessonStep currentStep,
  }) {
    // Collect last 5 specific issues from this session
    final previousMistakes = progress.stepResults
        .expand((r) => r.attempts)
        .where((a) => a.score < 0.7 && a.specificIssue != null)
        .map((a) => a.specificIssue!)
        .toList();

    // Keep only last 5 to keep prompts tight
    if (previousMistakes.length > 5) {
      previousMistakes.removeRange(0, previousMistakes.length - 5);
    }

    // Count current attempt number for this step
    final currentStepAttempts = progress.currentStepIndex < progress.stepResults.length
        ? progress.stepResults[progress.currentStepIndex].attempts.length
        : 0;

    return GeminiSessionContext(
      learnerLevel: lesson.cefrLevel,
      targetLanguage: lesson.language,
      nativeLanguage: progress.nativeLanguage,
      lessonTopic: lesson.topic,
      lessonGoal: lesson.goal,
      previousMistakes: previousMistakes,
      stepNumber: progress.currentStepIndex + 1,
      totalSteps: lesson.steps.length,
      attemptNumber: currentStepAttempts + 1,
    );
  }

  /// Serialize context to the text block prepended to every Gemini prompt.
  static String serialize(GeminiSessionContext ctx) {
    final mistakeSection = ctx.previousMistakes.isNotEmpty
        ? 'Known struggle areas this session: ${ctx.previousMistakes.join(', ')}'
        : 'No prior mistakes recorded this session.';

    return '''
=== LEARNER SESSION CONTEXT ===
Language being learned: ${ctx.targetLanguage}
Learner's native language: ${ctx.nativeLanguage}
CEFR proficiency level: ${ctx.learnerLevel.label}
Lesson topic: ${ctx.lessonTopic}
Lesson goal: ${ctx.lessonGoal}
Current step: ${ctx.stepNumber} of ${ctx.totalSteps}
Attempt number: ${ctx.attemptNumber}
$mistakeSection
================================'''
        .trim();
  }

  /// Update context after a step is completed (mistakes accumulate).
  static void updateAfterStep(GeminiSessionContext ctx, StepResult result) {
    ctx.stepNumber++;
    ctx.attemptNumber = 1;

    final newMistakes = result.attempts
        .where((a) => a.specificIssue != null)
        .map((a) => a.specificIssue!)
        .toList();

    ctx.previousMistakes = [...ctx.previousMistakes, ...newMistakes];
    // Keep only last 5
    if (ctx.previousMistakes.length > 5) {
      ctx.previousMistakes =
          ctx.previousMistakes.sublist(ctx.previousMistakes.length - 5);
    }
  }
}
