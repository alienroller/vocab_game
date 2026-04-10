// Data models for the Duolingo-style speaking practice module.
//
// Adapted from the TypeScript specification to Dart.
// All types here are plain data classes — no Hive or JSON serialization
// needed since lessons are in-memory during a session.

// ─── Enums ──────────────────────────────────────────────────────────

enum CEFRLevel { a1, a2, b1, b2, c1 }

extension CEFRLevelExtension on CEFRLevel {
  String get label {
    switch (this) {
      case CEFRLevel.a1:
        return 'A1';
      case CEFRLevel.a2:
        return 'A2';
      case CEFRLevel.b1:
        return 'B1';
      case CEFRLevel.b2:
        return 'B2';
      case CEFRLevel.c1:
        return 'C1';
    }
  }
}

enum StepType {
  listenAndRepeat,
  readAndSpeak,
  promptResponse,
  fillTheGap,
  freeConversation,
}

extension StepTypeExtension on StepType {
  String get displayName {
    switch (this) {
      case StepType.listenAndRepeat:
        return 'Listen & Repeat';
      case StepType.readAndSpeak:
        return 'Read & Speak';
      case StepType.promptResponse:
        return 'Answer the Question';
      case StepType.fillTheGap:
        return 'Fill the Gap';
      case StepType.freeConversation:
        return 'Free Conversation';
    }
  }

  String get emoji {
    switch (this) {
      case StepType.listenAndRepeat:
        return '🔊';
      case StepType.readAndSpeak:
        return '📖';
      case StepType.promptResponse:
        return '💬';
      case StepType.fillTheGap:
        return '✏️';
      case StepType.freeConversation:
        return '🗣️';
    }
  }

  /// Max XP per step type (from spec Phase 8.1).
  int get maxXp {
    switch (this) {
      case StepType.listenAndRepeat:
        return 8;
      case StepType.readAndSpeak:
        return 10;
      case StepType.promptResponse:
        return 15;
      case StepType.fillTheGap:
        return 12;
      case StepType.freeConversation:
        return 50;
    }
  }
}

// ─── Mic Button State ───────────────────────────────────────────────

enum MicState {
  idle,
  ready,
  countdown,
  recording,
  processing,
  success,
  error,
}

// ─── Step Outcome Action ────────────────────────────────────────────

enum StepAction {
  advance,
  retry,
  retryWithHint,
  showAnswerContinue,
  silentRetry,
  continueConversation,
}

// ─── Data Classes ───────────────────────────────────────────────────

/// A full speaking lesson with multiple steps.
class SpeakingLesson {
  final String id;
  final String title;
  final String language;
  final String languageCode; // e.g. "en-US", "uz-UZ"
  final CEFRLevel cefrLevel;
  final String topic;
  final String goal;
  final List<LessonStep> steps;
  final int estimatedMinutes;
  final int xpReward;

  const SpeakingLesson({
    required this.id,
    required this.title,
    required this.language,
    required this.languageCode,
    required this.cefrLevel,
    required this.topic,
    required this.goal,
    required this.steps,
    required this.estimatedMinutes,
    required this.xpReward,
  });
}

/// One exercise step within a lesson.
class LessonStep {
  final String id;
  final StepType type;
  final String instruction;
  final String? targetPhrase;
  final String? promptQuestion;
  final List<String> expectedKeywords;
  final List<String> acceptableVariants;
  final List<String> hints;
  final double minAccuracyToPass;
  final int maxAttempts;
  final String? grammarFocus;

  const LessonStep({
    required this.id,
    required this.type,
    required this.instruction,
    this.targetPhrase,
    this.promptQuestion,
    this.expectedKeywords = const [],
    this.acceptableVariants = const [],
    this.hints = const [],
    this.minAccuracyToPass = 0.65,
    this.maxAttempts = 3,
    this.grammarFocus,
  });
}

/// One speech attempt by the learner.
class SpeechAttempt {
  final String transcript;
  final double score;
  final String feedback;
  final String? specificIssue;
  final DateTime timestamp;

