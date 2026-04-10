import '../models/speaking_models.dart';
import 'context_builder.dart';

/// Prompt templates for all step types.
///
/// Each builder produces a carefully crafted prompt that follows the
/// **Context-First Pattern**: serialize the full session context,
/// then give Gemini a well-scoped evaluation task with explicit rules.
class PromptBuilders {
  PromptBuilders._();

  // ─── Step 1: Listen & Repeat ────────────────────────────────────

  static String listenAndRepeat({
    required GeminiSessionContext ctx,
    required String targetPhrase,
    required String userTranscript,
  }) {
    return '''
${ContextBuilder.serialize(ctx)}

=== TASK: LISTEN AND REPEAT EVALUATION ===
The learner just heard a native speaker say this phrase and tried to repeat it.

Target phrase: "$targetPhrase"
Learner said: "$userTranscript"

EVALUATION RULES (apply strictly in this order):
1. Core vocabulary: Did they say the essential words? (60%)
2. Word order: Is the grammar structure intact? (25%)
3. Completeness: Did they finish without cutting off? (15%)

LENIENCY RULES:
- Do NOT penalize regional accent or pronunciation variation
- Do NOT penalize filler sounds (um, uh, hmm)
- A1/A2 learners: Be generous — reward the attempt
- Speech recognition often mishears foreign words — if transcript is close, score high

RESPOND IN JSON:
{
  "score": 0.0-1.0,
  "passed": true or false (passed = score >= 0.65),
  "feedback": "One warm coaching sentence in ${ctx.nativeLanguage}",
  "specific_issue": null or "the exact word or syllable they missed",
  "celebration": null or "short celebration string if score > 0.85",
  "wrong_language": true or false
}
''';
  }

  // ─── Step 2: Read & Speak ───────────────────────────────────────

  static String readAndSpeak({
    required GeminiSessionContext ctx,
    required String targetPhrase,
    required List<String> acceptableVariants,
    required String userTranscript,
  }) {
    final variantsStr = acceptableVariants.isNotEmpty
        ? 'Also acceptable: ${acceptableVariants.map((v) => '"$v"').join(', ')}'
        : '';

    return '''
${ContextBuilder.serialize(ctx)}

=== TASK: READ AND SPEAK EVALUATION ===
Target phrase: "$targetPhrase"
$variantsStr
Learner said: "$userTranscript"

KEY DISTINCTION: There was no audio to copy. The learner had to internalize the
written text and produce speech — this is reading comprehension + speaking.

Score by:
- Did they convey the complete meaning? (50%)
- Were all key vocabulary items present? (30%)
- Was the structure grammatically intelligible? (20%)

Partial credit is intentional: 90% correct → score 0.85+

RESPOND IN JSON:
{
  "score": 0.0-1.0,
  "passed": true or false,
  "feedback": "Specific, warm, one sentence in ${ctx.nativeLanguage}",
  "missing_words": ["key words they dropped"],
  "celebration": null or "celebration string",
  "wrong_language": true or false
}
''';
  }

  // ─── Step 3: Prompt & Response ──────────────────────────────────

  static String promptResponse({
    required GeminiSessionContext ctx,
    required String question,
    required List<String> expectedKeywords,
    String? grammarFocus,
    required String userTranscript,
  }) {
    return '''
${ContextBuilder.serialize(ctx)}

=== TASK: OPEN-ENDED RESPONSE EVALUATION ===
Assess COMMUNICATION, not perfection. This is the most important rule.

Question asked: "$question"
Expected vocabulary/concepts: ${expectedKeywords.join(', ')}
${grammarFocus != null ? 'Grammar structure being practiced: $grammarFocus' : ''}
Learner responded: "$userTranscript"

SCORING RUBRIC:
- Did they understand and answer the question relevantly? → 50%
- Did they use vocabulary from the expected concepts list? → 30%
- Did they form a sentence a listener could understand? → 20%

LEVEL-BASED LENIENCY:
- A1/A2: Any meaningful attempt should score >= 0.6. Grammar errors are irrelevant.
- B1/B2: Expect a structured response but accent/minor errors are fine.
- C1: Expect appropriate vocabulary range and sentence complexity.

A learner who communicates the right idea imperfectly still PASSES.
Only fail if they answered the wrong thing entirely or said nothing relevant.

RESPOND IN JSON:
{
  "score": 0.0-1.0,
  "passed": true or false,
  "feedback": "Coach-style in ${ctx.nativeLanguage} — acknowledge what they said, then gently model a better version",
  "model_answer": "How a native speaker might naturally answer this question",
  "vocabulary_hit": ["words from expectedKeywords they actually used"],
  "vocabulary_miss": ["1-2 key words they could have included"],
  "wrong_language": true or false
}
''';
  }

