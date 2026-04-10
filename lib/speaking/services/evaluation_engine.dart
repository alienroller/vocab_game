import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/speaking_models.dart';
import '../models/scripted_conversation.dart';
import 'eval_cache_service.dart';
import 'local_evaluator.dart';
import 'local_summary_generator.dart';

/// The evaluation engine — dispatches to the right local evaluator,
/// checks persistent cache, and determines next action.
///
/// After refactor: ZERO Gemini API calls. All evaluation is local.
class EvaluationEngine {
  EvaluationEngine._();

  // ─── Main Dispatcher ──────────────────────────────────────────────

  /// Evaluate a step using local algorithms (no network).
  static Future<EvaluationResult> evaluateStep({
    required LessonStep step,
    required String transcript,
    required GeminiSessionContext ctx,
    List<ConversationTurn>? history,
  }) async {
    // Guard: empty transcript is an empty result — do not evaluate
    if (transcript.trim().length < 2) return EvaluationResult.empty();

    // Free conversation uses its own scripted evaluator path
    if (step.type == StepType.freeConversation) {
      return _evaluateScriptedConversationTurn(step, transcript, history ?? []);
    }

    // Check persistent cache before any computation
    final cached = await EvalCacheService.get(step, transcript, ctx.learnerLevel);
    if (cached != null) {
      debugPrint('Eval cache hit for: $transcript');
      return cached;
    }

    // Local evaluation — zero network, zero quota
    final EvaluationResult result;
    switch (step.type) {
      case StepType.listenAndRepeat:
        result = LocalEvaluator.evaluateListenAndRepeat(
          targetPhrase: step.targetPhrase ?? '',
          transcript: transcript,
          level: ctx.learnerLevel,
        );

      case StepType.readAndSpeak:
        result = LocalEvaluator.evaluateReadAndSpeak(
          targetPhrase: step.targetPhrase ?? '',
          acceptableVariants: step.acceptableVariants,
          transcript: transcript,
          level: ctx.learnerLevel,
        );

      case StepType.promptResponse:
        result = LocalEvaluator.evaluatePromptResponse(
          question: step.promptQuestion ?? '',
          expectedKeywords: step.expectedKeywords,
          transcript: transcript,
          grammarFocus: step.grammarFocus,
          level: ctx.learnerLevel,
        );

      case StepType.fillTheGap:
        // correctAnswers = expectedKeywords (the accepted gap words)
        result = LocalEvaluator.evaluateFillTheGap(
          targetPhrase: step.targetPhrase ?? '',
          correctAnswers: step.expectedKeywords,
          transcript: transcript,
        );

      case StepType.freeConversation:
        // Handled above — this case is unreachable
        result = EvaluationResult.empty();
    }

    // Persist to cache for future attempts
    await EvalCacheService.set(step, transcript, ctx.learnerLevel, result);
    return result;
  }

  // ─── Scripted Conversation ────────────────────────────────────────

