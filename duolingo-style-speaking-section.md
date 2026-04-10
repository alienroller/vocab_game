# 🎙️ Duolingo-Style Speaking Section — Senior Architecture Guide
### Powered by Gemini API · Context-First Evaluation Strategy

---

## Why Gemini — And How to Make It Work Great

Gemini isn't the sharpest model at zero-shot language evaluation. But that's not how we're using it.

**Gemini's actual strengths:**
- Massive context window (1M tokens on Flash/Pro) — send everything
- Very fast on `gemini-2.0-flash` — sub-second on simple evaluations
- Strong instruction-following when the task is well-scoped
- Native JSON output mode (`responseMimeType`) — eliminates parse errors
- Free tier is generous enough to build and test the full system

**The strategy:** Don't ask Gemini to figure things out. Tell it everything — learner level, lesson topic, previous mistakes this session, what a correct answer looks like, what partial credit means. Gemini with full context outperforms a smarter model with a lazy prompt. Every single call in this system follows the **Context-First Pattern**.

---

## The Context-First Pattern (Core Principle)

Every Gemini call gets a **Session Context Object** prepended. This is built once at lesson start and grows richer after every step:

```typescript
type GeminiSessionContext = {
  learnerLevel: CEFRLevel;         // "A1" | "A2" | "B1" | "B2" | "C1"
  targetLanguage: string;          // "Spanish", "French", "Japanese"
  nativeLanguage: string;          // "English" — for feedback language
  lessonTopic: string;             // "Ordering Coffee at a Café"
  lessonGoal: string;              // "Learner can order food/drink in a café scenario"
  previousMistakes: string[];      // Collected across steps this session
  stepNumber: number;              // 1 of 8 — Gemini knows where in the arc
  totalSteps: number;
  attemptNumber: number;           // 1st try vs 3rd try changes tone
};
```

This is passed to every evaluation call. It's why Gemini works reliably here — it always has the full picture.

---

## System Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        SPEAKING MODULE                           │
│                                                                  │
│  ┌──────────┐   ┌──────────┐   ┌────────────┐   ┌───────────┐  │
│  │  LESSON  │ → │  STEP    │ → │  EVALUATE  │ → │   NEXT    │  │
│  │  ENGINE  │   │  ENGINE  │   │   ENGINE   │   │   STEP    │  │
│  └──────────┘   └──────────┘   └────────────┘   └───────────┘  │
│        ↑               ↑               ↑                         │
│        └───────────────┴───────────────┘                         │
│              Gemini API Layer (Context-First)                     │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Session Context Object  ←  grows richer each step       │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### Core Systems:
1. **Lesson Engine** — Curates and sequences content per user level
2. **Step Engine** — Renders the right exercise type (5 types)
3. **Speech Pipeline** — Browser mic → Web Speech API → Normalization → Gemini
4. **Evaluation Engine** — Gemini assesses with full session context
5. **Progression Engine** — Decides what comes next based on performance
6. **XP / Streak Layer** — Gamification hooks

---

## Phase 0: Gemini API Setup

### 0.1 — Which Model to Use

| Model | Use Case | Why |
|---|---|---|
| `gemini-2.0-flash` | Steps 1–4 (all evaluations) | Fastest, cheap, accurate enough with good context |
| `gemini-1.5-pro` | Step 5 (free conversation) | Better multi-turn reasoning, worth the cost |
| `gemini-2.0-flash` | Lesson summary generation | Speed matters here, quality is fine |

**Default to Flash.** Only upgrade to Pro for the conversation step.

### 0.2 — API Client Setup

```typescript
// geminiClient.ts
const GEMINI_API_KEY = process.env.NEXT_PUBLIC_GEMINI_API_KEY;
const FLASH_MODEL = 'gemini-2.0-flash';
const PRO_MODEL   = 'gemini-1.5-pro';

async function callGemini(
  prompt: string,
  model: string = FLASH_MODEL,
  expectJSON: boolean = true
): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

  const body = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: expectJSON ? 0.1 : 0.7,  // Low temp for evals, higher for conversation
      maxOutputTokens: expectJSON ? 512 : 1024,
      // Force JSON output — Gemini's killer feature for structured evals
      ...(expectJSON && { responseMimeType: "application/json" })
    }
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  const data = await res.json();
  return data.candidates[0].content.parts[0].text;
}
```

