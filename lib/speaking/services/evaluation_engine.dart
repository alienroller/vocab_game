import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/speaking_models.dart';
import 'eval_cache_service.dart';
import 'gemini_client.dart';
import 'prompt_builders.dart';

/// The evaluation engine — dispatches to the right prompt builder,
/// calls Gemini, parses the response, and determines next action.
class EvaluationEngine {
  EvaluationEngine._();

  // ─── Main Dispatcher ──────────────────────────────────────────────

  /// Evaluate a step using Gemini (or Levenshtein fallback).
  static Future<EvaluationResult> evaluateStep({
    required LessonStep step,
    required String transcript,
    required GeminiSessionContext ctx,
    List<ConversationTurn>? history,
  }) async {
    if (transcript.trim().length < 2) {
      return EvaluationResult.empty();
    }

    try {
      if (step.type == StepType.freeConversation) {
        if (history == null) {
          debugPrint('Warning: history is null for freeConversation');
          history = [];
        }
        return await _evaluateConversationTurn(
          step: step,
          transcript: transcript,
          ctx: ctx,
          history: history,
        );
      }

      // Check cache first
      final cachedResult = EvalCacheService.getCachedResult(step, transcript, ctx);
      if (cachedResult != null) {
        debugPrint('Eval cache hit for: \$transcript');
        return cachedResult;
      }

      final prompt = _buildPrompt(step, transcript, ctx);
      if (prompt == null) {
        throw GeminiUnavailableException('Missing prompt builder');
      }

      final json = await GeminiClient.callJSON(prompt: prompt);
      final result = _parseResult(json, step.type);
      
      EvalCacheService.cacheResult(step, transcript, ctx, result);
      return result;
    } on GeminiUnavailableException catch (e) {
      debugPrint('Gemini unavailable ($e) — using smart fallback');
      return _smartFallback(step, transcript);
    } catch (e) {
      debugPrint('Evaluation error: $e — using smart fallback');
      return _smartFallback(step, transcript);
    }
  }

  /// Build the right prompt for the step type.
  static String? _buildPrompt(
      LessonStep step, String transcript, GeminiSessionContext ctx) {
    switch (step.type) {
      case StepType.listenAndRepeat:
        return PromptBuilders.listenAndRepeat(
          ctx: ctx,
          targetPhrase: step.targetPhrase!,
          userTranscript: transcript,
        );
      case StepType.readAndSpeak:
        return PromptBuilders.readAndSpeak(
          ctx: ctx,
          targetPhrase: step.targetPhrase!,
          acceptableVariants: step.acceptableVariants,
          userTranscript: transcript,
        );
      case StepType.promptResponse:
        return PromptBuilders.promptResponse(
          ctx: ctx,
          question: step.promptQuestion!,
          expectedKeywords: step.expectedKeywords,
          grammarFocus: step.grammarFocus,
          userTranscript: transcript,
        );
      case StepType.fillTheGap:
        return PromptBuilders.fillTheGap(
          ctx: ctx,
          sentenceWithGap: step.targetPhrase!,
          correctAnswers: step.expectedKeywords,
          userTranscript: transcript,
        );
      case StepType.freeConversation:
        return null;
    }
  }

  static Future<EvaluationResult> _evaluateConversationTurn({
    required LessonStep step,
    required String transcript,
    required GeminiSessionContext ctx,
    required List<ConversationTurn> history,
  }) async {
    final systemInstruction = PromptBuilders.freeConversationInstruction(
      ctx: ctx,
      step: step,
    );

    try {
      final rawResponse = await GeminiClient.callConversation(
        systemInstruction: systemInstruction,
        history: history,
        prompt: transcript,
      );

      // Parse <<<EVAL>>> JSON block if present
      final evalMatch = RegExp(r'<<<EVAL>>>([\s\S]*?)<<<END_EVAL>>>').firstMatch(rawResponse);
      
      if (evalMatch != null) {
        final jsonStr = evalMatch.group(1)!.trim();
        final json = jsonDecode(jsonStr);
        final reply = rawResponse.replaceAll(evalMatch.group(0)!, '').trim();
        
        return EvaluationResult(
          score: (json['score'] as num?)?.toDouble() ?? 0.0,
          passed: json['passed'] as bool? ?? false,
          feedback: json['feedback'] as String? ?? 'Good conversation!',
          chatReply: reply.isNotEmpty ? reply : null,
          isConversationComplete: true,
          fluency: (json['fluency'] as num?)?.toDouble(),
          vocabularyRange: (json['vocabulary_range'] as num?)?.toDouble(),
          taskCompletion: (json['task_completion'] as num?)?.toDouble(),
          highlights: _parseStringList(json['highlights']),
          focusAreas: _parseStringList(json['focus_areas']),
        );
      } else {
        // Conversation continues...
        return EvaluationResult(
          score: 1.0,
          passed: true,
          feedback: '',
          chatReply: rawResponse.trim(),
          isConversationComplete: false,
        );
      }
    } catch (e) {
      debugPrint('Conversation error: $e');
      return const EvaluationResult(
        score: 1.0,
        passed: true,
        feedback: '',
        chatReply: "I'm having trouble connecting. Could you say that again?",
        isConversationComplete: false,
      );
    }
  }