  /// Evaluates one turn of a scripted conversation.
  ///
  /// [history] is used to determine which node we're currently on:
  ///   - Empty history = first node (opening turn)
  ///   - Each passed turn adds 2 entries (user + model) to history
  ///   - Current node index = history.length / 2
  static Future<EvaluationResult> _evaluateScriptedConversationTurn(
    LessonStep step,
    String transcript,
    List<ConversationTurn> history,
  ) async {
    // Look up the scripted conversation for this step
    final script = ScriptedConversationRegistry.get(step.id);

    if (script == null) {
      debugPrint('No script registered for step: ${step.id} — using fallback');
      // No script registered — fallback: any non-empty response passes
      return EvaluationResult(
        score: 0.75,
        passed: true,
        feedback: "Good response!",
        chatReply: "Great! Let's continue.",
        isConversationComplete: history.length >= 4,
        fluency: 0.75,
        vocabularyRange: 0.70,
        taskCompletion: 0.75,
        isEmpty: false,
        missingWords: const [],
        vocabularyHit: const [],
        vocabularyMiss: const [],
        highlights: const ['Completed a conversation turn'],
        focusAreas: const [],
        wrongLanguageDetected: false,
      );
    }

    // Determine current node from history length
    // The first AI message is pre-added to history, so:
    // history = [model(opening)] → user responds → we evaluate node 0
    // After pass: history = [model(opening), user, model(next)] → node 1
    // Current node = number of completed user turns
    final currentNodeIndex = history.where((t) => t.role == ConversationRole.user).length;

    if (currentNodeIndex >= script.nodes.length) {
      // We're past the end — mark complete
      return const EvaluationResult(
        score: 0.90,
        passed: true,
        feedback: "Excellent conversation!",
        isConversationComplete: true,
        fluency: 0.85,
        vocabularyRange: 0.80,
        taskCompletion: 0.95,
        isEmpty: false,
        missingWords: [],
        vocabularyHit: [],
        vocabularyMiss: [],
        highlights: ['Completed the full conversation!'],
        focusAreas: [],
        wrongLanguageDetected: false,
      );
    }

    final currentNode = script.nodes[currentNodeIndex];

    // Get the next node's AI utterance (to be spoken after this pass)
    final nextNode = currentNode.nextNodeId != null
        ? script.getNode(currentNode.nextNodeId!)
        : null;

    return LocalEvaluator.evaluateScriptedTurn(
      transcript: transcript,
      acceptableKeywords: currentNode.acceptableKeywords,
      feedbackOnSuccess: currentNode.feedbackOnSuccess,
      feedbackOnFail: currentNode.feedbackOnFail,
      nextAiUtterance: nextNode?.aiUtterance,
      isLastNode: currentNode.isLastNode,
    );
  }

  // ─── Scoring → Next Action ────────────────────────────────────────

  /// Determine what happens next after an evaluation.
  static StepOutcome resolveNextAction({
    required EvaluationResult result,
    required LessonStep step,
    required int attemptNumber,
  }) {
    if (result.isEmpty) {
      return const StepOutcome(action: StepAction.silentRetry);
    }

    if (result.isConversationComplete == false) {
      return const StepOutcome(action: StepAction.continueConversation);
    }

    if (result.passed) {
      return StepOutcome(
        action: StepAction.advance,
        xpEarned: calculateXP(result.score, attemptNumber, step.type),
        animation: result.score > 0.9 ? 'PERFECT' : 'CORRECT',
      );
    }
    
    // Explicit Language Mismatch Catcher
    if (result.wrongLanguageDetected) {
      return StepOutcome(
        action: StepAction.retry,
        hint: "Oops! We didn't hear the expected language. Try saying it in the correct target language!",
      );
    }

    // Show hints after 2nd failed attempt
    if (attemptNumber >= 2 && step.hints.isNotEmpty) {
      final hintIndex = min(attemptNumber - 2, step.hints.length - 1);
      return StepOutcome(
        action: StepAction.retryWithHint,
        hint: step.hints[hintIndex],
      );
    }

    // Max attempts reached — show answer and continue
    if (attemptNumber >= step.maxAttempts) {
      return StepOutcome(
        action: StepAction.showAnswerContinue,
        xpEarned: 2, // Participation XP — never zero, never demoralizing
        modelAnswer: result.modelAnswer ?? result.correctFullSentence,
      );
    }

    return const StepOutcome(action: StepAction.retry);
  }

  /// Calculate XP for a step (from spec Phase 8.1).
  static int calculateXP(double score, int attempts, StepType type) {
    final maxXp = type.maxXp;
    int xp = (score * maxXp).round();

    // Bonuses
    if (score >= 0.95) xp += 3; // Perfect score
    if (attempts == 1) xp += 2; // First attempt pass
    // Deduction for multiple attempts
    xp -= max(0, attempts - 1) * 2;

    return max(1, xp); // Never zero
  }

  // ─── Lesson Summary ───────────────────────────────────────────────

  /// Generate a lesson summary — fully local, no API call.
  static Future<LessonSummary> generateSummary({
    required SpeakingLesson lesson,
    required UserProgress progress,
    required GeminiSessionContext ctx,
  }) async {
    // Fully local — no API call
    return LocalSummaryGenerator.generate(
      lesson: lesson,
      progress: progress,
    );
  }
}