**Key:** `responseMimeType: "application/json"` is a Gemini-native feature that forces valid JSON output. Use it on every evaluation call. This alone eliminates ~90% of parsing bugs in AI-powered apps.

### 0.3 — The Context Builder

```typescript
// contextBuilder.ts
function buildSessionContext(
  lesson: SpeakingLesson,
  progress: UserProgress,
  currentStep: LessonStep
): GeminiSessionContext {
  const previousMistakes = progress.stepResults
    .flatMap(r => r.attempts)
    .filter(a => a.score < 0.7)
    .map(a => a.specificIssue)
    .filter(Boolean)
    .slice(-5); // Last 5 mistakes only — keep prompts tight

  return {
    learnerLevel: lesson.cefrLevel,
    targetLanguage: lesson.language,
    nativeLanguage: progress.nativeLanguage,
    lessonTopic: lesson.topic,
    lessonGoal: lesson.goal,
    previousMistakes,
    stepNumber: progress.currentStepIndex + 1,
    totalSteps: lesson.steps.length,
    attemptNumber: (progress.stepResults[progress.currentStepIndex]?.attempts.length ?? 0) + 1
  };
}

function serializeContext(ctx: GeminiSessionContext): string {
  return `
=== LEARNER SESSION CONTEXT ===
Language being learned: ${ctx.targetLanguage}
Learner's native language: ${ctx.nativeLanguage}
CEFR proficiency level: ${ctx.learnerLevel}
Lesson topic: ${ctx.lessonTopic}
Lesson goal: ${ctx.lessonGoal}
Current step: ${ctx.stepNumber} of ${ctx.totalSteps}
Attempt number: ${ctx.attemptNumber}
${ctx.previousMistakes.length > 0
  ? `Known struggle areas this session: ${ctx.previousMistakes.join(', ')}`
  : 'No prior mistakes recorded this session.'}
================================
`.trim();
}
```

Every single prompt starts with `serializeContext(ctx)`. This is the entire secret.

---

## Phase 1: Data Model & Content Schema

### 1.1 — Lesson Schema

```typescript
type SpeakingLesson = {
  id: string;
  title: string;           // "Ordering Coffee"
  language: string;        // "Spanish", "French", "Japanese"
  languageCode: string;    // "es-ES", "fr-FR" — for Web Speech API
  cefrLevel: "A1" | "A2" | "B1" | "B2" | "C1";
  topic: string;
  goal: string;            // Explicit goal used in every Gemini prompt
  steps: LessonStep[];
  estimatedMinutes: number;
  xpReward: number;
};
```

### 1.2 — Step Schema

```typescript
type StepType =
  | "listen_and_repeat"
  | "read_and_speak"
  | "prompt_response"
  | "fill_the_gap"
  | "free_conversation";

type LessonStep = {
  id: string;
  type: StepType;
  instruction: string;
  targetPhrase?: string;
  promptQuestion?: string;
  expectedKeywords?: string[];    // What Gemini should listen for
  acceptableVariants?: string[];  // Alternative correct phrasings
  audioUrl?: string;
  hints?: string[];
  minAccuracyToPass: number;
  maxAttempts: number;
  grammarFocus?: string;          // e.g. "subjunctive mood" — tells Gemini what to watch
};
```

### 1.3 — Progress Schema

```typescript
type SpeechAttempt = {
  transcript: string;
  score: number;
  feedback: string;
  specificIssue?: string;   // The exact word Gemini flagged
  timestamp: Date;
};
```

---

## Phase 2: The Five Step Types

### Step Type 1: Listen & Repeat (`listen_and_repeat`)

**UX Flow:**
```
IDLE → PLAYING_AUDIO → AWAITING_USER → RECORDING → PROCESSING → RESULT
```