  /// Parse Gemini's JSON response into an EvaluationResult.
  static EvaluationResult _parseResult(
      Map<String, dynamic> json, StepType type) {
    return EvaluationResult(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? 'Good effort!',
      specificIssue: json['specific_issue'] as String?,
      celebration: json['celebration'] as String?,
      modelAnswer: json['model_answer'] as String?,
      missingWords: _parseStringList(json['missing_words']),
      vocabularyHit: _parseStringList(json['vocabulary_hit']),
      vocabularyMiss: _parseStringList(json['vocabulary_miss']),
      gapFilledCorrectly: json['gap_filled_correctly'] as bool?,
      spokeFullSentence: json['spoke_full_sentence'] as bool?,
      correctFullSentence: json['correct_full_sentence'] as String?,
      wrongLanguageDetected: json['wrong_language'] as bool? ?? false,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Smart fallback when Gemini is unavailable (e.g. CORS on web).
  /// Uses step-type-specific scoring strategies.
  static EvaluationResult _smartFallback(LessonStep step, String transcript) {
    switch (step.type) {
      case StepType.listenAndRepeat:
      case StepType.readAndSpeak:
        return _levenshteinFallback(step, transcript);
      case StepType.promptResponse:
        return _keywordFallback(step, transcript);
      case StepType.fillTheGap:
        return _gapFillFallback(step, transcript);
      case StepType.freeConversation:
        // Always pass free conversation in fallback mode
        return const EvaluationResult(
          score: 0.7,
          passed: true,
          feedback: 'Great effort! Keep practicing your speaking. 💬',
        );
    }
  }

  /// Levenshtein fallback for listen-and-repeat / read-and-speak.
  /// Compares transcript against the target phrase.
  static EvaluationResult _levenshteinFallback(
      LessonStep step, String transcript) {
    final target = step.targetPhrase ?? '';
    final score = GeminiClient.levenshteinScore(target, transcript);
    final passed = score >= step.minAccuracyToPass;

    String feedback;
    if (score > 0.9) {
      feedback = 'Excellent — almost perfect! 🌟';
    } else if (score > 0.7) {
      feedback = 'Good job — keep practicing! 💪';
    } else if (score > 0.5) {
      feedback = 'Nice try — a few words were off. Try again!';
    } else {
      feedback = "That wasn't quite right. Listen carefully and try again.";
    }

    return EvaluationResult(
      score: score,
      passed: passed,
      feedback: feedback,
      correctFullSentence: target,
    );
  }

  /// Keyword-overlap fallback for prompt-response steps.
  /// Checks how many expected keywords the user included,
  /// and gives generous credit for any meaningful attempt.
  static EvaluationResult _keywordFallback(
      LessonStep step, String transcript) {
    final words = transcript.toLowerCase().split(RegExp(r'\s+'));
    final keywords = step.expectedKeywords;

    if (keywords.isEmpty) {
      // No keywords defined — if they said something, give credit
      final score = transcript.trim().length > 3 ? 0.75 : 0.3;
      return EvaluationResult(
        score: score,
        passed: score >= step.minAccuracyToPass,
        feedback: score >= step.minAccuracyToPass
            ? 'Good response! 👍'
            : 'Try to give a more complete answer.',
      );
    }

    // Count keyword matches
    int hits = 0;
    final hitList = <String>[];
    final missList = <String>[];

    for (final keyword in keywords) {
      final kw = keyword.toLowerCase();
      if (words.any((w) => w.contains(kw) || kw.contains(w))) {
        hits++;
        hitList.add(keyword);
      } else {
        missList.add(keyword);
      }
    }

    // Score: keyword overlap + bonus for having a meaningful response
    double score = keywords.isNotEmpty ? hits / keywords.length : 0.0;
    // Bonus: if they said a full sentence (5+ words), boost score
    if (words.length >= 4) score = min(1.0, score + 0.2);
    // Bonus: if they answered at all, at least 0.3
    if (transcript.trim().length > 5) score = max(score, 0.3);

    final passed = score >= step.minAccuracyToPass;

    String feedback;
    if (score >= 0.85) {
      feedback = 'Excellent response — you used the right vocabulary! 🌟';
    } else if (score >= 0.65) {
      feedback = 'Good answer! You got the key idea across. 👍';
    } else if (hits > 0) {
      feedback =
          'You used "${hitList.join(", ")}" — try to also include "${missList.take(2).join(", ")}".';
    } else {
      feedback =
          'Try using some of these words: "${keywords.take(3).join(", ")}".';
    }

    return EvaluationResult(
      score: score,
      passed: passed,
      feedback: feedback,
      vocabularyHit: hitList,
      vocabularyMiss: missList.take(2).toList(),
    );
  }

  /// Gap-fill fallback: check if any correct keyword appears in transcript.
  static EvaluationResult _gapFillFallback(
      LessonStep step, String transcript) {
    final words = transcript.toLowerCase().split(RegExp(r'\s+'));
    final correctAnswers = step.expectedKeywords;

    // Check if any correct word for the gap is present
    final gapCorrect = correctAnswers.any((answer) {
      final ans = answer.toLowerCase();
      return words.any((w) => w == ans || w.contains(ans));
    });

    // Check if they spoke a full sentence (not just the gap word)
    final spokeFullSentence = words.length >= 4;

    double score;
    if (gapCorrect && spokeFullSentence) {
      score = 0.95;
    } else if (gapCorrect) {
      score = 0.55; // Got the word but not the full sentence
    } else {
      score = 0.2;
    }

    final passed = score >= step.minAccuracyToPass;

    String feedback;
    if (gapCorrect && spokeFullSentence) {
      feedback = 'Perfect — you filled the gap and said the full sentence! 🌟';
    } else if (gapCorrect) {
      feedback =
          'You got the right word! Now try saying the complete sentence.';
    } else {
      feedback =
          'The missing word was "${correctAnswers.first}". Try again with the full sentence.';
    }

    // Reconstruct the full correct sentence
    final fullSentence = step.targetPhrase?.replaceAll(
      RegExp(r'_+'),
      correctAnswers.first,
    );

    return EvaluationResult(
      score: score,
      passed: passed,
      feedback: feedback,
      gapFilledCorrectly: gapCorrect,
      spokeFullSentence: spokeFullSentence,
      correctFullSentence: fullSentence,
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

  /// Generate a lesson summary using Gemini.
  static Future<LessonSummary> generateSummary({
    required SpeakingLesson lesson,
    required UserProgress progress,
    required GeminiSessionContext ctx,
  }) async {
    try {
      final avgScore = progress.stepResults.isEmpty
          ? 0.0
          : progress.stepResults.fold<double>(
                  0.0,
                  (sum, r) =>
                      sum +
                      (r.attempts.isNotEmpty
                          ? r.attempts.last.score
                          : 0.0)) /
              progress.stepResults.length;

      final allMistakes = progress.stepResults
          .expand((s) => s.attempts)
          .where((a) => a.specificIssue != null)
          .map((a) => a.specificIssue!)
          .toList();

      final prompt = PromptBuilders.lessonSummary(
        ctx: ctx,
        lesson: lesson,
        averageScore: avgScore,
        totalXpEarned: progress.totalXpEarned,
        allMistakes: allMistakes,
      );

      final json = await GeminiClient.callJSON(prompt: prompt);

      return LessonSummary(
        headline: json['headline'] as String? ?? 'Great practice session!',
        strength: json['strength'] as String? ?? 'You showed up and tried!',
        focusNext:
            json['focus_next'] as String? ?? 'Keep practicing regularly.',
        encouragement: json['encouragement'] as String? ??
            "You're making real progress — keep it up!",
        badgeEarned: json['badge_earned'] as String?,
      );
    } catch (e) {
      debugPrint('Summary generation failed: $e');
      return const LessonSummary(
        headline: 'Practice complete! 🎉',
        strength: 'You showed real determination.',
        focusNext: 'Review the words you found challenging.',
        encouragement: "Every practice session makes you stronger. Keep going!",
      );
    }
  }
}