  // ─── Step 4: Fill the Gap ───────────────────────────────────────

  static String fillTheGap({
    required GeminiSessionContext ctx,
    required String sentenceWithGap,
    required List<String> correctAnswers,
    required String userTranscript,
  }) {
    return '''
${ContextBuilder.serialize(ctx)}

=== TASK: FILL-IN-THE-GAP EVALUATION ===
Sentence with gap: "$sentenceWithGap"
Accepted words for the gap: ${correctAnswers.map((a) => '"$a"').join(' OR ')}
Learner said: "$userTranscript"

RULES:
1. They should speak the ENTIRE sentence, not just the gap word
2. If they only said the gap word → partial credit (0.5 max), coach to say full sentence
3. Accept any word from the accepted answers list
4. Minor pronunciation variation is fine — focus on correct word choice

RESPOND IN JSON:
{
  "score": 0.0-1.0,
  "passed": true or false,
  "gap_filled_correctly": true or false,
  "spoke_full_sentence": true or false,
  "feedback": "One focused sentence in ${ctx.nativeLanguage}",
  "correct_full_sentence": "The complete correct sentence for UI display",
  "wrong_language": true or false
}
''';
  }

  // ─── Step 5: Free Conversation ───────────────────────────────────

  static String freeConversationInstruction({
    required GeminiSessionContext ctx,
    required LessonStep step,
  }) {
    final persona = step.targetPhrase ?? 'a conversational partner';
    final scenario = step.promptQuestion ?? 'having a free conversation';
    
    return '''
${ContextBuilder.serialize(ctx)}

You are playing the role of: $persona
Scenario: $scenario

STRICT RULES:
1. ALWAYS respond in ${ctx.targetLanguage} first and foremost.
2. Keep your turns to 1-2 sentences MAX — this is a learner's exercise.
3. If the learner makes a grammar error: use the correct form naturally in YOUR next line (implicit correction — never lecture or correct explicitly).
4. After exactly 4 learner turns: end the conversation naturally, then append this exact block:

<<<EVAL>>>
{
  "score": 0.0-1.0,
  "passed": true or false,
  "feedback": "Overall impression in ${ctx.nativeLanguage}",
  "fluency": 0.0-1.0,
  "vocabulary_range": 0.0-1.0,
  "task_completion": 0.0-1.0,
  "highlights": ["two things they did well"],
  "focus_areas": ["one or two improvements"]
}
<<<END_EVAL>>>
''';
  }

  // ─── Lesson Summary ─────────────────────────────────────────────

  static String lessonSummary({
    required GeminiSessionContext ctx,
    required SpeakingLesson lesson,
    required double averageScore,
    required int totalXpEarned,
    required List<String> allMistakes,
  }) {
    return '''
${ContextBuilder.serialize(ctx)}

=== LESSON SUMMARY GENERATION ===
Lesson completed: "${lesson.title}"
Average score: ${(averageScore * 100).toStringAsFixed(0)}%
Total XP earned: $totalXpEarned
Issues during lesson: ${allMistakes.isNotEmpty ? allMistakes.join(', ') : 'none'}

Write a motivating, specific summary. Reference the actual topic ("${lesson.topic}").
Tone: friendly coach, not automated system.

RESPOND IN JSON:
{
  "headline": "One punchy sentence specific to ${lesson.topic}",
  "strength": "The one concrete thing they did best",
  "focus_next": "The one specific thing to practice next lesson",
  "encouragement": "A warm closing 1-sentence pep talk",
  "badge_earned": null or "badge_name"
}
''';
  }
}