**Gemini Prompt:**
```typescript
function buildListenRepeatPrompt(
  ctx: GeminiSessionContext,
  targetPhrase: string,
  userTranscript: string
): string {
  return `
${serializeContext(ctx)}

=== TASK: LISTEN AND REPEAT EVALUATION ===
The learner just heard a native speaker say this phrase and tried to repeat it.

Target phrase: "${targetPhrase}"
Learner said: "${userTranscript}"

EVALUATION RULES (apply strictly in this order):
1. Core vocabulary: Did they say the essential words? (60%)
2. Word order: Is the grammar structure intact? (25%)
3. Completeness: Did they finish without cutting off? (15%)

LENIENCY RULES:
- Do NOT penalize regional accent or pronunciation variation
- Do NOT penalize filler sounds (um, uh, hmm)
- A1/A2 learners: Be generous — reward the attempt
- Web Speech API often mishears foreign words — if transcript is close, score high

RESPOND IN JSON:
{
  "score": 0.0-1.0,
  "passed": true or false (passed = score >= 0.65),
  "feedback": "One warm coaching sentence in ${ctx.nativeLanguage}",
  "specific_issue": null or "the exact word or syllable they missed",
  "celebration": null or "short celebration string if score > 0.85"
}
  `.trim();
}
```

---

### Step Type 2: Read & Speak (`read_and_speak`)

**Gemini Prompt:**
```typescript
function buildReadSpeakPrompt(
  ctx: GeminiSessionContext,
  targetPhrase: string,
  acceptableVariants: string[],
  userTranscript: string
): string {
  return `
${serializeContext(ctx)}

=== TASK: READ AND SPEAK EVALUATION ===
Target phrase: "${targetPhrase}"
${acceptableVariants.length > 0 ? `Also acceptable: ${acceptableVariants.map(v => `"${v}"`).join(', ')}` : ''}
Learner said: "${userTranscript}"

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
  "celebration": null or "celebration string"
}
  `.trim();
}
```

---

### Step Type 3: Prompt & Response (`prompt_response`)

The most important step type. No single correct answer — Gemini evaluates *communication success*.

**Gemini Prompt:**
```typescript
function buildPromptResponsePrompt(
  ctx: GeminiSessionContext,
  question: string,
  expectedKeywords: string[],
  grammarFocus: string | undefined,
  userTranscript: string
): string {
  return `
${serializeContext(ctx)}

=== TASK: OPEN-ENDED RESPONSE EVALUATION ===
Assess COMMUNICATION, not perfection. This is the most important rule.

Question asked: "${question}"
Expected vocabulary/concepts: ${expectedKeywords.join(', ')}
${grammarFocus ? `Grammar structure being practiced: ${grammarFocus}` : ''}
Learner responded: "${userTranscript}"

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
  "vocabulary_miss": ["1-2 key words they could have included"]
}
  `.trim();
}
```

---

### Step Type 4: Fill the Gap (`fill_the_gap`)

**Gemini Prompt:**
```typescript
function buildFillGapPrompt(
  ctx: GeminiSessionContext,
  sentenceWithGap: string,
  correctAnswers: string[],
  userTranscript: string
): string {
  return `
${serializeContext(ctx)}

=== TASK: FILL-IN-THE-GAP EVALUATION ===
Sentence with gap: "${sentenceWithGap}"
Accepted words for the gap: ${correctAnswers.map(a => `"${a}"`).join(' OR ')}
Learner said: "${userTranscript}"

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
  "correct_full_sentence": "The complete correct sentence for UI display"
}
  `.trim();
}
```

---

### Step Type 5: Free Conversation (`free_conversation`)

Use `gemini-1.5-pro` here. Maintain conversation history. This is the graduation exercise.

```typescript
// conversationEngine.ts
type ConversationTurn = {
  role: "model" | "user";
  parts: [{ text: string }];
};

async function conductConversationTurn(
  ctx: GeminiSessionContext,
  scenario: string,
  persona: string,
  history: ConversationTurn[],
  userTranscript: string
): Promise<ConversationResponse> {

  const systemInstruction = `
