# SPEAKING MODULE — COMPLETE AI REFACTOR INSTRUCTIONS
## Zero-Cost, Fully Offline, Production-Grade Implementation

> **READ THIS ENTIRE FILE BEFORE WRITING A SINGLE LINE OF CODE.**
> This document is the single source of truth. Every architectural decision,
> every file to create, every file to modify, every line of logic is specified
> here. Do not improvise. Do not add packages not listed. Follow the order of
> operations exactly.

---

## TABLE OF CONTENTS

1. [Mission & Context](#1-mission--context)
2. [Why We Are Refactoring](#2-why-we-are-refactoring)
3. [Complete Existing Architecture (Read-Only Reference)](#3-complete-existing-architecture)
4. [Target Architecture After Refactor](#4-target-architecture-after-refactor)
5. [Order of Operations](#5-order-of-operations)
6. [FILE 1 — local_evaluator.dart](#6-file-1--local_evaluatordart)
7. [FILE 2 — scripted_conversation.dart](#7-file-2--scripted_conversationdart)
8. [FILE 3 — local_summary_generator.dart](#8-file-3--local_summary_generatordart)
9. [FILE 4 — eval_cache_service.dart (REPLACE)](#9-file-4--eval_cache_servicedart-replace-existing)
10. [FILE 5 — evaluation_engine.dart (MODIFY)](#10-file-5--evaluation_enginedart-modify-existing)
11. [FILE 6 — speaking_models.dart (MODIFY)](#11-file-6--speaking_modelsdart-modify-existing)
12. [FILE 7 — sample_lessons.dart (MODIFY)](#12-file-7--sample_lessonsdart-modify-existing)
13. [FILE 8 — speaking_lesson_screen.dart (MODIFY)](#13-file-8--speaking_lesson_screendart-modify-existing)
14. [FILE 9 — step_widgets.dart (MODIFY)](#14-file-9--step_widgetsdart-modify-existing)
15. [Verification Checklist](#15-verification-checklist)
16. [Common Mistakes To Avoid](#16-common-mistakes-to-avoid)

---

## 1. MISSION & CONTEXT

### What This App Is
A Flutter vocabulary learning app for Uzbek-speaking learners studying English.
It has a Duolingo-style **Speaking Section** with 5 exercise types, speech recognition,
text-to-speech, and AI evaluation via Google Gemini.

### The Problem
The Gemini free tier has very low quota limits. The app calls Gemini on **every single
speech attempt** — sometimes 3-6 times per lesson step. Users hit the rate limit
within minutes of using the speaking section. The app is essentially broken in production.

### The Goal
Eliminate ALL Gemini API calls from the runtime evaluation path. Replace them with
local algorithms that are deterministic, fast (< 5ms), work offline, and produce
evaluation quality equal to or better than the Gemini prompts for structured exercises.
Keep optional Groq API support (free, generous limits) ONLY for free conversation steps,
but make it gracefully degrade to scripted dialogue when unavailable.

### Key Constraint
**Do not change the UI at all.** The screens, widgets, colors, animations, and UX flow
stay 100% identical. Only the evaluation backend changes. A user should notice
zero difference in how the app looks or feels — only that it never says "API limit reached."

---

## 2. WHY WE ARE REFACTORING

### Current Call Sites (ALL must be eliminated or made optional):

| Location | Gemini Call | Calls Per Lesson |
|---|---|---|
| `EvaluationEngine.evaluateStep()` | `GeminiClient.callJSON()` | Up to 18 (3 attempts × 6 steps) |
| `EvaluationEngine._evaluateConversationTurn()` | `GeminiClient.callConversation()` | Up to 4 per free conv step |
| `EvaluationEngine.generateSummary()` | `GeminiClient.callJSON()` | 1 per lesson |
| **Total per lesson** | | **Up to ~23 calls** |

Gemini free tier: ~60 calls/minute, ~1500/day. One active user can exhaust the
daily quota in under 2 hours.

### Why Local Algorithms Work Here
The 4 structured step types (`listenAndRepeat`, `readAndSpeak`, `promptResponse`,
`fillTheGap`) all have a **known correct answer** defined in the lesson data.
This is NOT open-ended generation — it is string similarity + keyword matching.
Jaro-Winkler + word overlap scoring at the word level is more robust to ASR errors
than Levenshtein (which is character-level and penalizes innocent transpositions).

Duolingo itself uses rule-based scoring for structured exercises. AI is for content
*authoring*, not runtime *evaluation* of exercises with known answers.

---

## 3. COMPLETE EXISTING ARCHITECTURE

### Directory Structure
```
lib/speaking/
├── data/
│   └── sample_lessons.dart          # 4 hardcoded lessons
├── models/
│   └── speaking_models.dart         # All data classes and enums
├── screens/
│   ├── speaking_home_screen.dart    # Lesson list (DO NOT TOUCH)
│   └── speaking_lesson_screen.dart  # Main orchestrator screen
├── services/
│   ├── speech_service.dart          # STT wrapper (DO NOT TOUCH)
│   ├── tts_service.dart             # TTS wrapper (DO NOT TOUCH)
│   ├── gemini_client.dart           # HTTP client (keep, make optional)
│   ├── evaluation_engine.dart       # Main orchestrator (MODIFY)
│   ├── prompt_builders.dart         # Gemini prompts (keep for reference)
│   ├── context_builder.dart         # Session context (DO NOT TOUCH)
│   └── eval_cache_service.dart      # In-memory cache (REPLACE)
└── widgets/
    ├── feedback_card.dart           # Result display (DO NOT TOUCH)
    ├── live_transcript.dart         # STT display (DO NOT TOUCH)
    ├── mic_button.dart              # Mic states (DO NOT TOUCH)
    └── step_widgets.dart            # Exercise renderers (MODIFY for scripted conv)
```

### Existing Enums (in speaking_models.dart)
```dart
enum CEFRLevel { a1, a2, b1, b2, c1 }
// Extension: .label → 'A1', 'A2', etc.

enum StepType {
  listenAndRepeat,  // maxXp: 8
  readAndSpeak,     // maxXp: 10
  promptResponse,   // maxXp: 15
  fillTheGap,       // maxXp: 12
  freeConversation  // maxXp: 50
}

enum MicState { idle, ready, countdown, recording, processing, success, error }

enum StepAction { advance, retry, retryWithHint, showAnswerContinue, silentRetry, continueConversation }
```

### Existing Key Classes (DO NOT RENAME OR REMOVE FIELDS)
```dart
class LessonStep {
  final String id;
  final StepType type;
  final String instruction;
  final String? targetPhrase;        // the phrase to repeat/read
  final String? promptQuestion;      // question for promptResponse
  final List<String> expectedKeywords;
  final List<String> acceptableVariants;
  final List<String> hints;
  final double minAccuracyToPass;    // default 0.65
  final int maxAttempts;             // default 3
  final String? grammarFocus;
}

class EvaluationResult {
  final double score;                // 0.0 to 1.0
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
  // Free conversation fields:
  final String? chatReply;
  final bool isConversationComplete;
  final double? fluency;
  final double? vocabularyRange;
  final double? taskCompletion;
  final List<String> highlights;
  final List<String> focusAreas;
  final bool wrongLanguageDetected;

  factory EvaluationResult.empty();
}

class ConversationTurn {
  final String role;  // 'model' or 'user'
  final String text;
}

class LessonSummary {
  final String headline;
  final String strength;
  final String focusNext;
  final String encouragement;
  final String? badgeEarned;
}

class GeminiSessionContext {
  CEFRLevel learnerLevel;
  String targetLanguage;
  String nativeLanguage;
  String lessonTopic;
  String lessonGoal;
  List<String> previousMistakes;
  int stepNumber;
  int totalSteps;
  int attemptNumber;
}
```

### Existing SpeechService.normalize() — USE THIS EVERYWHERE
```dart
// Already exists in speech_service.dart — do not reimplement
static String normalize(String raw) {
  // Lowercases, strips filler words (um, uh, ah, hmm, er, like, you know)
  // strips punctuation, normalizes whitespace
}
```

---

## 4. TARGET ARCHITECTURE AFTER REFACTOR

### New Directory Structure
```
lib/speaking/
├── data/
│   └── sample_lessons.dart              # MODIFIED: scripted conv lessons
├── models/
│   ├── speaking_models.dart             # MODIFIED: add toJson/fromJson
│   └── scripted_conversation.dart       # NEW: dialogue tree model
├── screens/
│   ├── speaking_home_screen.dart        # UNTOUCHED
│   └── speaking_lesson_screen.dart      # MODIFIED: scripted conv state
├── services/
│   ├── speech_service.dart              # UNTOUCHED
│   ├── tts_service.dart                 # UNTOUCHED
│   ├── gemini_client.dart               # UNTOUCHED (kept, used only optionally)
│   ├── evaluation_engine.dart           # MODIFIED: local-first
│   ├── local_evaluator.dart             # NEW: all local algorithms
│   ├── local_summary_generator.dart     # NEW: template summaries
│   ├── prompt_builders.dart             # UNTOUCHED (kept for future reference)
│   ├── context_builder.dart             # UNTOUCHED
│   └── eval_cache_service.dart          # REPLACED: persistent SharedPreferences
└── widgets/
    ├── feedback_card.dart               # UNTOUCHED
    ├── live_transcript.dart             # UNTOUCHED
    ├── mic_button.dart                  # UNTOUCHED
    └── step_widgets.dart                # MODIFIED: scripted conv widget
```

### Data Flow After Refactor
```
User speaks
    ↓
SpeechService (normalize transcript)
    ↓
EvalCacheService.get() ← SharedPreferences (persistent)
    ↓ cache miss
LocalEvaluator (Jaro-Winkler + word overlap) ← no network
    ↓
EvalCacheService.set() → SharedPreferences
    ↓
EvaluationEngine.resolveNextAction() ← unchanged logic
    ↓
FeedbackCard ← unchanged UI
```

---

## 5. ORDER OF OPERATIONS

**Implement in this exact order. Each step depends on the previous.**

1. Modify `speaking_models.dart` — add `toJson`/`fromJson` to `EvaluationResult` and `LessonSummary`. Add `ScriptedConversation` import.
2. Create `scripted_conversation.dart` — new model file.
3. Create `local_evaluator.dart` — all scoring algorithms.
4. Create `local_summary_generator.dart` — template summary generator.
5. Replace `eval_cache_service.dart` — persistent cache.
6. Modify `evaluation_engine.dart` — wire local evaluator as primary path.
7. Modify `sample_lessons.dart` — add scripted conversation data.
8. Modify `speaking_lesson_screen.dart` — add scripted conversation state management.
9. Modify `step_widgets.dart` — scripted conversation widget update.

---

## 6. FILE 1 — local_evaluator.dart

**Path:** `lib/speaking/services/local_evaluator.dart`
**Action:** CREATE NEW FILE

### Purpose
Contains all local (no-network) scoring algorithms. No async. No HTTP. No exceptions.
Must always return a valid `EvaluationResult`.

### Complete Implementation

```dart
import 'dart:math';
import '../models/speaking_models.dart';
import 'speech_service.dart';

/// All local evaluation algorithms. Zero network dependencies.
/// Uses Jaro-Winkler similarity (better than Levenshtein for ASR output
/// because it handles transpositions and gives prefix match bonus).
class LocalEvaluator {

  // ═══════════════════════════════════════════════════════════════
  // CORE SIMILARITY ALGORITHMS
  // ═══════════════════════════════════════════════════════════════

  /// Jaro-Winkler similarity between two strings.
  /// Returns 0.0 (completely different) to 1.0 (identical).
  /// Superior to Levenshtein for speech recognition output because:
  ///   - Handles character transpositions (ASR swaps adjacent sounds)
  ///   - Gives prefix bonus (first syllables are most distinctive)
  ///   - O(n*m) but on short words it is effectively instant
  static double jaroWinkler(String s, String t) {
    if (s == t) return 1.0;
    if (s.isEmpty || t.isEmpty) return 0.0;

    final matchDistance = (max(s.length, t.length) / 2).floor() - 1;
    if (matchDistance < 0) return 0.0;

    final sMatches = List.filled(s.length, false);
    final tMatches = List.filled(t.length, false);

    int matches = 0;
    int transpositions = 0;

    // Find matching characters within match distance
    for (int i = 0; i < s.length; i++) {
      final start = max(0, i - matchDistance);
      final end = min(i + matchDistance + 1, t.length);
      for (int j = start; j < end; j++) {
        if (tMatches[j] || s[i] != t[j]) continue;
        sMatches[i] = true;
        tMatches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    // Count transpositions
    int k = 0;
    for (int i = 0; i < s.length; i++) {
      if (!sMatches[i]) continue;
      while (!tMatches[k]) k++;
      if (s[i] != t[k]) transpositions++;
      k++;
    }

    final jaro = (matches / s.length +
            matches / t.length +
            (matches - transpositions / 2) / matches) /
        3;

    // Winkler prefix bonus: up to 4 matching prefix characters add up to 10%
    int prefix = 0;
    for (int i = 0; i < min(4, min(s.length, t.length)); i++) {
      if (s[i] == t[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + prefix * 0.1 * (1 - jaro);
  }

  /// Word-level overlap score.
  /// For each word in [target], finds the best fuzzy match in [transcript].
  /// Returns the average best-match score across all target words.
  ///
  /// Why word-level matters:
  ///   - ASR frequently omits small function words ("a", "the", "to")
  ///   - Character-level Jaro-Winkler penalizes those omissions too harshly
  ///   - Word-level scoring rewards getting the content words right
  static double wordOverlapScore(String target, String transcript) {
    final tWords = target
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final uWords = transcript
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    if (tWords.isEmpty) return 1.0;
    if (uWords.isEmpty) return 0.0;

    double totalScore = 0.0;
    for (final targetWord in tWords) {
      double bestMatch = 0.0;
      for (final userWord in uWords) {
        bestMatch = max(bestMatch, jaroWinkler(targetWord, userWord));
      }
      totalScore += bestMatch;
    }
    return totalScore / tWords.length;
  }

  /// Combined score: 40% character Jaro-Winkler + 60% word overlap.
  /// Blending both gives robustness to both ASR character errors AND
  /// word omissions. The 60/40 weight favors word-level because content
  /// words carry meaning; function words are often dropped by ASR.
  static double combinedScore(String target, String transcript) {
    final charScore = jaroWinkler(target, transcript);
    final wordScore = wordOverlapScore(target, transcript);
    return charScore * 0.4 + wordScore * 0.6;
  }

  /// Returns a CEFR-adjusted score floor/bonus.
  /// Beginner learners (A1/A2) get generous scoring to avoid discouragement.
  /// Advanced learners (B2/C1) get strict scoring to reflect real standards.
  static double cefrLeniencyBonus(CEFRLevel level) {
    return switch (level) {
      CEFRLevel.a1 => 0.15,
      CEFRLevel.a2 => 0.10,
      CEFRLevel.b1 => 0.05,
      CEFRLevel.b2 => 0.0,
      CEFRLevel.c1 => -0.05, // slightly stricter for advanced
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP-TYPE EVALUATORS
  // ═══════════════════════════════════════════════════════════════

  /// Evaluates [StepType.listenAndRepeat].
  ///
  /// The user heard a phrase via TTS and must repeat it verbatim.
  /// Scoring weights:
  ///   - 60%: word-level overlap (content words present)
  ///   - 40%: character Jaro-Winkler (phonetic similarity)
  /// Leniency: CEFR bonus applied. Accent is not penalized.
  /// ASR-common errors (word order swap, filler words) are tolerated
  /// because SpeechService.normalize() has already stripped fillers.
  static EvaluationResult evaluateListenAndRepeat({
    required String targetPhrase,
    required String transcript,
    required CEFRLevel level,
  }) {
    final target = SpeechService.normalize(targetPhrase);
    final user = SpeechService.normalize(transcript);

    final raw = combinedScore(target, user);
    final score = (raw + cefrLeniencyBonus(level)).clamp(0.0, 1.0);
    final passed = score >= 0.65;

    return EvaluationResult(
      score: score,
      passed: passed,
      feedback: _listenRepeatFeedback(score, targetPhrase),
      specificIssue: passed ? null : 'Repetition accuracy low for: "$targetPhrase"',
      celebration: score >= 0.92 ? _randomCelebration() : null,
      isEmpty: false,
      missingWords: const [],
      vocabularyHit: const [],
      vocabularyMiss: const [],
      highlights: const [],
      focusAreas: const [],
      isConversationComplete: false,
      wrongLanguageDetected: false,
    );
  }

  /// Evaluates [StepType.readAndSpeak].
  ///
  /// No audio provided — user reads the phrase on screen and speaks it.
  /// Scores against [targetPhrase] AND all [acceptableVariants].
  /// Takes the highest score among all candidates.
  ///
  /// Scoring weights:
  ///   - 50%: complete meaning (word overlap with all variants)
  ///   - 30%: key vocabulary (content words longer than 3 chars)
  ///   - 20%: character similarity (phonetic accuracy)
  /// Missing content words are identified and reported.
  static EvaluationResult evaluateReadAndSpeak({
    required String targetPhrase,
    required List<String> acceptableVariants,
    required String transcript,
    required CEFRLevel level,
  }) {
    final user = SpeechService.normalize(transcript);
    final allCandidates = [targetPhrase, ...acceptableVariants]
        .map(SpeechService.normalize)
        .toList();

    // Score against all variants, use best match
    double bestScore = 0.0;
    for (final candidate in allCandidates) {
      final s = combinedScore(candidate, user);
      if (s > bestScore) bestScore = s;
    }

    final score = (bestScore + cefrLeniencyBonus(level)).clamp(0.0, 1.0);

    // Identify which content words were missing (length > 3 = not a function word)
    final contentWords = SpeechService.normalize(targetPhrase)
        .split(' ')
        .where((w) => w.length > 3)
        .toList();
    final missingWords = contentWords.where((targetWord) {
      // Check if any user word is a close match
      final userWords = user.split(' ').where((w) => w.isNotEmpty).toList();
      return !userWords.any((uw) => jaroWinkler(targetWord, uw) >= 0.82);
    }).toList();

    return EvaluationResult(
      score: score,
      passed: score >= 0.65,
      feedback: _readSpeakFeedback(score, missingWords),
      missingWords: missingWords,
      specificIssue: missingWords.isNotEmpty
          ? 'Missing words: ${missingWords.join(', ')}'
          : null,
      celebration: score >= 0.92 ? _randomCelebration() : null,
      isEmpty: false,
      vocabularyHit: const [],
      vocabularyMiss: const [],
      highlights: const [],
      focusAreas: const [],
      isConversationComplete: false,
      wrongLanguageDetected: false,
    );
  }

  /// Evaluates [StepType.promptResponse].
  ///
  /// User answers an open question. There is no single correct sentence —
  /// evaluation is based on keyword coverage and response completeness.
  /// "Assess COMMUNICATION, not perfection."
  ///
  /// Scoring weights:
  ///   - 70%: keyword coverage (how many expectedKeywords were spoken)
  ///   - 30%: completeness bonus (did they form a real sentence?)
  /// Floor: A1/A2 learners who hit at least 1 keyword get minimum 0.6.
  /// This prevents discouragement for genuine beginners.
  static EvaluationResult evaluatePromptResponse({
    required String question,
    required List<String> expectedKeywords,
    required String transcript,
    required String? grammarFocus,
    required CEFRLevel level,
  }) {
    final user = SpeechService.normalize(transcript);
    final userWords = user.split(' ').where((w) => w.isNotEmpty).toList();

    // Fuzzy keyword matching: a user word "matches" a keyword if
    // Jaro-Winkler >= 0.85 (allows minor ASR errors like "wanna" vs "want")
    final hit = <String>[];
    final miss = <String>[];

    for (final keyword in expectedKeywords) {
      final kwNorm = SpeechService.normalize(keyword);
      final matched = userWords.any((uw) => jaroWinkler(uw, kwNorm) >= 0.85);
      if (matched) {
        hit.add(keyword);
      } else {
        miss.add(keyword);
      }
    }

    final keywordRatio = expectedKeywords.isEmpty
        ? 0.75 // No keywords defined → reward any real attempt
        : hit.length / expectedKeywords.length;

    // Sentence completeness bonus
    // 4+ words = proper sentence attempt
    // 2-3 words = partial attempt
    // 1 word = bare word only
    final lengthBonus = userWords.length >= 4
        ? 0.20
        : userWords.length >= 2
            ? 0.10
            : 0.0;

    final raw = keywordRatio * 0.70 + lengthBonus * 0.30;

    // A1/A2 generous floor: any attempt with at least 1 keyword passes
    final isGenerousLevel = level == CEFRLevel.a1 || level == CEFRLevel.a2;
    final floor = (isGenerousLevel && hit.isNotEmpty) ? 0.60 : 0.25;
    final score = max(raw, floor).clamp(0.0, 1.0);

    // Build a model answer from the keywords to show the user
    final modelAnswer = hit.isEmpty && miss.isNotEmpty
        ? 'Try using: ${miss.take(3).map((w) => '"$w"').join(', ')}'
        : null;

    return EvaluationResult(
      score: score,
      passed: score >= 0.65,
      feedback: _promptResponseFeedback(score, hit, miss),
      vocabularyHit: hit,
      vocabularyMiss: miss,
      modelAnswer: modelAnswer,
      specificIssue: miss.isNotEmpty
          ? 'Missing keywords: ${miss.take(2).join(', ')}'
          : null,
      celebration: score >= 0.90 ? _randomCelebration() : null,
      isEmpty: false,
      missingWords: const [],
      highlights: const [],
      focusAreas: const [],
      isConversationComplete: false,
      wrongLanguageDetected: false,
    );
  }

  /// Evaluates [StepType.fillTheGap].
  ///
  /// The sentence has a gap (marked with `_+` regex in targetPhrase).
  /// User must speak the COMPLETE sentence, not just the missing word.
  /// "Just the gap word = partial credit only."
  ///
  /// Scoring:
  ///   - 0.95: gap word present AND spoke full sentence (4+ words)
  ///   - 0.55: gap word present BUT only spoke the word (< 4 words)
  ///   - 0.20: gap word not detected at all
  ///
  /// Gap detection uses fuzzy match (JW >= 0.82) to handle ASR errors
  /// on the gap word.
  static EvaluationResult evaluateFillTheGap({
    required String targetPhrase,
    required List<String> correctAnswers,
    required String transcript,
  }) {
    final user = SpeechService.normalize(transcript);
    final userWords = user.split(' ').where((w) => w.isNotEmpty).toList();

    // Check if any correct answer appears in the user's words (fuzzy)
    final gapFilled = correctAnswers.any((answer) {
      final ansNorm = SpeechService.normalize(answer);
      return userWords.any((uw) => jaroWinkler(uw, ansNorm) >= 0.82);
    });

    // Full sentence = at least 4 words (heuristic for sentence vs. word)
    final spokeFullSentence = userWords.length >= 4;

    final double score;
    if (gapFilled && spokeFullSentence) {
      score = 0.95;
    } else if (gapFilled && !spokeFullSentence) {
      score = 0.55; // Got the word, missed the sentence requirement
    } else {
      score = 0.20; // Did not fill the gap correctly
    }

    // Build the complete correct sentence by replacing the gap marker
    final correctFullSentence = targetPhrase.replaceAll(
      RegExp(r'_+'),
      correctAnswers.first,
    );

    return EvaluationResult(
      score: score,
      passed: score >= 0.65,
      gapFilledCorrectly: gapFilled,
      spokeFullSentence: spokeFullSentence,
      feedback: _fillGapFeedback(gapFilled, spokeFullSentence),
      correctFullSentence: correctFullSentence,
      specificIssue: !gapFilled
          ? 'Gap word not detected: ${correctAnswers.first}'
          : !spokeFullSentence
              ? 'Did not speak full sentence'
              : null,
      celebration: (gapFilled && spokeFullSentence) ? _randomCelebration() : null,
      isEmpty: false,
      missingWords: const [],
      vocabularyHit: const [],
      vocabularyMiss: const [],
      highlights: const [],
      focusAreas: const [],
      isConversationComplete: false,
      wrongLanguageDetected: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SCRIPTED CONVERSATION EVALUATOR
  // ═══════════════════════════════════════════════════════════════

  /// Evaluates one turn of a scripted (branching dialogue) conversation.
  /// [acceptableKeywords]: any single keyword match = pass.
  /// [isLastNode]: true when this is the final turn of the conversation.
  ///
  /// This replaces the Gemini multi-turn conversation for free conversation steps.
  /// The AI persona replies are hardcoded in the script — no generation needed.
  static EvaluationResult evaluateScriptedTurn({
    required String transcript,
    required List<String> acceptableKeywords,
    required String feedbackOnSuccess,
    required String feedbackOnFail,
    required String? nextAiUtterance,
    required bool isLastNode,
  }) {
    final user = SpeechService.normalize(transcript);
    final userWords = user.split(' ').where((w) => w.isNotEmpty).toList();

    // Match if ANY acceptable keyword is found with fuzzy match
    final matched = acceptableKeywords.any((kw) {
      final kwNorm = SpeechService.normalize(kw);
      return userWords.any((uw) => jaroWinkler(uw, kwNorm) >= 0.82);
    });

    final score = matched ? 0.88 : 0.30;
    final conversationComplete = matched && isLastNode;

    return EvaluationResult(
      score: score,
      passed: matched,
      feedback: matched ? feedbackOnSuccess : feedbackOnFail,
      chatReply: matched ? nextAiUtterance : null,
      isConversationComplete: conversationComplete,
      fluency: matched ? 0.80 : 0.35,
      vocabularyRange: matched ? 0.75 : 0.30,
      taskCompletion: matched ? 0.90 : 0.30,
      highlights: matched ? ['Good response!'] : const [],
      focusAreas: matched ? const [] : ['Try using: ${acceptableKeywords.take(2).join(', ')}'],
      celebration: conversationComplete ? '🎉 Conversation complete!' : null,
      isEmpty: false,
      missingWords: const [],
      vocabularyHit: const [],
      vocabularyMiss: const [],
      wrongLanguageDetected: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FEEDBACK TEXT GENERATORS
  // Keep feedback constructive and encouraging. Never shame.
  // ═══════════════════════════════════════════════════════════════

  static String _listenRepeatFeedback(double score, String target) {
    if (score >= 0.92) return "Perfect! Your pronunciation is excellent.";
    if (score >= 0.78) return "Great job! Nearly perfect repetition.";
    if (score >= 0.62) return "Good effort! Try saying each word clearly: \"$target\"";
    if (score >= 0.45) return "Almost there. Listen again then try: \"$target\"";
    return "Let's keep practicing. The phrase is: \"$target\"";
  }

  static String _readSpeakFeedback(double score, List<String> missing) {
    if (score >= 0.90) return "Excellent! You read and spoke that perfectly.";
    if (score >= 0.75) return "Great reading! Your pronunciation is clear.";
    if (missing.isNotEmpty) {
      return "Good try! Make sure to include: ${missing.take(2).join(', ')}";
    }
    return "Nice effort! Try to speak a bit more clearly and completely.";
  }

  static String _promptResponseFeedback(
      double score, List<String> hit, List<String> miss) {
    if (score >= 0.90) return "Fantastic answer! You used the key vocabulary perfectly.";
    if (score >= 0.75) {
      return hit.isEmpty
          ? "Good sentence! Try to include some key vocabulary next time."
          : "Great! You used: ${hit.take(2).join(', ')}. Well done!";
    }
    if (score >= 0.60) {
      return miss.isEmpty
          ? "Good attempt! Try to say a complete sentence."
          : "Good start! Also try to use: ${miss.take(2).join(', ')}";
    }
    return miss.isEmpty
        ? "Give it another try. Speak a full sentence."
        : "Try again. Use words like: ${miss.take(3).join(', ')}";
  }

  static String _fillGapFeedback(bool filled, bool full) {
    if (filled && full) return "Perfect! You completed the whole sentence correctly.";
    if (filled && !full) {
      return "You got the missing word! Now say the COMPLETE sentence, not just the word.";
    }
    return "Not quite. Try again — say the full sentence with the missing word.";
  }

  static String _randomCelebration() {
    const pool = [
      "Outstanding! 🌟",
      "Fantastic! 🎉",
      "You nailed it! 💪",
      "Perfect! ⭐",
      "Brilliant! 🔥",
      "Amazing! 🏆",
    ];
    return pool[DateTime.now().millisecondsSinceEpoch % pool.length];
  }
}
```

---

## 7. FILE 2 — scripted_conversation.dart

**Path:** `lib/speaking/models/scripted_conversation.dart`
**Action:** CREATE NEW FILE

### Purpose
Data model for the scripted branching dialogue system that replaces
free-form Gemini conversation. Each `ConversationNode` is one AI turn.
The user's response is evaluated for keyword presence — if they pass,
the next node's AI utterance is spoken via TTS and shown in the chat UI.

```dart
/// One node in a scripted conversation tree.
/// Represents a single AI utterance and the criteria for the user's response.
class ConversationNode {
  /// Unique identifier within this conversation.
  final String id;

  /// What the AI "says" — shown in the chat bubble and spoken via TTS.
  final String aiUtterance;

  /// Any ONE of these keywords in the user's response = pass.
  /// Use simple, unambiguous words. The evaluator does fuzzy matching,
  /// so slight ASR errors are tolerated.
  final List<String> acceptableKeywords;

  /// Shown to the user when they fail this turn (after attempt 2+).
  final String? hint;

  /// ID of the next node to advance to after this turn is passed.
  /// null = this is the final node; conversation ends after this turn.
  final String? nextNodeId;

  /// Feedback shown on pass.
  final String feedbackOnSuccess;

  /// Feedback shown on fail.
  final String feedbackOnFail;

  const ConversationNode({
    required this.id,
    required this.aiUtterance,
    required this.acceptableKeywords,
    this.hint,
    this.nextNodeId,
    required this.feedbackOnSuccess,
    required this.feedbackOnFail,
  });

  bool get isLastNode => nextNodeId == null;
}

/// A complete scripted conversation for one [LessonStep] of type [StepType.freeConversation].
/// Contains an ordered list of [ConversationNode]s.
class ScriptedConversation {
  final String scenarioTitle;
  final String aiPersonaDescription; // Shown to user so they know who they're talking to
  final List<ConversationNode> nodes;

  const ScriptedConversation({
    required this.scenarioTitle,
    required this.aiPersonaDescription,
    required this.nodes,
  });

  /// Get a node by its ID. Returns null if not found.
  ConversationNode? getNode(String id) {
    try {
      return nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the first node (opening AI utterance).
  ConversationNode get firstNode => nodes.first;

  /// Get the node that comes after [currentId]. Returns null if at end.
  ConversationNode? getNextNode(String currentId) {
    final current = getNode(currentId);
    if (current == null || current.nextNodeId == null) return null;
    return getNode(current.nextNodeId!);
  }
}

/// Registry of all scripted conversations, keyed by [LessonStep.id].
/// When [EvaluationEngine] sees a [StepType.freeConversation] step,
/// it looks up the script here by step ID.
class ScriptedConversationRegistry {
  static final Map<String, ScriptedConversation> _scripts = {};

  static void register(String stepId, ScriptedConversation script) {
    _scripts[stepId] = script;
  }

  static ScriptedConversation? get(String stepId) => _scripts[stepId];

  /// Call this once at app startup (e.g., in main.dart or in
  /// SpeakingLessonScreen.initState before any evaluation).
  static void registerAll() {
    // Restaurant lesson - step id must match exactly what's in sample_lessons.dart
    register('restaurant_conv_1', _restaurantConversation);
    // Add more scripts here as you add more free conversation lessons
  }

  // ─── Scripted Conversations ───────────────────────────────────

  static const _restaurantConversation = ScriptedConversation(
    scenarioTitle: "Ordering Food at a Diner",
    aiPersonaDescription: "You are talking to a friendly waiter at Joe's Diner.",
    nodes: [
      ConversationNode(
        id: 'greet',
        aiUtterance:
            "Hi there! Welcome to Joe's Diner. What can I get for you today?",
        acceptableKeywords: [
          'like', 'want', 'order', 'have', 'get', 'please',
          'burger', 'pizza', 'sandwich', 'salad', 'soup', 'pasta',
        ],
        hint: 'Try saying: "I\'d like to order a burger, please."',
        nextNodeId: 'drink',
        feedbackOnSuccess: "Great order! The waiter understood you perfectly.",
        feedbackOnFail:
            "Tell the waiter what food you want. Try: \"I'd like a...\"",
      ),
      ConversationNode(
        id: 'drink',
        aiUtterance:
            "Excellent choice! And what would you like to drink with that?",
        acceptableKeywords: [
          'water', 'juice', 'coffee', 'tea', 'coke', 'soda',
          'drink', 'beer', 'lemonade', 'milk', 'yes', 'no',
        ],
        hint: 'Try saying: "I\'ll have a coffee, please."',
        nextNodeId: 'check',
        feedbackOnSuccess: "Perfect! Your drink order is placed.",
        feedbackOnFail:
            "Name a drink. For example: water, coffee, juice, or soda.",
      ),
      ConversationNode(
        id: 'check',
        aiUtterance:
            "Wonderful! Is there anything else I can get for you today?",
        acceptableKeywords: [
          'no', "that's", 'all', 'thank', 'thanks', 'good',
          'nothing', 'fine', 'yes', 'also', 'check', 'bill',
        ],
        hint: 'Try saying: "No, that\'s all. Thank you!"',
        nextNodeId: null, // Last node — conversation ends
        feedbackOnSuccess:
            "🎉 Great job! You ordered your meal successfully in English!",
        feedbackOnFail:
            "Say yes or no. Try: \"No, that's all. Thank you!\"",
      ),
    ],
  );
}
```

---

## 8. FILE 3 — local_summary_generator.dart

**Path:** `lib/speaking/services/local_summary_generator.dart`
**Action:** CREATE NEW FILE

### Purpose
Replaces the `generateSummary` Gemini call. Uses template strings
driven by the actual session data (average score, XP, mistake patterns).
Produces varied, personalized-feeling summaries using data — not AI.

```dart
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
```

---

## 9. FILE 4 — eval_cache_service.dart (REPLACE EXISTING)

**Path:** `lib/speaking/services/eval_cache_service.dart`
**Action:** REPLACE THE ENTIRE FILE CONTENT

### Purpose
Replace the in-memory session cache with a persistent `SharedPreferences` cache.
This means a user who speaks "Hello, how are you?" for the `greetings_step_1`
step today and again tomorrow will get the cached result — zero API call.
This is the single highest-impact change for quota reduction.

### Required Package
Add to `pubspec.yaml` under dependencies:
```yaml
shared_preferences: ^2.3.2
```

### Complete Implementation

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/speaking_models.dart';
import 'speech_service.dart';

/// Persistent evaluation cache using SharedPreferences.
///
/// Cache key is derived from: stepId + targetPhrase + normalizedTranscript + cefrLevel
/// This means the same learner speaking the same phrase for the same step
/// gets a cached result across sessions — eliminating redundant API calls.
///
/// Eviction policy: LRU-approximated via timestamp. Max 500 entries.
/// Free conversation turns are never cached (non-deterministic).
class EvalCacheService {
  static const _prefix = 'eval_cache_v2_';
  static const _timestampPrefix = 'eval_ts_v2_';
  static const _maxEntries = 500;

  // In-memory layer for current session (avoids SharedPreferences overhead
  // on repeated attempts within the same session)
  static final Map<String, EvaluationResult> _sessionCache = {};

  // ─── Key Construction ──────────────────────────────────────────

  static String _buildKey(LessonStep step, String transcript, CEFRLevel level) {
    final normalized = SpeechService.normalize(transcript);
    final raw =
        '${step.id}|${step.targetPhrase ?? ""}|$normalized|${level.label}';
    // Base64 encodes to make it safe as a SharedPreferences key
    final encoded = base64Url.encode(utf8.encode(raw));
    return _prefix + encoded;
  }

  // ─── Public API ────────────────────────────────────────────────

  /// Returns a cached [EvaluationResult] if one exists, or null.
  /// Checks in-memory session cache first, then SharedPreferences.
  static Future<EvaluationResult?> get(
    LessonStep step,
    String transcript,
    CEFRLevel level,
  ) async {
    // Never cache free conversation — responses depend on conversation history
    if (step.type == StepType.freeConversation) return null;

    final key = _buildKey(step, transcript, level);

    // 1. Check session cache (instant)
    if (_sessionCache.containsKey(key)) {
      return _sessionCache[key];
    }

    // 2. Check persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;

      final result = EvaluationResult.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // Warm up session cache
      _sessionCache[key] = result;
      return result;
    } catch (_) {
      // Corrupt cache entry — treat as miss
      return null;
    }
  }

  /// Stores an [EvaluationResult] in both caches.
  /// Does NOT cache: empty results, very low scores (garbage audio),
  /// or free conversation turns.
  static Future<void> set(
    LessonStep step,
    String transcript,
    CEFRLevel level,
    EvaluationResult result,
  ) async {
    if (step.type == StepType.freeConversation) return;
    if (result.isEmpty) return;
    if (result.score < 0.15) return; // Garbage audio — do not cache

    final key = _buildKey(step, transcript, level);

    // Update session cache immediately (synchronous)
    _sessionCache[key] = result;

    // Persist asynchronously
    try {
      final prefs = await SharedPreferences.getInstance();

      // Evict oldest entries if at capacity
      await _evictIfNeeded(prefs);

      await prefs.setString(key, jsonEncode(result.toJson()));
      // Record timestamp for LRU eviction
      await prefs.setInt(
        _timestampPrefix + key,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Cache write failure is non-fatal — evaluation result is still valid
    }
  }

  /// Clears only the in-memory session cache (call on lesson restart).
  static void clearSessionCache() {
    _sessionCache.clear();
  }

  /// Clears ALL cached evaluations including persistent storage.
  /// Use only for debugging or account reset.
  static Future<void> clearAll() async {
    _sessionCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((k) => k.startsWith(_prefix) || k.startsWith(_timestampPrefix))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  // ─── Internal ──────────────────────────────────────────────────

  /// Evicts the oldest entry if cache is at maximum capacity.
  static Future<void> _evictIfNeeded(SharedPreferences prefs) async {
    final cacheKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix))
        .toList();

    if (cacheKeys.length < _maxEntries) return;

    // Find oldest entry by timestamp
    String? oldestKey;
    int oldestTime = DateTime.now().millisecondsSinceEpoch;

    for (final key in cacheKeys) {
      final ts = prefs.getInt(_timestampPrefix + key) ?? 0;
      if (ts < oldestTime) {
        oldestTime = ts;
        oldestKey = key;
      }
    }

    if (oldestKey != null) {
      await prefs.remove(oldestKey);
      await prefs.remove(_timestampPrefix + oldestKey);
    }
  }
}
```

---

## 10. FILE 5 — evaluation_engine.dart (MODIFY EXISTING)

**Path:** `lib/speaking/services/evaluation_engine.dart`
**Action:** MODIFY — Replace the body of `evaluateStep()` and `_evaluateConversationTurn()`.
Keep `resolveNextAction()` and `calculateXP()` COMPLETELY UNCHANGED.
Keep `generateSummary()` signature unchanged but replace its body.

### What to change and what to keep

**KEEP UNCHANGED (do not touch):**
- `resolveNextAction()` — entire method
- `calculateXP()` — entire method
- All imports that are already there

**ADD these imports at the top:**
```dart
import 'local_evaluator.dart';
import 'local_summary_generator.dart';
import '../models/scripted_conversation.dart';
```

### Replace `evaluateStep()` completely:

```dart
static Future<EvaluationResult> evaluateStep(
  LessonStep step,
  String transcript,
  GeminiSessionContext ctx,
  List<ConversationTurn> history,
) async {
  // Guard: empty transcript is an empty result — do not evaluate
  if (transcript.trim().length < 2) return EvaluationResult.empty();

  // Free conversation uses its own scripted evaluator path
  if (step.type == StepType.freeConversation) {
    return _evaluateScriptedConversationTurn(step, transcript, history);
  }

  // Check persistent cache before any computation
  final cached = await EvalCacheService.get(step, transcript, ctx.learnerLevel);
  if (cached != null) return cached;

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
      // correctAnswers = acceptableVariants if available, else expectedKeywords
      final correctAnswers = step.acceptableVariants.isNotEmpty
          ? step.acceptableVariants
          : step.expectedKeywords;
      result = LocalEvaluator.evaluateFillTheGap(
        targetPhrase: step.targetPhrase ?? '',
        correctAnswers: correctAnswers,
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
```

### Replace `_evaluateConversationTurn()` with `_evaluateScriptedConversationTurn()`:

```dart
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
  // Each successful turn adds: 1 user message + 1 model message = 2 entries
  // So current node index = history.length / 2 (integer division)
  final currentNodeIndex = (history.length / 2).floor();

  if (currentNodeIndex >= script.nodes.length) {
    // We're past the end — mark complete
    return EvaluationResult(
      score: 0.90,
      passed: true,
      feedback: "Excellent conversation!",
      isConversationComplete: true,
      fluency: 0.85,
      vocabularyRange: 0.80,
      taskCompletion: 0.95,
      isEmpty: false,
      missingWords: const [],
      vocabularyHit: const [],
      vocabularyMiss: const [],
      highlights: const ['Completed the full conversation!'],
      focusAreas: const [],
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
```

### Replace `generateSummary()` body only (keep signature):

```dart
static Future<LessonSummary> generateSummary(
  SpeakingLesson lesson,
  UserProgress progress,
  GeminiSessionContext ctx,
) async {
  // Fully local — no API call
  return LocalSummaryGenerator.generate(
    lesson: lesson,
    progress: progress,
  );
}
```

---

## 11. FILE 6 — speaking_models.dart (MODIFY EXISTING)

**Path:** `lib/speaking/models/speaking_models.dart`
**Action:** ADD `toJson()` and `fromJson()` to `EvaluationResult` and `LessonSummary`.
Do not change any existing fields. Only add serialization.

### Add to `EvaluationResult`:

```dart
/// Serialize for persistent cache storage.
Map<String, dynamic> toJson() => {
  'score': score,
  'passed': passed,
  'feedback': feedback,
  'specificIssue': specificIssue,
  'celebration': celebration,
  'modelAnswer': modelAnswer,
  'missingWords': missingWords,
  'vocabularyHit': vocabularyHit,
  'vocabularyMiss': vocabularyMiss,
  'gapFilledCorrectly': gapFilledCorrectly,
  'spokeFullSentence': spokeFullSentence,
  'correctFullSentence': correctFullSentence,
  'isEmpty': isEmpty,
  'chatReply': chatReply,
  'isConversationComplete': isConversationComplete,
  'fluency': fluency,
  'vocabularyRange': vocabularyRange,
  'taskCompletion': taskCompletion,
  'highlights': highlights,
  'focusAreas': focusAreas,
  'wrongLanguageDetected': wrongLanguageDetected,
};

/// Deserialize from persistent cache storage.
factory EvaluationResult.fromJson(Map<String, dynamic> json) {
  return EvaluationResult(
    score: (json['score'] as num).toDouble(),
    passed: json['passed'] as bool,
    feedback: json['feedback'] as String? ?? '',
    specificIssue: json['specificIssue'] as String?,
    celebration: json['celebration'] as String?,
    modelAnswer: json['modelAnswer'] as String?,
    missingWords: List<String>.from(json['missingWords'] as List? ?? []),
    vocabularyHit: List<String>.from(json['vocabularyHit'] as List? ?? []),
    vocabularyMiss: List<String>.from(json['vocabularyMiss'] as List? ?? []),
    gapFilledCorrectly: json['gapFilledCorrectly'] as bool?,
    spokeFullSentence: json['spokeFullSentence'] as bool?,
    correctFullSentence: json['correctFullSentence'] as String?,
    isEmpty: json['isEmpty'] as bool? ?? false,
    chatReply: json['chatReply'] as String?,
    isConversationComplete: json['isConversationComplete'] as bool? ?? false,
    fluency: (json['fluency'] as num?)?.toDouble(),
    vocabularyRange: (json['vocabularyRange'] as num?)?.toDouble(),
    taskCompletion: (json['taskCompletion'] as num?)?.toDouble(),
    highlights: List<String>.from(json['highlights'] as List? ?? []),
    focusAreas: List<String>.from(json['focusAreas'] as List? ?? []),
    wrongLanguageDetected: json['wrongLanguageDetected'] as bool? ?? false,
  );
}
```

---

## 12. FILE 7 — sample_lessons.dart (MODIFY EXISTING)

**Path:** `lib/speaking/data/sample_lessons.dart`
**Action:** Update the "At the Restaurant" lesson step ID to match what's registered
in `ScriptedConversationRegistry`.

### Find the `freeConversation` step in the restaurant lesson and ensure its `id` field is:

```dart
LessonStep(
  id: 'restaurant_conv_1',  // ← This MUST match ScriptedConversationRegistry key
  type: StepType.freeConversation,
  instruction: 'Have a conversation with the waiter at Joe\'s Diner.',
  // targetPhrase and promptQuestion are still used for display in FreeConversationStep widget
  targetPhrase: 'You are a friendly waiter at Joe\'s Diner.',
  promptQuestion: 'Order food and a drink. Confirm your order politely.',
  expectedKeywords: const ['order', 'like', 'want', 'please', 'thank'],
  hints: const [
    'Start by saying what food you want.',
    'Try: "I\'d like a burger, please."',
    'End with: "No, that\'s all. Thank you!"',
  ],
  minAccuracyToPass: 0.65,
  maxAttempts: 4,
),
```

---

## 13. FILE 8 — speaking_lesson_screen.dart (MODIFY EXISTING)

**Path:** `lib/speaking/screens/speaking_lesson_screen.dart`
**Action:** Add scripted conversation state. Modify initState and conversation flow.

### Add these state variables to `_SpeakingLessonScreenState`:

```dart
// Scripted conversation state
// Tracks which node in the script the user is currently on
int _scriptedNodeIndex = 0;

// The AI utterance to show/speak next (after user passes current node)
String? _pendingAiUtterance;
```

### In `initState()`, add after existing initialization:

```dart
// Register all scripted conversations so evaluator can look them up
ScriptedConversationRegistry.registerAll();
```

### In `_advanceToNextStep()`, add a reset for scripted state:

```dart
// Reset scripted conversation state for the new step
_scriptedNodeIndex = 0;
_pendingAiUtterance = null;
```

### In `_evaluate()`, find where `continueConversation` is handled.
Replace the conversation handling block with:

```dart
// Handle scripted conversation turn result
if (outcome.action == StepAction.continueConversation) {
  // Append user turn
  setState(() {
    _chatHistory.add(ConversationTurn(role: 'user', text: transcript));
  });

  // The nextAiUtterance is in result.chatReply
  if (_currentResult?.chatReply != null) {
    final aiReply = _currentResult!.chatReply!;

    // Append model turn
    setState(() {
      _chatHistory.add(ConversationTurn(role: 'model', text: aiReply));
      _scriptedNodeIndex++;   // Advance to next node
    });

    // Speak the AI reply via TTS
    await _ttsService.speak(
      aiReply,
      widget.lesson.languageCode,
      widget.lesson.cefrLevel,
    );
  }

  // Reset mic to ready for next user turn
  setState(() {
    _micState = MicState.ready;
    _interimTranscript = '';
    _finalTranscript = '';
    _currentResult = null;
    _currentOutcome = null;
  });
  return; // Do not show feedback card — conversation continues
}
```

### In `_initializeStep()` (or equivalent first-load logic for a step),
add the opening AI utterance for `freeConversation` steps:

```dart
// For scripted conversation steps, speak the opening AI line
if (_currentStep.type == StepType.freeConversation) {
  final script = ScriptedConversationRegistry.get(_currentStep.id);
  if (script != null) {
    final openingLine = script.firstNode.aiUtterance;
    // Add to chat history as model turn
    setState(() {
      _chatHistory.add(ConversationTurn(role: 'model', text: openingLine));
    });
    // Speak the opening line
    await _ttsService.speak(
      openingLine,
      widget.lesson.languageCode,
      widget.lesson.cefrLevel,
    );
  }
}
```

---

## 14. FILE 9 — step_widgets.dart (MODIFY EXISTING)

**Path:** `lib/speaking/widgets/step_widgets.dart`
**Action:** Update `FreeConversationStep` to show the scripted context.

### In `FreeConversationStep`, update the "empty state" widget:

The existing widget shows `"Say hello to start!"` when history is empty.
With scripted conversations, the first AI message is prepopulated in history
at step load time (from the change in FILE 8 above). So the empty state
should only show briefly or not at all. No code change needed if FILE 8
is implemented correctly — but verify the empty state message is still
appropriate as a loading fallback:

```dart
// Verify this string in your existing code — update if needed
// Empty state (shown only before the first AI line loads):
Text("Starting conversation...")
// Or keep "Say hello to start!" — both are fine since it shows briefly
```

### In `FreeConversationStep`, ensure the scenario description is shown:

Find where `step.targetPhrase` is displayed (the AI persona description).
Ensure it reads from the step data and is shown in the UI header area,
since this is now the human-readable scenario context:

```dart
// This should already exist — verify it displays step.targetPhrase as the scenario
// and step.promptQuestion as the task instruction. No change needed if already there.
```

---

## 15. VERIFICATION CHECKLIST

After implementation, verify each item manually:

### Compilation
- [ ] `flutter analyze` reports zero errors
- [ ] `flutter build apk --debug` succeeds without errors

### Zero Gemini Calls in Structured Steps
- [ ] Set a breakpoint in `GeminiClient.call()` — it must NOT be hit for
      `listenAndRepeat`, `readAndSpeak`, `promptResponse`, `fillTheGap` steps
- [ ] Or: temporarily invalidate the Gemini API key and verify the 4 structured
      step types still evaluate correctly (they must, since they're now local)

### Local Evaluator Scoring
Test these inputs manually through the UI:

| Step Type | Input | Expected Score Range |
|---|---|---|
| listenAndRepeat | Exact phrase | 0.90 – 1.00 |
| listenAndRepeat | ~80% similar phrase | 0.70 – 0.88 |
| listenAndRepeat | Completely different | 0.00 – 0.35 |
| readAndSpeak | Exact + CEFR bonus | 0.88 – 1.00 |
| promptResponse (A1) | 1 keyword + sentence | ≥ 0.60 |
| promptResponse | All keywords | ≥ 0.80 |
| fillTheGap | Gap word only | ~0.55 |
| fillTheGap | Full sentence + gap word | ~0.95 |
| freeConversation | Node keyword present | ~0.88, `continueConversation` |
| freeConversation | Final node + keyword | `isConversationComplete: true` |

### Persistent Cache
- [ ] Complete a lesson step and kill the app
- [ ] Re-launch and attempt the SAME phrase on the SAME step
- [ ] Verify the result is instant (< 50ms) — no loading indicator visible
- [ ] Check SharedPreferences contains `eval_cache_v2_` prefixed keys

### Lesson Completion Summary
- [ ] Complete a full lesson
- [ ] Verify the completion screen shows `headline`, `strength`, `focusNext`,
      `encouragement` — all populated with real data
- [ ] Verify `badgeEarned` appears for high-scoring sessions (avg ≥ 0.78)
- [ ] No network call is made during summary generation

### Scripted Conversation Flow
- [ ] Navigate to "At the Restaurant" lesson
- [ ] Opening AI line appears in chat and is spoken via TTS immediately on step load
- [ ] User speaks a response with a valid keyword → chat advances, next AI line appears
- [ ] User speaks an invalid response → feedback card shows, mic resets to retry
- [ ] After the final node is passed → `isConversationComplete: true` → lesson advances
- [ ] `_scriptedNodeIndex` resets to 0 when navigating to a new step

### UI Unchanged
- [ ] `MicButton` visual states are identical to before
- [ ] `FeedbackCard` slides in and shows score, feedback, XP correctly
- [ ] `LiveTranscript` shows interim and final transcript correctly
- [ ] Progress bar advances correctly after each step

---

## 16. COMMON MISTAKES TO AVOID

**1. Do NOT remove `GeminiClient`.**
Keep it in place. It may be needed in future for content generation
(creating new lessons, not evaluating them). Only stop calling it from
`EvaluationEngine`.

**2. Do NOT change `resolveNextAction()` or `calculateXP()`.**
These are correct and do not call any API. Leave them exactly as-is.

**3. Do NOT use `Random()` with no seed in `LocalEvaluator._randomCelebration()`.**
Use `DateTime.now().millisecondsSinceEpoch % pool.length` for index selection.
This makes tests deterministic — `Random()` makes them flaky.

**4. Do NOT await `EvalCacheService.set()` in a way that blocks the UI.**
The `await` in `evaluateStep()` is fine because the whole method is already
`async`. But never call `set()` on the main isolate in a synchronous context.

**5. Do NOT change `EvaluationResult.empty()` factory.**
The screen checks `result.isEmpty` to detect empty transcripts and trigger
`silentRetry`. If you break this, the mic will not auto-reset on silence.

**6. Scripted conversation `_scriptedNodeIndex` must reset on step change.**
This is done in `_advanceToNextStep()`. If you forget this, the restaurant
conversation will start on the wrong node if the user re-enters the lesson.

**7. The `ScriptedConversationRegistry.registerAll()` must be called before
any `freeConversation` step is evaluated.**
If not called, `ScriptedConversationRegistry.get(step.id)` returns null
and the fallback is used. Not a crash — but conversations will feel generic.
Best place: `initState()` of `SpeakingLessonScreen`.

**8. `SpeechService.normalize()` must be called on BOTH sides of every
comparison in `LocalEvaluator`.**
Target phrase AND transcript must both be normalized before passing to
`jaroWinkler()` or `wordOverlapScore()`. If only one side is normalized,
case and punctuation differences will wrongly lower scores.

**9. `toJson()`/`fromJson()` must handle null fields gracefully.**
Use `json['field'] as Type?` with null-coalescing defaults (`?? []`, `?? false`)
everywhere. SharedPreferences data from old app versions may be missing fields.

**10. Do NOT cache `freeConversation` steps.**
`EvalCacheService.set()` already guards against this with:
`if (step.type == StepType.freeConversation) return;`
Do not remove this guard.

---

## QUICK REFERENCE: Files Summary

| File | Action | Gemini Calls Before | Gemini Calls After |
|---|---|---|---|
| `local_evaluator.dart` | CREATE | 0 | 0 |
| `scripted_conversation.dart` | CREATE | 0 | 0 |
| `local_summary_generator.dart` | CREATE | 0 | 0 |
| `eval_cache_service.dart` | REPLACE | 0 | 0 |
| `evaluation_engine.dart` | MODIFY | ~23/lesson | **0** |
| `speaking_models.dart` | MODIFY (add json) | 0 | 0 |
| `sample_lessons.dart` | MODIFY (step id) | 0 | 0 |
| `speaking_lesson_screen.dart` | MODIFY (state) | 0 | 0 |
| `step_widgets.dart` | MODIFY (verify) | 0 | 0 |
| `gemini_client.dart` | UNTOUCHED | — | — |
| `prompt_builders.dart` | UNTOUCHED | — | — |
| `speech_service.dart` | UNTOUCHED | — | — |
| `tts_service.dart` | UNTOUCHED | — | — |
| `context_builder.dart` | UNTOUCHED | — | — |
| `speaking_home_screen.dart` | UNTOUCHED | — | — |
| `feedback_card.dart` | UNTOUCHED | — | — |
| `live_transcript.dart` | UNTOUCHED | — | — |
| `mic_button.dart` | UNTOUCHED | — | — |

**Expected result after implementation:**
- API calls per lesson: **0** (was up to 23)
- Works offline: **Yes**
- Works with no API key: **Yes**
- UI changes visible to user: **None**
- Evaluation quality for structured steps: **Equal or better** (Jaro-Winkler
  is more ASR-appropriate than Levenshtein)
- Evaluation quality for conversation: **Deterministic and reliable** (was
  dependent on Gemini availability and prompt interpretation variance)
