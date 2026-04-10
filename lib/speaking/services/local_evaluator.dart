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
      while (!tMatches[k]) {
        k++;
      }
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
      highlights: matched ? const ['Good response!'] : const [],
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