${serializeContext(ctx)}

You are playing the role of: ${persona}
Scenario: ${scenario}

STRICT RULES:
1. ALWAYS respond in ${ctx.targetLanguage} first
2. Keep your turns to 1-2 sentences MAX — this is a learner's exercise
3. If the learner makes a grammar error: use the correct form naturally in YOUR next line
   (implicit correction — never lecture or correct explicitly)
4. After exactly 4 learner turns: end the conversation naturally, then append:

<<<EVAL>>>
{
  "overall_score": 0.0-1.0,
  "fluency": 0.0-1.0,
  "vocabulary_range": 0.0-1.0,
  "task_completion": 0.0-1.0,
  "highlights": ["two things they did well"],
  "focus_areas": ["one or two improvements"],
  "xp_earned": 10-50
}
<<<END_EVAL>>>
  `.trim();

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${PRO_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const body = {
    system_instruction: { parts: [{ text: systemInstruction }] },
    contents: [
      ...history,
      { role: "user", parts: [{ text: userTranscript }] }
    ],
    generationConfig: { temperature: 0.7, maxOutputTokens: 512 }
  };

  const data = await (await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })).json();
  const rawText = data.candidates[0].content.parts[0].text;

  const evalMatch = rawText.match(/<<<EVAL>>>([\s\S]*?)<<<END_EVAL>>>/);
  const reply = rawText.replace(/<<<EVAL>>>[\s\S]*?<<<END_EVAL>>>/, '').trim();

  return {
    reply,
    evaluation: evalMatch ? JSON.parse(evalMatch[1].trim()) : null,
    isComplete: !!evalMatch
  };
}
```

---

## Phase 3: The Speech Pipeline

### 3.1 — Web Speech API

```typescript
class SpeechService {
  private recognition: SpeechRecognition;

  init(languageCode: string) {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SR();
    this.recognition.lang = languageCode;   // "es-ES", "fr-FR", "ja-JP"
    this.recognition.continuous = false;
    this.recognition.interimResults = true;
    this.recognition.maxAlternatives = 3;
  }

  async record(onInterim: (text: string) => void): Promise<TranscriptResult> {
    return new Promise((resolve, reject) => {
      let final = '';

      this.recognition.onresult = (e) => {
        for (let i = e.resultIndex; i < e.results.length; i++) {
          if (e.results[i].isFinal) final += e.results[i][0].transcript;
          else onInterim(e.results[i][0].transcript);
        }
      };

      this.recognition.onend = () => resolve({
        transcript: final.trim(),
        confidence: this.recognition.results?.[0]?.[0]?.confidence ?? 0.5
      });

      this.recognition.onerror = (e) => {
        if (e.error === 'no-speech') resolve({ transcript: '', confidence: 0 });
        else reject(e);
      };

      this.recognition.start();
    });
  }
}
```

### 3.2 — Transcript Normalization

Run this BEFORE sending to Gemini. Without it, Gemini wastes tokens on noise:

```typescript
function normalizeTranscript(raw: string): string {
  return raw
    .toLowerCase()
    .trim()
    .replace(/\b(um|uh|ah|hmm|er|like|you know)\b/gi, '')
    .replace(/[.,!?;:]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
```

### 3.3 — Confidence-Based Fallback

```typescript
async function transcribeWithFallback(
  languageCode: string,
  onInterim: (t: string) => void
): Promise<string> {
  try {
    const result = await speechService.record(onInterim);

    if (result.confidence < 0.35 || result.transcript.length < 2) {
      return promptRetry("We didn't catch that — try once more");
    }

    return normalizeTranscript(result.transcript);
  } catch {
    return promptManualInput(); // Never leave the user stuck
  }
}
```

---

## Phase 4: The Evaluation Engine

### 4.1 — Main Dispatcher