  const SpeechAttempt({
    required this.transcript,
    required this.score,
    required this.feedback,
    this.specificIssue,
    required this.timestamp,
  });
}

/// All attempts for a single step.
class StepResult {
  final String stepId;
  final List<SpeechAttempt> attempts;
  final bool passed;
  final int xpEarned;

  const StepResult({
    required this.stepId,
    required this.attempts,
    required this.passed,
    required this.xpEarned,
  });
}

/// Session-level progress tracking.
class UserProgress {
  final String nativeLanguage;
  int currentStepIndex;
  final List<StepResult> stepResults;
  int totalXpEarned;

  UserProgress({
    this.nativeLanguage = 'Uzbek',
    this.currentStepIndex = 0,
    List<StepResult>? stepResults,
    this.totalXpEarned = 0,
  }) : stepResults = stepResults ?? [];
}

/// Context object sent with every Gemini API call.
class GeminiSessionContext {
  final CEFRLevel learnerLevel;
  final String targetLanguage;
  final String nativeLanguage;
  final String lessonTopic;
  final String lessonGoal;
  List<String> previousMistakes;
  int stepNumber;
  final int totalSteps;
  int attemptNumber;

  GeminiSessionContext({
    required this.learnerLevel,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.lessonTopic,
    required this.lessonGoal,
    List<String>? previousMistakes,
    required this.stepNumber,
    required this.totalSteps,
    this.attemptNumber = 1,
  }) : previousMistakes = previousMistakes ?? [];
}

/// A single turn in a free conversation.
enum ConversationRole { model, user }

class ConversationTurn {
  final ConversationRole role;
  final String text;

  const ConversationTurn({
    required this.role,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'parts': [
          {'text': text}
        ],
      };
}

/// Parsed evaluation result from Gemini.
class EvaluationResult {
  final double score;
  final bool passed;
  final String feedback;
  final String? specificIssue;
  final String? celebration;
  final String? modelAnswer;
  final List<String> missingWords;
  final List<String> vocabularyHit;
  final List<String> vocabularyMiss;
  final bool? gapFilledCorrectly;
  final bool? spokeFullSentence;
  final String? correctFullSentence;
  final bool isEmpty;

  // Free conversation specific fields
  final String? chatReply;
  final bool? isConversationComplete;
  final double? fluency;
  final double? vocabularyRange;
  final double? taskCompletion;
  final List<String> highlights;
  final List<String> focusAreas;
  final bool wrongLanguageDetected;

  const EvaluationResult({
    required this.score,
    required this.passed,
    required this.feedback,
    this.specificIssue,
    this.celebration,
    this.modelAnswer,
    this.missingWords = const [],
    this.vocabularyHit = const [],
    this.vocabularyMiss = const [],
    this.gapFilledCorrectly,
    this.spokeFullSentence,
    this.correctFullSentence,
    this.isEmpty = false,
    this.chatReply,
    this.isConversationComplete,
    this.fluency,
    this.vocabularyRange,
    this.taskCompletion,
    this.highlights = const [],
    this.focusAreas = const [],
    this.wrongLanguageDetected = false,
  });

  /// Empty/no-speech result.
  factory EvaluationResult.empty() => const EvaluationResult(
        score: 0,
        passed: false,
        feedback: "We didn't hear anything — try again!",
        isEmpty: true,
      );
}

/// What to do after an evaluation.
class StepOutcome {
  final StepAction action;
  final int xpEarned;
  final String? hint;
  final String? modelAnswer;
  final String? animation; // 'PERFECT' | 'CORRECT'

  const StepOutcome({
    required this.action,
    this.xpEarned = 0,
    this.hint,
    this.modelAnswer,
    this.animation,
  });
}

/// Summary generated by Gemini at lesson completion.
class LessonSummary {
  final String headline;
  final String strength;
  final String focusNext;
  final String encouragement;
  final String? badgeEarned;

  const LessonSummary({
    required this.headline,
    required this.strength,
    required this.focusNext,
    required this.encouragement,
    this.badgeEarned,
  });
}