```typescript
async function evaluateStep(
  step: LessonStep,
  transcript: string,
  ctx: GeminiSessionContext
): Promise<EvaluationResult> {

  if (!transcript || transcript.length < 2) {
    return { score: 0, passed: false, feedback: "We didn't hear anything — try again!", isEmpty: true };
  }

  const promptBuilders = {
    listen_and_repeat: () => buildListenRepeatPrompt(ctx, step.targetPhrase!, transcript),
    read_and_speak:    () => buildReadSpeakPrompt(ctx, step.targetPhrase!, step.acceptableVariants ?? [], transcript),
    prompt_response:   () => buildPromptResponsePrompt(ctx, step.promptQuestion!, step.expectedKeywords ?? [], step.grammarFocus, transcript),
    fill_the_gap:      () => buildFillGapPrompt(ctx, step.targetPhrase!, step.expectedKeywords ?? [], transcript),
  };

  const prompt = promptBuilders[step.type]?.();
  if (!prompt) throw new Error('Use conversationEngine for free_conversation');

  const raw = await callGemini(prompt, FLASH_MODEL, true);
  const result = JSON.parse(raw); // Safe — responseMimeType guarantees valid JSON

  // Feed mistake back into context for subsequent steps
  if (result.specific_issue) ctx.previousMistakes.push(result.specific_issue);

  return result;
}
```

### 4.2 — Scoring → Next Action

```typescript
function resolveNextAction(
  result: EvaluationResult,
  step: LessonStep,
  attemptNumber: number
): StepOutcome {

  if (result.isEmpty) return { action: 'SILENT_RETRY' };

  if (result.passed) {
    return {
      action: 'ADVANCE',
      xpEarned: calculateXP(result.score, attemptNumber),
      animation: result.score > 0.9 ? 'PERFECT' : 'CORRECT'
    };
  }

  if (attemptNumber >= 2 && step.hints?.length) {
    const hintIndex = Math.min(attemptNumber - 2, step.hints.length - 1);
    return { action: 'RETRY_WITH_HINT', hint: step.hints[hintIndex] };
  }

  if (attemptNumber >= step.maxAttempts) {
    return {
      action: 'SHOW_ANSWER_CONTINUE',
      xpEarned: 2,  // Participation XP — never zero, never demoralizing
      modelAnswer: result.model_answer ?? result.correct_full_sentence
    };
  }

  return { action: 'RETRY' };
}

function calculateXP(score: number, attempts: number): number {
  return Math.max(1, Math.round(score * 10) - Math.max(0, attempts - 1) * 2);
}
```

---

## Phase 5: Progression Engine

### 5.1 — Context Grows After Every Step

By Step 6, Gemini knows every mistake from Steps 1–5 and auto-adjusts tone and leniency. This is free adaptive learning with zero ML:

```typescript
function updateContextAfterStep(ctx: GeminiSessionContext, result: StepResult): void {
  ctx.stepNumber++;
  ctx.attemptNumber = 1;

  const newMistakes = result.attempts
    .filter(a => a.specificIssue)
    .map(a => a.specificIssue!);

  ctx.previousMistakes = [...ctx.previousMistakes, ...newMistakes].slice(-5);
}
```

### 5.2 — Lesson Summary Generation

```typescript
async function generateLessonSummary(
  lesson: SpeakingLesson,
  progress: UserProgress,
  ctx: GeminiSessionContext
): Promise<LessonSummary> {
  const avgScore = calculateAverageScore(progress.stepResults);
  const allMistakes = progress.stepResults
    .flatMap(s => s.attempts)
    .filter(a => a.specificIssue)
    .map(a => a.specificIssue);

  const prompt = `
${serializeContext(ctx)}

=== LESSON SUMMARY GENERATION ===
Lesson completed: "${lesson.title}"
Average score: ${(avgScore * 100).toFixed(0)}%
Total XP earned: ${progress.totalXpEarned}
Issues during lesson: ${allMistakes.join(', ') || 'none'}

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
  `.trim();

  return JSON.parse(await callGemini(prompt, FLASH_MODEL, true));
}
```

---

## Phase 6: UI/UX Component Architecture

### 6.1 — Component Tree

```
<SpeakingLesson>
  ├── <LessonHeader>          // Progress bar, XP, step X of N
  ├── <StepRenderer>          // Switches on step.type
  │   ├── <ListenAndRepeat>
  │   ├── <ReadAndSpeak>
  │   ├── <PromptResponse>
  │   ├── <FillTheGap>
  │   └── <FreeConversation>  // Own conversation history state
  ├── <MicButton>             // Shared — the most important component
  ├── <WaveformVisualizer>    // Real-time audio feedback
  ├── <LiveTranscript>        // Shows STT result as user speaks
  ├── <FeedbackCard>          // Gemini's feedback after each attempt
  ├── <HintDrawer>            // Progressive hint reveal
  └── <LessonComplete>        // Scorecard + summary from Gemini
```

### 6.2 — Mic Button States

```typescript
type MicState =
  | "idle"        // Neutral, waiting
  | "ready"       // Pulsing — "Tap to speak"
  | "countdown"   // 3-2-1 before auto-record
  | "recording"   // Red + live waveform
  | "processing"  // Spinner — "Evaluating..."
  | "success"     // Green flash
  | "error";      // Soft orange — "Try again"

// Rule: user must NEVER be unsure what the mic is doing
// Every state transition = color change + label change + animation change
```

### 6.3 — Feedback Card

```typescript
// Color psychology:
// "correct"   → Green  — safe, winning
// "partial"   → Amber  — growth mindset, not failure
// "incorrect" → Soft orange/salmon — NEVER harsh red
//               Red = shame. Orange = "almost, try again"
```

---

## Phase 7: Gemini-Specific Optimizations

### 7.1 — `responseMimeType` on Every Eval Call

```typescript
generationConfig: {
  responseMimeType: "application/json"
}
// Forces valid JSON — eliminates ~90% of parsing bugs
// Use on all Steps 1–4 and lesson summary
// Do NOT use on Step 5 (conversation reply is prose)
```

### 7.2 — Cache Common Evaluations

Phrases like "Buenos días" will be attempted thousands of times. Cache by normalized key:

```typescript
const evalCache = new Map<string, EvaluationResult>();

async function evaluateWithCache(step: LessonStep, transcript: string, ctx: GeminiSessionContext) {
  const key = btoa(`${step.targetPhrase}|${transcript}|${ctx.learnerLevel}`);
  if (evalCache.has(key)) return evalCache.get(key)!;
  const result = await evaluateStep(step, transcript, ctx);
  evalCache.set(key, result);
  return result;
}
```

### 7.3 — Prefetch While User Reads Feedback

```typescript
// After Step N result is shown, quietly build Step N+1's context in background
useEffect(() => {
  if (currentStepResult) {
    const nextCtx = buildSessionContext(lesson, updatedProgress, nextStep);
    // Warm up the context object — no API call, just prep
    setNextStepContext(nextCtx);
  }
}, [currentStepResult]);
```

### 7.4 — Stream Free Conversation Replies

```typescript
const url = `...${PRO_MODEL}:streamGenerateContent?key=${GEMINI_API_KEY}`;
const res = await fetch(url, { method: 'POST', body: JSON.stringify(body) });
const reader = res.body!.getReader();
const decoder = new TextDecoder();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  appendToConversationUI(decoder.decode(value)); // Word-by-word — feels alive
}
```

---

## Phase 8: Gamification

### 8.1 — XP Per Step Type

```
listen_and_repeat   → max 8 XP
read_and_speak      → max 10 XP
prompt_response     → max 15 XP
fill_the_gap        → max 12 XP
free_conversation   → max 50 XP

Bonuses:
+3 XP  Perfect score (>= 0.95)
+2 XP  First attempt pass
+1 XP  Zero hints used
```

### 8.2 — Streak

```typescript
function checkStreak(lastActivityDate: Date): StreakStatus {
  const hours = differenceInHours(new Date(), lastActivityDate);
  if (hours < 24) return "active";
  if (hours < 48) return "at_risk";
  return "broken";
}
```

### 8.3 — Badges

| Badge | Trigger |
|---|---|
| 🎙️ First Word | Complete first speaking step |
| 🔥 Hot Streak | 7-day speaking streak |
| 💬 Conversationalist | Complete 5 free conversations |
| ⚡ Lightning Round | Perfect score, first attempt, 3 steps in a row |
| 🎯 No Hints | Full lesson with zero hints |
| 🌍 Polyglot Path | Lessons in 2+ languages |

---

## Phase 9: Build Order

### Week 1 — Foundation
- [ ] TypeScript schemas (Lesson, Step, Progress, Result)
- [ ] `GeminiClient` with `responseMimeType: "application/json"`
- [ ] `serializeContext()` — the most important function in the codebase
- [ ] `SpeechService` + normalization
- [ ] `EvaluationEngine` for Type 1 (`listen_and_repeat`) only
- [ ] One step works end-to-end before touching anything else

### Week 2 — All Step Types
- [ ] Type 2 (`read_and_speak`)
- [ ] Type 3 (`prompt_response`) — test open-ended answers carefully
- [ ] Type 4 (`fill_the_gap`)
- [ ] `FeedbackCard` with all visual states
- [ ] `LessonHeader` with progress bar

### Week 3 — Progression & Polish
- [ ] Wire `updateContextAfterStep()` — context accumulates correctly
- [ ] Hint system
- [ ] `LessonComplete` with Gemini summary
- [ ] XP/streak system
- [ ] `WaveformVisualizer` + `LiveTranscript`

### Week 4 — Advanced
- [ ] Type 5 (`free_conversation`) with multi-turn history
- [ ] Evaluation caching
- [ ] Streaming for conversation step
- [ ] Performance audit — measure total feedback loop per step type
- [ ] Badge system

---

## Phase 10: Error Handling

```typescript
const EDGE_CASES = {
  emptyTranscript: {
    detect: "transcript.length < 2",
    action: "SILENT_RETRY — do not count as attempt"
  },
  lowSTTConfidence: {
    detect: "confidence < 0.35",
    action: "Ask to speak more clearly — still don't count as attempt"
  },
  geminiAPIError: {
    detect: "fetch throws or returns non-200",
    action: "Fall back to Levenshtein score, show cached template feedback, allow continue"
  },
  geminiJSONMalformed: {
    detect: "JSON.parse throws despite responseMimeType",
    action: "Retry once with same prompt — if fails again, use Levenshtein fallback"
  },
  micPermissionDenied: {
    action: "Show mic enable instructions + always offer text input"
  },
  wrongLanguage: {
    detect: "Gemini flags this in JSON response",
    action: "Gentle 'Try saying it in Spanish!' — not an error, a redirect"
  }
};
```

---

## Phase 11: Performance Targets

| Operation | Target | How |
|---|---|---|
| Mic → Transcript | < 1.5s | Web Speech API is local |
| Transcript → Gemini Flash eval | < 2s | Flash is fast + JSON mode |
| Total feedback loop | **< 4 seconds** | Duolingo benchmark |
| Free conversation turn | < 3s | Streaming hides latency |

---

## Summary: The Gemini-Specific Golden Rules

1. **Context-First, always** — `serializeContext()` goes at the top of every single prompt. Gemini performs proportionally to how much it knows upfront.

2. **`responseMimeType: "application/json"`** — Gemini's killer feature for this use case. Never parse freeform JSON from an AI if you can force structured output.

3. **Flash for evaluation, Pro for conversation** — don't pay Pro rates for simple pass/fail scoring.

4. **Mistakes accumulate in context** — by Step 6, Gemini knows what the learner struggled with in Steps 1–5 and adjusts automatically. Free adaptive learning with zero ML infrastructure.

5. **Gemini evaluates MEANING, not perfection** — the prompts above are designed so partial credit is the default, not the exception.

6. **The mic button is the whole product** — more design time should go into its states than any other component.

7. **Never leave the user in silence** — every processing state has a label, animation, and color. Confusion kills motivation faster than a wrong answer.

8. **Always ship the text fallback** — mic issues, accessibility, and user preference all require it.

---

*Gemini works best when you treat it as a well-briefed expert, not an omniscient oracle. Brief it thoroughly on every call and it will not let you down.*
