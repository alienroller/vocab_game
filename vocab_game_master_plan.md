# Vocab Game — Master Plan: Competitive Upgrade + Growth Funnel

> **Purpose:** This document is a complete, step-by-step implementation guide for adding
> competitive multiplayer features to the `vocab_game` Flutter app AND a full DotCom Secrets
> marketing funnel strategy layered on top. Every section is written so that any developer
> (or AI assistant) can execute it without guessing.
> No Firebase. The backend is **Supabase** (open-source, free tier).
>
> **Two systems. One document.** The technical system makes the product addictive.
> The funnel system turns users into a sustainable business.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
   - 1.1 Value Ladder — Monetization Architecture (DotCom Secrets)
   - 1.2 Word Content Architecture — The Four-Table System
2. [Phase 0 — Content Pipeline & Word System](#2-phase-0--content-pipeline--word-system)
   - 2.1 Database Schema — Collections, Units, Words, Word Mastery
   - 2.2 AI Content Generation Script
   - 2.3 ESL & Fiction Collections — Seed Data Plan
   - 2.4 Library Screen — Flutter Implementation
   - 2.5 Session Logic — Spaced Repetition Word Selection
   - 2.6 Duel Modes — Three Word Selection Strategies
3. [Tech Stack Decision](#3-tech-stack-decision)
4. [Supabase Project Setup](#4-supabase-project-setup)
5. [Database Schema — Competitive Tables](#5-database-schema--competitive-tables)
6. [Flutter Dependencies](#6-flutter-dependencies)
7. [Supabase Initialization in Flutter](#7-supabase-initialization-in-flutter)
8. [Phase 1 — Foundation (Week 1)](#8-phase-1--foundation-week-1)
   - 8.1 User Profile Model (Hive)
   - 8.2 XP Engine
   - 8.3 Streak System
   - 8.4 Level System
   - 8.5 Syncing to Supabase
9. [Phase 2 — The Arena (Weeks 2–3)](#9-phase-2--the-arena-weeks-23)
   - 9.1 Leaderboard Screen
   - 9.2 Class Room System
   - 9.3 Weekly Tournament Reset
   - 9.4 Teacher Dashboard — Unit Assignment
10. [Phase 3 — Obsession (Week 4+)](#10-phase-3--obsession-week-4)
    - 10.1 1v1 Live Duel Engine
    - 10.2 Revenge Button
    - 10.3 Wall of Fame
    - 10.4 Push Notifications
    - 10.5 Duel History
11. [The 6 Addiction Hooks — Implementation](#11-the-6-addiction-hooks--implementation)
12. [First Impression Onboarding Flow](#12-first-impression-onboarding-flow)
    - 12.1 Dream Customer Definition (DotCom Secrets)
13. [DotCom Secrets Funnel System](#13-dotcom-secrets-funnel-system)
    - 13.1 The Attractive Character
    - 13.2 Funnel Map — Hook → Story → Offer
    - 13.3 Email Follow-Up Sequence
    - 13.4 Traffic Strategy — Own, Control, Earn
14. [Riverpod Providers Reference](#14-riverpod-providers-reference)
15. [File Structure](#15-file-structure)
16. [Supabase Row Level Security (RLS)](#16-supabase-row-level-security-rls)
17. [Error Handling & Offline Strategy](#17-error-handling--offline-strategy)
18. [Testing Checklist](#18-testing-checklist)

---

## 1. Project Overview

**Existing stack:**
- Flutter (Dart) — cross-platform (iOS, Android, Web, Desktop)
- `flutter_riverpod: ^2.6.1` — state management
- `hive: ^2.2.3` + `hive_flutter: ^1.1.0` — local storage
- `uuid: ^4.5.1` — unique IDs
- `google_fonts: ^6.2.1` — typography

**What we are adding:**
- Supabase as the cloud backend (leaderboard, auth, real-time duels)
- XP and leveling system
- Daily streak tracking
- Class-based leaderboard with weekly reset
- 1v1 real-time duels
- Push notifications for rivalry events

**What we are NOT changing:**
- The existing word/quiz game logic
- The Hive local storage setup
- The Riverpod provider architecture
- The UI language (English ↔ Uzbek vocabulary)

The principle is **offline-first**: all gameplay works without internet. Scores sync
to Supabase when a connection is available. The competitive features degrade gracefully
when offline (show cached data, queue sync).

---

### 1.1 Value Ladder — Monetization Architecture (DotCom Secrets)

> **DotCom Secrets principle:** Never sell just one thing. Build a ladder of offers at
> increasing value and price. Guide every user upward, one rung at a time.

The vocab game's Value Ladder maps directly onto the product features being built in
this guide. Each rung exists. You are already building it — this framework just makes
the business model explicit.

```
┌────────────────────────────────────────────────────────────┐
│  RUNG 4 — SCHOOL LICENSE                   $200–$500/yr   │
│  Unlimited classes, admin dashboard,                       │
│  usage reports, priority support                           │
├────────────────────────────────────────────────────────────┤
│  RUNG 3 — TEACHER PRO SUBSCRIPTION         $9–$15/month   │
│  Full teacher dashboard, 5+ classes,                       │
│  custom word sets, export progress CSV                     │
├────────────────────────────────────────────────────────────┤
│  RUNG 2 — STUDENT PREMIUM                  $3–$5/month    │
│  No ads (future), bonus word packs,                        │
│  streak shields (miss a day, keep streak)                  │
├────────────────────────────────────────────────────────────┤
│  RUNG 1 — FREE (the hook)                  $0             │
│  Full game, XP, streaks, class leaderboard,                │
│  duels — everything built in this guide                    │
└────────────────────────────────────────────────────────────┘
```

**Implementation priority:** Build Rung 1 to perfection first (this entire guide).
Introduce Rung 2 after you have 100+ active weekly users. Add Rung 3 when 3+ teachers
are actively using classes. Rung 4 comes after a school approaches you directly.

**The ladder in action:**
- A student plays for free → gets addicted via hooks in Section 10
- A student whose streak shield runs out → upgrades to Premium to protect it
- A teacher sees students competing → creates an account → hits the 1-class free limit → upgrades to Pro
- A school principal sees the dashboard → buys a school license

**Do not build payment infrastructure now.** The free product must first create
undeniable value. Add RevenueCat (Flutter-native) when you are ready for Rung 2.

---

### 1.2 Word Content Architecture — The Four-Table System

> This is the content backbone of the entire game. Every competitive feature —
> XP, duels, leaderboards, streaks — is meaningless without high-quality word content
> for students to actually learn. This section defines the architecture before any
> code is written.

**The two concerns that must never be mixed:**

1. **Content pipeline** — how words get into the database (runs on your laptop, never in the app)
2. **Content delivery** — how students browse, select, and play with those words (the Flutter app)

**The four tables:**

```
collections  →  units  →  words  →  word_mastery
```

- `collections` — A book or ESL course. E.g. "Harry Potter", "Headway Intermediate Unit 1–6"
- `units` — A chapter or theme within a collection. 10–12 words each.
- `words` — The actual word: Uzbek translation, example sentence, difficulty (A1–B2), word type
- `word_mastery` — Per-user progress on each word. Tracks seen count, correct count, last seen date.
  This is the spaced repetition layer. One row per (user_id, word_id) pair.

**The mastery rule:** A word is marked mastered when answered correctly on **3 separate calendar days**.
This is lightweight spaced repetition — no complex SRS algorithm needed. It naturally
forces students to return to the same unit across multiple sessions to complete it.

**The navigation rule:** Students never see a list of words before playing.
They select a unit and hit Play. The system selects the 10 best words for them
based on their mastery state. This keeps the UX clean and the game feeling smart.

**Content source priority:**
1. Uzbek secondary school ESL textbooks (highest relevance — curriculum-aligned)
2. Cambridge / Oxford / Headway ESL series (universal ESL standard)
3. Popular fiction in English commonly read by Uzbek students (Harry Potter, Animal Farm, The Alchemist)

---

## 2. Phase 0 — Content Pipeline & Word System

> **Run Phase 0 before Phase 1.** The XP engine, streak system, and duels all depend
> on words existing in the database. Phase 0 gives the game its content foundation.
> It has two parts: the backend pipeline (run once, from your laptop) and the
> Flutter Library screen (the student-facing content browser).

---

### 2.1 Database Schema — Collections, Units, Words, Word Mastery

Run all SQL in **Supabase → SQL Editor → New Query**, in order.

#### Collections table

```sql
CREATE TABLE collections (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,                        -- "Harry Potter and the Philosopher's Stone"
  short_title text NOT NULL,                  -- "Harry Potter 1" (for UI cards)
  description text,                           -- "Vocabulary from J.K. Rowling's first book"
  category text NOT NULL                      -- 'fiction' | 'esl' | 'academic'
    CHECK (category IN ('fiction', 'esl', 'academic')),
  difficulty text NOT NULL                    -- 'A1' | 'A2' | 'B1' | 'B2'
    CHECK (difficulty IN ('A1', 'A2', 'B1', 'B2')),
  cover_emoji text DEFAULT '📚',             -- Emoji used as cover art in the UI
  cover_color text DEFAULT '#4F46E5',        -- Hex color for the card background
  total_units integer DEFAULT 0,             -- Denormalized count, updated by trigger
  is_published boolean DEFAULT false,        -- Draft until you approve content
  created_at timestamptz DEFAULT now() NOT NULL
);
```

#### Units table

```sql
CREATE TABLE units (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  collection_id uuid REFERENCES collections(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,             -- "Chapter 1 — The Boy Who Lived"
  unit_number integer NOT NULL,    -- 1, 2, 3... for ordering within a collection
  word_count integer DEFAULT 0,    -- Denormalized, updated by trigger
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(collection_id, unit_number)
);
```

#### Words table

```sql
CREATE TABLE words (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  unit_id uuid REFERENCES units(id) ON DELETE CASCADE NOT NULL,
  collection_id uuid REFERENCES collections(id) ON DELETE CASCADE NOT NULL,
  word text NOT NULL,                    -- The English word: "peculiar"
  translation text NOT NULL,             -- Uzbek translation: "g'alati, notabiiy"
  example_sentence text NOT NULL,        -- "Mr Dursley had a very peculiar Tuesday."
  word_type text NOT NULL                -- 'noun' | 'verb' | 'adjective' | 'adverb' | 'phrase'
    CHECK (word_type IN ('noun', 'verb', 'adjective', 'adverb', 'phrase')),
  difficulty text NOT NULL
    CHECK (difficulty IN ('A1', 'A2', 'B1', 'B2')),
  word_number integer NOT NULL,          -- Order within the unit (1–12)
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(unit_id, word_number)
);
```

#### Word Mastery table

```sql
CREATE TABLE word_mastery (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  word_id uuid REFERENCES words(id) ON DELETE CASCADE NOT NULL,
  seen_count integer DEFAULT 0 NOT NULL,        -- Total times shown to this user
  correct_count integer DEFAULT 0 NOT NULL,     -- Times answered correctly
  correct_days integer DEFAULT 0 NOT NULL,      -- Distinct calendar days answered correctly
                                                -- Mastered when correct_days >= 3
  last_seen_date date,                          -- For spaced repetition prioritization
  last_correct_date date,                       -- Last day answered correctly
  is_mastered boolean DEFAULT false NOT NULL,   -- True when correct_days >= 3
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(profile_id, word_id)                   -- One mastery record per user per word
);
```

#### Indexes

```sql
-- Fast lookup: all words in a unit
CREATE INDEX idx_words_unit_id ON words(unit_id);

-- Fast lookup: all words in a collection (for mixed duels)
CREATE INDEX idx_words_collection_id ON words(collection_id);

-- Fast lookup: user's mastery state for a unit's words
CREATE INDEX idx_word_mastery_profile ON word_mastery(profile_id);
CREATE INDEX idx_word_mastery_word ON word_mastery(word_id);

-- Fast lookup: unmastered words for a user (session selection query)
CREATE INDEX idx_word_mastery_mastered ON word_mastery(profile_id, is_mastered);

-- Units ordered within a collection
CREATE INDEX idx_units_collection ON units(collection_id, unit_number);
```

#### Trigger: auto-update word_count and total_units

```sql
-- Function to keep unit word_count in sync
CREATE OR REPLACE FUNCTION update_unit_word_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE units SET word_count = word_count + 1 WHERE id = NEW.unit_id;
    UPDATE collections SET total_units = (
      SELECT COUNT(*) FROM units WHERE collection_id = NEW.collection_id
    ) WHERE id = NEW.collection_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE units SET word_count = word_count - 1 WHERE id = OLD.unit_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER words_count_trigger
AFTER INSERT OR DELETE ON words
FOR EACH ROW EXECUTE FUNCTION update_unit_word_count();
```

#### RLS for content tables

```sql
-- Collections and units and words: read-only for all users
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_mastery ENABLE ROW LEVEL SECURITY;

CREATE POLICY "collections_read" ON collections FOR SELECT USING (is_published = true);
CREATE POLICY "units_read" ON units FOR SELECT USING (true);
CREATE POLICY "words_read" ON words FOR SELECT USING (true);

-- Word mastery: users can only read and write their own records
CREATE POLICY "mastery_read" ON word_mastery FOR SELECT USING (true);
CREATE POLICY "mastery_insert" ON word_mastery FOR INSERT WITH CHECK (true);
CREATE POLICY "mastery_update" ON word_mastery FOR UPDATE USING (true);
```

---

### 2.2 AI Content Generation Script

> This script runs on your laptop, not inside the Flutter app. You run it once per
> collection. It calls the Claude API, generates structured JSON word data, lets you
> review it, then inserts it into Supabase. The student never sees this process.

**Requirements:** Node.js 18+, `@anthropic-ai/sdk`, `@supabase/supabase-js`

Create a folder `tools/content_pipeline/` in your project root (outside `lib/`).

#### File: `tools/content_pipeline/package.json`

```json
{
  "name": "vocab-content-pipeline",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@anthropic-ai/sdk": "^0.20.0",
    "@supabase/supabase-js": "^2.39.0"
  }
}
```

Run `npm install` inside this folder.

#### File: `tools/content_pipeline/generate.mjs`

```javascript
import Anthropic from '@anthropic-ai/sdk';
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// --- CONFIG — set these before running ---
const COLLECTION_TITLE = 'Animal Farm';
const COLLECTION_SHORT_TITLE = 'Animal Farm';
const COLLECTION_DESCRIPTION = 'Vocabulary from George Orwell\'s Animal Farm';
const COLLECTION_CATEGORY = 'fiction'; // 'fiction' | 'esl' | 'academic'
const COLLECTION_DIFFICULTY = 'B1';
const COLLECTION_EMOJI = '🐷';
const COLLECTION_COLOR = '#16A34A';
const NUM_UNITS = 6;          // How many units to generate
const WORDS_PER_UNIT = 10;    // Words per unit (10 is the sweet spot)

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY; // Use service key for admin insert
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

// -----------------------------------------

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const GENERATION_PROMPT = `
You are an expert EFL/ESL vocabulary curriculum designer creating content for
Uzbek secondary school students learning English (ages 13–18, CEFR level ${COLLECTION_DIFFICULTY}).

Generate ${NUM_UNITS} vocabulary units from the book/course: "${COLLECTION_TITLE}"

Requirements:
- Each unit must have exactly ${WORDS_PER_UNIT} words
- Units should be themed by chapter, topic, or narrative section
- Words must be educationally valuable — not too simple, not too obscure
- Each word must have:
  - "word": the English word (lowercase)
  - "translation": Uzbek translation (in Uzbek script)
  - "example_sentence": a short, clear example sentence (NOT copied verbatim from the book — write your own)
  - "word_type": one of "noun", "verb", "adjective", "adverb", "phrase"
  - "difficulty": one of "A1", "A2", "B1", "B2"
- Units must be ordered from easier to harder vocabulary
- Unit titles should be descriptive (e.g. "Chapter 1 — The Revolution Begins")

Respond with ONLY a valid JSON array. No preamble, no markdown, no explanation.
Format:
[
  {
    "unit_number": 1,
    "unit_title": "Chapter 1 — Life on Manor Farm",
    "words": [
      {
        "word": "tyrant",
        "translation": "zolim, mustabid",
        "example_sentence": "The farmer was a tyrant who never listened to the animals.",
        "word_type": "noun",
        "difficulty": "B1",
        "word_number": 1
      }
    ]
  }
]
`;

async function generateContent() {
  console.log(`\n🤖 Generating content for: ${COLLECTION_TITLE}`);
  console.log(`   ${NUM_UNITS} units × ${WORDS_PER_UNIT} words = ${NUM_UNITS * WORDS_PER_UNIT} total words\n`);

  const response = await anthropic.messages.create({
    model: 'claude-opus-4-20250514',
    max_tokens: 8000,
    messages: [{ role: 'user', content: GENERATION_PROMPT }]
  });

  const rawText = response.content[0].text.trim();

  // Strip any accidental markdown fences
  const jsonText = rawText.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();

  let units;
  try {
    units = JSON.parse(jsonText);
  } catch (e) {
    console.error('❌ Failed to parse JSON. Raw response saved to output_raw.txt');
    fs.writeFileSync('output_raw.txt', rawText);
    process.exit(1);
  }

  // Save for review before inserting
  fs.writeFileSync('output_review.json', JSON.stringify(units, null, 2));
  console.log(`✅ Generated ${units.length} units`);
  console.log(`📄 Saved to output_review.json — REVIEW BEFORE INSERTING\n`);

  // Print summary for quick review
  units.forEach(u => {
    console.log(`  Unit ${u.unit_number}: ${u.unit_title} (${u.words.length} words)`);
    u.words.slice(0, 3).forEach(w => console.log(`    • ${w.word} → ${w.translation}`));
    console.log(`    ...`);
  });

  return units;
}

async function insertToSupabase(units) {
  console.log(`\n📤 Inserting into Supabase...`);

  // 1. Insert collection
  const { data: collection, error: collErr } = await supabase
    .from('collections')
    .insert({
      title: COLLECTION_TITLE,
      short_title: COLLECTION_SHORT_TITLE,
      description: COLLECTION_DESCRIPTION,
      category: COLLECTION_CATEGORY,
      difficulty: COLLECTION_DIFFICULTY,
      cover_emoji: COLLECTION_EMOJI,
      cover_color: COLLECTION_COLOR,
      is_published: false  // Set to true manually after reviewing in Supabase dashboard
    })
    .select()
    .single();

  if (collErr) { console.error('Collection insert failed:', collErr); process.exit(1); }
  console.log(`✅ Collection created: ${collection.id}`);

  // 2. Insert units and words
  for (const unitData of units) {
    const { data: unit, error: unitErr } = await supabase
      .from('units')
      .insert({
        collection_id: collection.id,
        title: unitData.unit_title,
        unit_number: unitData.unit_number,
      })
      .select()
      .single();

    if (unitErr) { console.error('Unit insert failed:', unitErr); process.exit(1); }

    const wordsToInsert = unitData.words.map(w => ({
      unit_id: unit.id,
      collection_id: collection.id,
      word: w.word.toLowerCase().trim(),
      translation: w.translation,
      example_sentence: w.example_sentence,
      word_type: w.word_type,
      difficulty: w.difficulty,
      word_number: w.word_number,
    }));

    const { error: wordsErr } = await supabase.from('words').insert(wordsToInsert);
    if (wordsErr) { console.error('Words insert failed:', wordsErr); process.exit(1); }

    console.log(`  ✅ Unit ${unitData.unit_number}: ${unitData.unit_title} (${wordsToInsert.length} words)`);
  }

  console.log(`\n🎉 Done! Collection is saved as DRAFT (is_published = false).`);
  console.log(`   Go to Supabase → Table Editor → collections → set is_published = true when ready.`);
}

// --- Main ---
const args = process.argv.slice(2);

if (args[0] === '--insert') {
  // Run: node generate.mjs --insert
  // Only inserts if output_review.json already exists (i.e. you reviewed it first)
  if (!fs.existsSync('output_review.json')) {
    console.error('❌ Run without --insert first to generate and review content.');
    process.exit(1);
  }
  const units = JSON.parse(fs.readFileSync('output_review.json', 'utf8'));
  await insertToSupabase(units);
} else {
  // Run: node generate.mjs
  // Generates content and saves to output_review.json for review
  await generateContent();
  console.log('\n✋ Review output_review.json, then run: node generate.mjs --insert');
}
```

**How to run it:**

```bash
cd tools/content_pipeline

# Step 1 — Generate and review (no data written yet)
ANTHROPIC_API_KEY=sk-ant-... \
SUPABASE_URL=https://xxx.supabase.co \
SUPABASE_SERVICE_KEY=eyJ... \
node generate.mjs

# Step 2 — Review output_review.json in your editor
# Edit any translations, fix any sentences you don't like

# Step 3 — Insert into Supabase
ANTHROPIC_API_KEY=sk-ant-... \
SUPABASE_URL=https://xxx.supabase.co \
SUPABASE_SERVICE_KEY=eyJ... \
node generate.mjs --insert

# Step 4 — Go to Supabase dashboard → collections → set is_published = true
```

**Important:** Use the **service role key** (not the anon key) for this script.
The service key bypasses RLS and is safe to use from your local machine.
Never put the service key in the Flutter app.

---

### 2.3 ESL & Fiction Collections — Seed Data Plan

Run the generator for these collections in priority order. Each collection takes
approximately 5 minutes of your time (1 minute to run, 4 minutes to review).

**Priority 1 — Uzbek curriculum-aligned (highest teacher adoption value):**

| Collection | Category | Difficulty | Units | Notes |
|---|---|---|---|---|
| Fly High (UZ School Book 5) | esl | A1 | 8 | Standard Uzbek Year 5 English |
| Fly High (UZ School Book 6) | esl | A1 | 8 | Standard Uzbek Year 6 English |
| Fly High (UZ School Book 7) | esl | A2 | 10 | Standard Uzbek Year 7 English |
| Fly High (UZ School Book 8) | esl | A2 | 10 | Standard Uzbek Year 8 English |
| Fly High (UZ School Book 9) | esl | B1 | 10 | Standard Uzbek Year 9 English |

**Priority 2 — Universal ESL (broad appeal):**

| Collection | Category | Difficulty | Units | Notes |
|---|---|---|---|---|
| Headway Beginner | esl | A1 | 12 | Oxford — most used ESL series globally |
| Headway Elementary | esl | A2 | 12 | Oxford |
| Cambridge A2 Key Vocabulary | esl | A2 | 10 | Cambridge KET prep |
| Cambridge B1 Preliminary | esl | B1 | 12 | Cambridge PET prep |

**Priority 3 — Fiction (student motivation & virality):**

| Collection | Category | Difficulty | Units | Notes |
|---|---|---|---|---|
| Animal Farm | fiction | B1 | 6 | Commonly taught in Uzbek schools |
| The Alchemist | fiction | B1 | 8 | Very popular among Uzbek youth |
| Harry Potter 1 | fiction | B1 | 10 | Highest virality potential |
| Charlotte's Web | fiction | A2 | 6 | Good for younger students |

**Launch target:** Complete Priority 1 before launch. This alone gives you
~80 units and ~800 words — enough content for months of daily play.

---

### 2.4 Library Screen — Flutter Implementation

The Library screen is the student's entry point to all word content.
It has three layers: Collection grid → Unit list → Word preview + Play button.

Create `lib/screens/library/library_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'unit_list_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'esl' | 'fiction' | 'academic'

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final data = await supabase
        .from('collections')
        .select('id, short_title, description, category, difficulty, cover_emoji, cover_color, total_units')
        .eq('is_published', true)
        .order('category')
        .order('difficulty');

    if (mounted) {
      setState(() {
        _collections = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _collections;
    return _collections.where((c) => c['category'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Word Library')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildCollectionGrid()),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'All'),
      ('esl', 'ESL'),
      ('fiction', 'Fiction'),
      ('academic', 'Academic'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCollectionGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final c = _filtered[index];
        return _CollectionCard(
          collection: c,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UnitListScreen(collection: c),
            ),
          ),
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback onTap;

  const _CollectionCard({required this.collection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(
        collection['cover_color'].replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection['cover_emoji'] ?? '📚',
                style: const TextStyle(fontSize: 36)),
            const Spacer(),
            Text(
              collection['short_title'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _DifficultyBadge(collection['difficulty']),
                const SizedBox(width: 6),
                Text(
                  '${collection['total_units']} units',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String level;
  const _DifficultyBadge(this.level);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(level,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
```

Create `lib/screens/library/unit_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../main.dart';
import '../game_screen.dart'; // your existing game screen

class UnitListScreen extends StatefulWidget {
  final Map<String, dynamic> collection;
  const UnitListScreen({super.key, required this.collection});

  @override
  State<UnitListScreen> createState() => _UnitListScreenState();
}

class _UnitListScreenState extends State<UnitListScreen> {
  List<Map<String, dynamic>> _units = [];
  Map<String, int> _unitMasteredCounts = {}; // unitId → mastered word count
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;

    // Fetch all units for this collection
    final units = await supabase
        .from('units')
        .select('id, title, unit_number, word_count')
        .eq('collection_id', widget.collection['id'])
        .order('unit_number');

    // Fetch mastery counts for each unit (how many words mastered per unit)
    if (userId != null && units.isNotEmpty) {
      final unitIds = units.map((u) => u['id'] as String).toList();

      // Count mastered words per unit for this user
      for (final unitId in unitIds) {
        final mastered = await supabase
            .from('word_mastery')
            .select('id')
            .eq('profile_id', userId)
            .eq('is_mastered', true)
            .in_('word_id',
                await _getWordIdsForUnit(unitId));
        _unitMasteredCounts[unitId] = (mastered as List).length;
      }
    }

    if (mounted) {
      setState(() {
        _units = List<Map<String, dynamic>>.from(units);
        _loading = false;
      });
    }
  }

  Future<List<String>> _getWordIdsForUnit(String unitId) async {
    final words = await supabase
        .from('words')
        .select('id')
        .eq('unit_id', unitId);
    return (words as List).map((w) => w['id'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.collection['short_title'])),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final unit = _units[index];
                final mastered = _unitMasteredCounts[unit['id']] ?? 0;
                final total = unit['word_count'] as int? ?? 10;
                final progress = total > 0 ? mastered / total : 0.0;
                final isComplete = mastered >= total;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(unit['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? Colors.green : Colors.amber),
                        ),
                        const SizedBox(height: 4),
                        Text('$mastered / $total words mastered',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: isComplete
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _startSession(unit),
                            child: const Text('Play'),
                          ),
                  ),
                );
              },
            ),
    );
  }

  void _startSession(Map<String, dynamic> unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          unitId: unit['id'],
          unitTitle: unit['title'],
          collectionId: widget.collection['id'],
        ),
      ),
    );
  }
}
```

---

### 2.5 Session Logic — Spaced Repetition Word Selection

> This is the intelligence layer of the word system. When a student hits Play on a
> unit, the system does not just pick 10 random words. It picks the 10 words the
> student needs most, based on their mastery history.

Create `lib/services/word_session_service.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../main.dart';

class WordSessionService {

  /// Selects the best 10 words for a session from a unit.
  /// Priority order:
  ///   1. Words never seen before (highest priority — always show new words first)
  ///   2. Words seen but not yet mastered, ordered by: lowest correct_days first,
  ///      then oldest last_seen_date first (longest overdue)
  ///   3. Mastered words (only if fewer than 10 unmastered words remain in the unit)
  ///
  /// Returns a list of word maps ready to use in the game session.
  static Future<List<Map<String, dynamic>>> selectSessionWords({
    required String unitId,
    int count = 10,
  }) async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;
    if (userId == null) return [];

    // Fetch all words in this unit
    final allWords = await supabase
        .from('words')
        .select('id, word, translation, example_sentence, word_type, difficulty')
        .eq('unit_id', unitId)
        .order('word_number');

    if (allWords.isEmpty) return [];

    final wordIds = (allWords as List).map((w) => w['id'] as String).toList();

    // Fetch this user's mastery records for these words
    final masteryRecords = await supabase
        .from('word_mastery')
        .select('word_id, seen_count, correct_count, correct_days, last_seen_date, is_mastered')
        .eq('profile_id', userId)
        .in_('word_id', wordIds);

    // Build a lookup map: wordId → mastery record
    final masteryMap = <String, Map<String, dynamic>>{};
    for (final m in (masteryRecords as List)) {
      masteryMap[m['word_id'] as String] = Map<String, dynamic>.from(m);
    }

    // Categorize words
    final neverSeen = <Map<String, dynamic>>[];
    final inProgress = <Map<String, dynamic>>[];
    final mastered = <Map<String, dynamic>>[];

    for (final word in allWords) {
      final wordId = word['id'] as String;
      final mastery = masteryMap[wordId];

      if (mastery == null || (mastery['seen_count'] as int) == 0) {
        neverSeen.add(word);
      } else if (mastery['is_mastered'] == true) {
        mastered.add(word);
      } else {
        // Attach mastery data for sorting
        inProgress.add({...word, '_mastery': mastery});
      }
    }

    // Sort in-progress words: lowest correct_days first, then oldest last_seen first
    inProgress.sort((a, b) {
      final aMastery = a['_mastery'] as Map<String, dynamic>;
      final bMastery = b['_mastery'] as Map<String, dynamic>;
      final daysDiff = (aMastery['correct_days'] as int)
          .compareTo(bMastery['correct_days'] as int);
      if (daysDiff != 0) return daysDiff;
      // Same correct_days — prioritize the one seen longest ago
      final aDate = aMastery['last_seen_date'] as String? ?? '2000-01-01';
      final bDate = bMastery['last_seen_date'] as String? ?? '2000-01-01';
      return aDate.compareTo(bDate); // older date = lower string = comes first
    });

    // Build final selection: neverSeen first, then inProgress, then mastered (as filler)
    final selected = <Map<String, dynamic>>[];
    selected.addAll(neverSeen.take(count));
    if (selected.length < count) {
      selected.addAll(inProgress.take(count - selected.length));
    }
    if (selected.length < count) {
      selected.addAll(mastered.take(count - selected.length));
    }

    // Remove internal _mastery field before returning to the game
    return selected.take(count).map((w) {
      final clean = Map<String, dynamic>.from(w);
      clean.remove('_mastery');
      return clean;
    }).toList();
  }

  /// Call this after every question answer to update word mastery.
  /// Pass isCorrect = true/false based on whether the student answered correctly.
  static Future<void> recordAnswer({
    required String wordId,
    required bool isCorrect,
  }) async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10); // "YYYY-MM-DD"

    try {
      // Fetch existing mastery record (may not exist yet)
      final existing = await supabase
          .from('word_mastery')
          .select()
          .eq('profile_id', userId)
          .eq('word_id', wordId)
          .maybeSingle();

      if (existing == null) {
        // First time seeing this word — create record
        await supabase.from('word_mastery').insert({
          'profile_id': userId,
          'word_id': wordId,
          'seen_count': 1,
          'correct_count': isCorrect ? 1 : 0,
          'correct_days': isCorrect ? 1 : 0,
          'last_seen_date': today,
          'last_correct_date': isCorrect ? today : null,
          'is_mastered': false,
        });
      } else {
        // Update existing record
        final seenCount = (existing['seen_count'] as int) + 1;
        final correctCount = (existing['correct_count'] as int) + (isCorrect ? 1 : 0);

        // Only increment correct_days if today is a NEW day compared to last_correct_date
        int correctDays = existing['correct_days'] as int;
        String? lastCorrectDate = existing['last_correct_date'] as String?;
        if (isCorrect && lastCorrectDate != today) {
          correctDays += 1;
          lastCorrectDate = today;
        }

        final isMastered = correctDays >= 3; // Mastered after 3 correct days

        await supabase.from('word_mastery').update({
          'seen_count': seenCount,
          'correct_count': correctCount,
          'correct_days': correctDays,
          'last_seen_date': today,
          'last_correct_date': lastCorrectDate,
          'is_mastered': isMastered,
        }).eq('profile_id', userId).eq('word_id', wordId);
      }
    } catch (e) {
      // Silently fail — mastery tracking must never crash the game
      debugPrint('Mastery update failed: $e');
    }
  }

  /// Returns the mastery progress for a unit: {mastered: int, total: int}
  static Future<Map<String, int>> getUnitProgress({
    required String unitId,
  }) async {
    final profileBox = Hive.box('userProfile');
    final userId = profileBox.get('id') as String?;
    if (userId == null) return {'mastered': 0, 'total': 0};

    final total = await supabase
        .from('words')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('unit_id', unitId);

    final wordIds = await supabase
        .from('words')
        .select('id')
        .eq('unit_id', unitId);

    final mastered = await supabase
        .from('word_mastery')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('profile_id', userId)
        .eq('is_mastered', true)
        .in_('word_id', (wordIds as List).map((w) => w['id']).toList());

    return {
      'mastered': mastered.count ?? 0,
      'total': total.count ?? 0,
    };
  }
}
```

**How to integrate into your existing GameScreen:**

```dart
// At the start of a unit session — replace your existing word-fetching logic:
final words = await WordSessionService.selectSessionWords(unitId: unitId);

// After every question answer — add this call alongside your XP calculation:
await WordSessionService.recordAnswer(
  wordId: currentWord['id'],
  isCorrect: isCorrect,
);
```

---

### 2.6 Duel Modes — Three Word Selection Strategies

The existing duel system stores a `word_set` jsonb field in the `duels` table.
With the word content system in place, you now choose which words go into that
field based on the duel mode. The game screen itself does not change — it receives
a list of word IDs and plays them regardless of how they were selected.

Add this to `lib/services/duel_service.dart`:

```dart
enum DuelWordMode {
  sameUnit,     // Both players have the same teacher-assigned unit active
  sameCollection, // Random words from a shared collection both players have studied
  open,         // Any words from either player's study history (existing behavior)
}

class DuelWordSelector {

  /// Selects 10 word IDs for a duel. Called by the challenger when creating the duel.
  /// The same word list is used by both players — fair competition.
  static Future<List<String>> selectDuelWords({
    required String challengerProfileId,
    required String opponentProfileId,
    required DuelWordMode mode,
    String? unitId,         // Required for sameUnit mode
    String? collectionId,   // Required for sameCollection mode
  }) async {
    switch (mode) {
      case DuelWordMode.sameUnit:
        return _wordsFromUnit(unitId!);

      case DuelWordMode.sameCollection:
        return _wordsFromSharedCollection(
          collectionId: collectionId!,
          challengerProfileId: challengerProfileId,
          opponentProfileId: opponentProfileId,
        );

      case DuelWordMode.open:
        return _wordsFromStudyHistory(
          challengerProfileId: challengerProfileId,
          opponentProfileId: opponentProfileId,
        );
    }
  }

  // Mode 1: Random 10 words from a specific unit
  // Used for teacher-assigned class duels
  static Future<List<String>> _wordsFromUnit(String unitId) async {
    final words = await supabase
        .from('words')
        .select('id')
        .eq('unit_id', unitId);
    final ids = (words as List).map((w) => w['id'] as String).toList();
    ids.shuffle();
    return ids.take(10).toList();
  }

  // Mode 2: Words from a collection that both players have seen at least once
  // Rewards breadth of study — you need to have studied the collection to compete well
  static Future<List<String>> _wordsFromSharedCollection({
    required String collectionId,
    required String challengerProfileId,
    required String opponentProfileId,
  }) async {
    // Get word IDs from this collection
    final collectionWords = await supabase
        .from('words')
        .select('id')
        .eq('collection_id', collectionId);
    final collectionWordIds =
        (collectionWords as List).map((w) => w['id'] as String).toList();

    // Get words seen by challenger
    final challengerSeen = await supabase
        .from('word_mastery')
        .select('word_id')
        .eq('profile_id', challengerProfileId)
        .gt('seen_count', 0)
        .in_('word_id', collectionWordIds);

    // Get words seen by opponent
    final opponentSeen = await supabase
        .from('word_mastery')
        .select('word_id')
        .eq('profile_id', opponentProfileId)
        .gt('seen_count', 0)
        .in_('word_id', collectionWordIds);

    // Intersection: words both players have seen
    final challengerIds =
        (challengerSeen as List).map((w) => w['word_id'] as String).toSet();
    final opponentIds =
        (opponentSeen as List).map((w) => w['word_id'] as String).toSet();
    final shared = challengerIds.intersection(opponentIds).toList();

    // Fall back to full collection if intersection is too small
    final pool = shared.length >= 10 ? shared : collectionWordIds;
    pool.shuffle();
    return pool.take(10).toList();
  }

  // Mode 3: Words from either player's study history (open duel)
  // Widest pool — any word either player has encountered
  static Future<List<String>> _wordsFromStudyHistory({
    required String challengerProfileId,
    required String opponentProfileId,
  }) async {
    final allSeen = await supabase
        .from('word_mastery')
        .select('word_id')
        .or('profile_id.eq.$challengerProfileId,profile_id.eq.$opponentProfileId')
        .gt('seen_count', 0);

    final ids = (allSeen as List).map((w) => w['word_id'] as String).toSet().toList();
    if (ids.isEmpty) {
      // Fallback: pick 10 random words from any published unit
      final fallback = await supabase
          .from('words')
          .select('id')
          .limit(50);
      final fallbackIds = (fallback as List).map((w) => w['id'] as String).toList();
      fallbackIds.shuffle();
      return fallbackIds.take(10).toList();
    }
    ids.shuffle();
    return ids.take(10).toList();
  }
}
```

**How to wire this into the existing duel creation flow (in section 10.1):**

```dart
// When challenger taps "Challenge" — before inserting the duel row:

// Determine mode based on context:
// - If teacher has assigned a unit this week → sameUnit
// - If challenger selects a collection from the challenge dialog → sameCollection
// - Otherwise → open

final wordIds = await DuelWordSelector.selectDuelWords(
  challengerProfileId: profile.id,
  opponentProfileId: opponent['id'],
  mode: DuelWordMode.sameUnit,  // or sameCollection or open
  unitId: assignedUnitId,       // from teacher assignment if available
);

// Then insert the duel with these word IDs as the word_set:
await supabase.from('duels').insert({
  'challenger_id': profile.id,
  'opponent_id': opponent['id'],
  'challenger_username': profile.username,
  'opponent_username': opponent['username'],
  'word_set': wordIds,  // stored as jsonb array of UUIDs
  'status': 'pending',
});
```

**Update to Teacher Dashboard (Section 9.4) — Unit Assignment:**

Teachers need one additional field in the `classes` table to assign a unit:

```sql
ALTER TABLE classes
  ADD COLUMN assigned_unit_id uuid REFERENCES units(id),
  ADD COLUMN assigned_unit_title text,
  ADD COLUMN assignment_expires_at date;
-- assignment_expires_at: the Friday of the current week.
-- After this date, the assignment banner disappears from student home screens.
```

The teacher dashboard (Section 9.4) gets a new "Assign Unit" button that:
1. Shows the Library collection grid (same as the student Library screen)
2. Teacher selects a collection → unit
3. Updates the class row with `assigned_unit_id`, `assigned_unit_title`, and sets `assignment_expires_at` to the coming Sunday
4. All students in the class see a banner on their home screen: "This week: [unit title] — Play Now"

---

## 3. Tech Stack Decision

### Why Supabase instead of Firebase

| Concern | Firebase | Supabase |
|---|---|---|
| Open-source | No | Yes (Apache 2.0) |
| Free tier | 1 GB Firestore | 500 MB PostgreSQL + 50K MAU |
| Real-time | Firestore streams | Postgres Realtime channels |
| Flutter SDK | `cloud_firestore` (heavy) | `supabase_flutter` (one package) |
| Auth without email | Requires workaround | Anonymous + username natively |
| SQL queries | No — NoSQL only | Full PostgreSQL |
| Weekly cron reset | Cloud Functions (paid) | `pg_cron` extension (free) |
| Vendor lock-in | High | Low — it's Postgres |

**Decision: Supabase.** One package. Free tier is enough for a classroom of hundreds.

---

## 4. Supabase Project Setup

### Step 1 — Create the project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. Click **New Project**.
3. Name it `vocab-game`. Choose the region closest to Uzbekistan: **Frankfurt (eu-central-1)**.
4. Set a strong database password. Save it somewhere — you will not use it in Flutter
   code directly, but you need it for direct DB access.
5. Wait ~2 minutes for the project to spin up.

### Step 2 — Get your credentials

In the Supabase dashboard:

1. Go to **Settings → API**.
2. Copy:
   - **Project URL** → looks like `https://xxxxxxxxxxx.supabase.co`
   - **anon public key** → a long JWT string

You will paste these into your Flutter app in section 6.

### Step 3 — Enable Realtime

1. Go to **Database → Replication**.
2. Find the `leaderboard` and `duels` tables (you will create them next).
3. Toggle **Realtime** ON for both tables.

This is required for the live leaderboard and 1v1 duels to work.

### Step 4 — Enable pg_cron for weekly reset

1. Go to **Database → Extensions**.
2. Search for `pg_cron` and enable it.
3. You will add the cron job in section 8.3.

---

## 5. Database Schema — Competitive Tables

Run all of the following SQL in **Supabase → SQL Editor → New Query**. Run them in
order. Do not skip any block.

### 4.1 Users / Profiles table

```sql
CREATE TABLE profiles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  username text UNIQUE NOT NULL,
  xp integer DEFAULT 0 NOT NULL,
  level integer DEFAULT 1 NOT NULL,
  streak_days integer DEFAULT 0 NOT NULL,
  last_played_date date,
  class_code text,
  week_xp integer DEFAULT 0 NOT NULL,
  total_words_answered integer DEFAULT 0 NOT NULL,
  total_correct integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
```

**Column explanations:**
- `id` — UUID, primary key, auto-generated. Used as the anonymous user identity.
- `username` — The name the student picks on first launch. Must be unique across the
  whole app (not just their class).
- `xp` — Total XP ever earned. Never resets. Used for the global leaderboard and level.
- `level` — Computed from `xp` but stored for fast queries. Sync it when xp changes.
- `streak_days` — How many consecutive days they have played. Reset to 0 if they miss
  a day. Increment on first game of each new day.
- `last_played_date` — The date of the last session. Used to check if streak is
  maintained or broken.
- `class_code` — The 6-character code their teacher gave them (e.g. `ENG7B`).
  Null for users not in a class.
- `week_xp` — XP earned in the current calendar week only. Resets every Monday at
  midnight via `pg_cron`. Used for the weekly tournament tab.
- `total_words_answered` / `total_correct` — For accuracy stats shown on profile page.

### 4.2 Classes table

```sql
CREATE TABLE classes (
  code text PRIMARY KEY,
  teacher_username text NOT NULL,
  class_name text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);
```

**Column explanations:**
- `code` — The 6-character code students enter to join (e.g. `ENG7B`). Teacher creates
  this. You can let teachers choose their own code or auto-generate it.
- `teacher_username` — The teacher's profile username. Used to show "Created by" on
  the join screen.
- `class_name` — A human-readable name like "Class 7B — English".

### 4.3 Duels table

```sql
CREATE TABLE duels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  challenger_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  opponent_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  challenger_username text NOT NULL,
  opponent_username text NOT NULL,
  challenger_score integer DEFAULT 0,
  opponent_score integer DEFAULT 0,
  challenger_xp_gain integer DEFAULT 0,
  opponent_xp_gain integer DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending','active','finished','declined')),
  word_set jsonb NOT NULL,
  winner_id uuid REFERENCES profiles(id),
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL
);
```

**Column explanations:**
- `status` — Lifecycle: `pending` (waiting for opponent to accept) → `active` (both
  playing) → `finished` (done) or `declined` (opponent rejected).
- `word_set` — A JSON array of the 10 word IDs used in this duel. Both players get
  the exact same words in the same order. Generate this when the challenger clicks
  "Challenge" and insert it here.
- `winner_id` — Set when the duel finishes (status → 'finished').
- `challenger_xp_gain` / `opponent_xp_gain` — Stored so the history screen can show
  "+50 XP" or "+10 XP" for each match.

### 4.4 Hall of Fame table

```sql
CREATE TABLE hall_of_fame (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  username text NOT NULL,
  rank integer NOT NULL CHECK (rank IN (1, 2, 3)),
  week_xp integer NOT NULL,
  period_label text NOT NULL,
  awarded_at timestamptz DEFAULT now() NOT NULL
);
```

**Column explanations:**
- `rank` — 1 (gold), 2 (silver), 3 (bronze).
- `period_label` — A human-readable string like "March 2026 — Week 2". Generate this
  in the cron job or in your Flutter app when submitting.
- This table NEVER gets cleared. It is permanent history.

### 4.5 Enable Realtime on the tables

```sql
ALTER TABLE profiles REPLICA IDENTITY FULL;
ALTER TABLE duels REPLICA IDENTITY FULL;
```

Run this after creating the tables. Without it, Supabase Realtime will not broadcast
row changes to Flutter subscribers.

### 4.6 Indexes for fast leaderboard queries

```sql
CREATE INDEX idx_profiles_xp ON profiles(xp DESC);
CREATE INDEX idx_profiles_week_xp ON profiles(week_xp DESC);
CREATE INDEX idx_profiles_class_code ON profiles(class_code);
CREATE INDEX idx_duels_challenger ON duels(challenger_id);
CREATE INDEX idx_duels_opponent ON duels(opponent_id);
CREATE INDEX idx_duels_status ON duels(status);
```

---

## 6. Flutter Dependencies

Open `pubspec.yaml` and add the following under `dependencies`. Keep all existing
dependencies — only add the new ones:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # --- existing ---
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  uuid: ^4.5.1
  google_fonts: ^6.2.1

  # --- new additions ---
  supabase_flutter: ^2.8.4          # Supabase client (auth + db + realtime)
  flutter_local_notifications: ^18.0.0  # Push-style local notifications
  connectivity_plus: ^6.1.0         # Detect online/offline for sync logic
  shared_preferences: ^2.3.3        # Store the local user UUID persistently
  intl: ^0.19.0                     # Date formatting for streak and period labels
```

After editing, run:

```bash
flutter pub get
```

---

## 7. Supabase Initialization in Flutter

### 6.1 Store credentials safely

Create a file `lib/config/supabase_config.dart`:

```dart
// lib/config/supabase_config.dart.dart
// DO NOT commit this file with real values to a public repo.
// Use --dart-define or a .env approach for production.

class SupabaseConfig {
  static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'YOUR_ANON_PUBLIC_KEY';
}
```

Replace `YOUR_PROJECT_ID` and `YOUR_ANON_PUBLIC_KEY` with the values from
Supabase → Settings → API (section 3, Step 2).

For production, pass these via `--dart-define` flags in your build command so they
are never hard-coded in source:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhb...
```

Then read them with `const String.fromEnvironment('SUPABASE_URL')`.

### 6.2 Initialize in main.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (existing)
  await Hive.initFlutter();
  // Open your existing Hive boxes here
  await Hive.openBox('settings');
  await Hive.openBox('userProfile');  // new box for profile data

  // Initialize Supabase (new)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: VocabGameApp(),
    ),
  );
}

// Helper getter — use this anywhere in the app to access Supabase
final supabase = Supabase.instance.client;
```

---

## 8. Phase 1 — Foundation (Week 1)

Goal: XP system, streak tracking, levels, and basic Supabase profile sync. This is
the foundation everything else builds on. Do not skip to Phase 2 without completing
every sub-section here.

---

### 7.1 User Profile Model (Hive)

This is the local copy of the profile. It is the source of truth during gameplay.
Supabase is the remote backup that is synced after each session.

Create `lib/models/user_profile.dart`:

```dart
import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 10)
class UserProfile extends HiveObject {
  @HiveField(0)
  late String id;           // UUID — generated once, stored in shared_preferences

  @HiveField(1)
  late String username;     // Set during onboarding

  @HiveField(2)
  int xp = 0;               // Total XP (never resets)

  @HiveField(3)
  int level = 1;

  @HiveField(4)
  int streakDays = 0;

  @HiveField(5)
  String? lastPlayedDate;   // ISO date string "2026-03-27"

  @HiveField(6)
  String? classCode;

  @HiveField(7)
  int weekXp = 0;           // Resets every Monday

  @HiveField(8)
  int totalWordsAnswered = 0;

  @HiveField(9)
  int totalCorrect = 0;
}
```

After creating this file, run:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

This generates `user_profile.g.dart` (the Hive type adapter). You must re-run this
command any time you add or change `@HiveField` annotations.

---

### 7.2 XP Engine

Create `lib/services/xp_service.dart`:

```dart
// lib/services/xp_service.dart

class XpService {
  // --- XP Calculation ---
  // Call this after every question answer.
  // secondsLeft: how many seconds remained on the timer when they answered
  // maxSeconds: the total timer length for one question (e.g. 20)
  // streakDays: the user's current consecutive day streak
  static int calculateXp({
    required bool correct,
    required int secondsLeft,
    required int maxSeconds,
    required int streakDays,
  }) {
    if (!correct) return 0;

    const int baseXp = 10;

    // Speed bonus: scales from 0 (answered at last second) to 10 (instant answer)
    final double speedRatio = secondsLeft / maxSeconds;
    final int speedBonus = (speedRatio * 10).round();

    // Streak multiplier
    final int streakMultiplier = _streakMultiplier(streakDays);

    return (baseXp + speedBonus) * streakMultiplier;
  }

  static int _streakMultiplier(int streakDays) {
    if (streakDays >= 30) return 4;
    if (streakDays >= 14) return 3;
    if (streakDays >= 7)  return 2;
    return 1;
  }

  // --- Level Calculation ---
  // Level is derived from total XP. Formula: level = floor(sqrt(xp / 50)) + 1
  // Level 1: 0 XP, Level 2: 50 XP, Level 3: 200 XP, Level 4: 450 XP ...
  // This creates a curve where early levels are fast and later levels are slower.
  static int levelFromXp(int xp) {
    return (xp / 50).ceil().toRadixString(10).length + // not this
        (xp < 50 ? 1 : (xp < 200 ? 2 : (xp < 450 ? 3 : (xp < 800 ? 4 :
        (xp < 1250 ? 5 : (xp < 1800 ? 6 : (xp < 2450 ? 7 : (xp < 3200 ? 8 :
        (xp < 4050 ? 9 : 10)))))))));
    // Simpler version — use this:
  }

  // Use this clean version:
  static int levelFromXpClean(int xp) {
    // Every level requires: level^2 * 50 XP total
    // Level 1: 0,  Level 2: 50, Level 3: 200, Level 4: 450, Level 5: 800...
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  static int xpRequiredForLevel(int level) {
    // XP needed to REACH this level from 0
    return (level - 1) * (level - 1) * 50;
  }

  static int xpProgressInLevel(int totalXp) {
    // XP earned within the current level (for the XP bar fill %)
    final int currentLevel = levelFromXpClean(totalXp);
    final int xpAtCurrentLevel = xpRequiredForLevel(currentLevel);
    return totalXp - xpAtCurrentLevel;
  }

  static int xpNeededForNextLevel(int totalXp) {
    // Total XP span of the current level
    final int currentLevel = levelFromXpClean(totalXp);
    return xpRequiredForLevel(currentLevel + 1) - xpRequiredForLevel(currentLevel);
  }

  static double levelProgressPercent(int totalXp) {
    // 0.0 to 1.0 — for the XP progress bar widget
    return xpProgressInLevel(totalXp) / xpNeededForNextLevel(totalXp);
  }
}
```

**How to call it in your game logic (in your existing game provider):**

```dart
// Inside your answer-submission handler:
final int xpGained = XpService.calculateXp(
  correct: isCorrect,
  secondsLeft: remainingSeconds,   // from your existing timer
  maxSeconds: 20,                   // whatever your question timer is
  streakDays: profile.streakDays,
);

if (xpGained > 0) {
  profile.xp += xpGained;
  profile.weekXp += xpGained;
  profile.level = XpService.levelFromXpClean(profile.xp);
  profile.totalWordsAnswered += 1;
  if (isCorrect) profile.totalCorrect += 1;
  await profile.save();  // save to Hive immediately
}
```

---

### 7.3 Streak System

The streak system runs every time the app launches or a game session begins.

Add this to `lib/services/streak_service.dart`:

```dart
import 'package:intl/intl.dart';
import '../models/user_profile.dart';

class StreakService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  static String _today() => _dateFormat.format(DateTime.now());

  static String _yesterday() =>
      _dateFormat.format(DateTime.now().subtract(const Duration(days: 1)));

  // Call this at the START of every game session (before showing questions).
  // Returns true if the streak was just incremented (to show a celebration).
  static bool checkAndUpdateStreak(UserProfile profile) {
    final String today = _today();
    final String? lastPlayed = profile.lastPlayedDate;

    if (lastPlayed == today) {
      // Already played today — do nothing, streak is fine
      return false;
    }

    if (lastPlayed == _yesterday()) {
      // Played yesterday — increment streak
      profile.streakDays += 1;
      profile.lastPlayedDate = today;
      profile.save();
      return true; // show streak celebration
    }

    // Missed a day (or first time playing)
    final bool wasStreak = profile.streakDays > 1;
    profile.streakDays = 1; // reset to 1 (today counts)
    profile.lastPlayedDate = today;
    profile.save();
    if (wasStreak) {
      // Optionally: show "Your streak was broken 😢" message
    }
    return false;
  }

  // Call this ONCE when the app opens (in your root widget or splash screen)
  // to check if a streak was broken while the app was closed.
  static void checkStreakOnAppOpen(UserProfile profile) {
    final String today = _today();
    final String? lastPlayed = profile.lastPlayedDate;

    if (lastPlayed == null || lastPlayed == today || lastPlayed == _yesterday()) {
      // Fine — no action needed
      return;
    }

    // They missed more than 1 day
    profile.streakDays = 0;
    profile.save();
  }
}
```

**Streak protection notification** — schedule this every day at 11:00 PM if the
student has not played yet. Implementation is in section 10, Hook 1.

---

### 7.4 Level System

The level badge and XP bar are shown on the home screen and profile. Here is a
complete Flutter widget for the XP bar:

```dart
// lib/widgets/xp_bar_widget.dart
import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class XpBarWidget extends StatelessWidget {
  final int totalXp;
  const XpBarWidget({super.key, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final int level = XpService.levelFromXpClean(totalXp);
    final double progress = XpService.levelProgressPercent(totalXp);
    final int xpInLevel = XpService.xpProgressInLevel(totalXp);
    final int xpNeeded = XpService.xpNeededForNextLevel(totalXp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Lvl $level',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '$xpInLevel / $xpNeeded XP',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
          ),
        ),
      ],
    );
  }
}
```

---

### 7.5 Syncing to Supabase

Create `lib/services/sync_service.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../main.dart'; // for the supabase getter

class SyncService {

  // Call this after every game session ends.
  // It is safe to call even when offline — it will silently do nothing if no connection.
  static Future<void> syncProfile(UserProfile profile) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return; // offline — skip

    try {
      await supabase.from('profiles').upsert({
        'id': profile.id,
        'username': profile.username,
        'xp': profile.xp,
        'level': profile.level,
        'streak_days': profile.streakDays,
        'last_played_date': profile.lastPlayedDate,
        'class_code': profile.classCode,
        'week_xp': profile.weekXp,
        'total_words_answered': profile.totalWordsAnswered,
        'total_correct': profile.totalCorrect,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id'); // upsert = insert if new, update if exists
    } catch (e) {
      // Silently fail — do not crash the app if sync fails
      // Optionally log to a local error log
      debugPrint('Sync failed: $e');
    }
  }

  // Call this on app start to restore profile from Supabase
  // (in case the user reinstalled the app or is on a new device)
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return null;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Fetch profile failed: $e');
      return null;
    }
  }
}
```

**Where to call `syncProfile`:** At the end of your game session screen, after
the results are shown. Not after every single question — that would be too many
API calls. Once per session is correct.

---

## 9. Phase 2 — The Arena (Weeks 2–3)

---

### 8.1 Leaderboard Screen

The leaderboard has three tabs:
1. **My Class** — top 50 in the student's class (by total XP)
2. **Global** — top 100 across all users (by total XP)
3. **This Week** — top 50 in class (by week_xp, resets Monday)

Create `lib/screens/leaderboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _classBoard = [];
  List<Map<String, dynamic>> _globalBoard = [];
  List<Map<String, dynamic>> _weekBoard = [];
  bool _loading = true;
  String? _classCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _subscribeToRealtime(); // live updates
  }

  Future<void> _loadData() async {
    // Get the user's class code from local profile
    final profileBox = Hive.box('userProfile');
    _classCode = profileBox.get('classCode');

    // Fetch all three boards in parallel
    final results = await Future.wait([
      if (_classCode != null)
        supabase
            .from('profiles')
            .select('username, xp, level, streak_days')
            .eq('class_code', _classCode!)
            .order('xp', ascending: false)
            .limit(50)
      else
        Future.value(<Map<String, dynamic>>[]),

      supabase
          .from('profiles')
          .select('username, xp, level')
          .order('xp', ascending: false)
          .limit(100),

      if (_classCode != null)
        supabase
            .from('profiles')
            .select('username, week_xp, level')
            .eq('class_code', _classCode!)
            .order('week_xp', ascending: false)
            .limit(50)
      else
        Future.value(<Map<String, dynamic>>[]),
    ]);

    if (mounted) {
      setState(() {
        _classBoard = List<Map<String, dynamic>>.from(results[0] as List);
        _globalBoard = List<Map<String, dynamic>>.from(results[1] as List);
        _weekBoard = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    }
  }

  void _subscribeToRealtime() {
    // Listen for any change on the profiles table and reload
    supabase
        .channel('leaderboard-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            _loadData(); // reload all boards when any profile changes
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Class'),
            Tab(text: 'Global'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBoard(_classBoard, scoreKey: 'xp'),
                _buildBoard(_globalBoard, scoreKey: 'xp'),
                _buildBoard(_weekBoard, scoreKey: 'week_xp'),
              ],
            ),
    );
  }

  Widget _buildBoard(List<Map<String, dynamic>> entries, {required String scoreKey}) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data yet — play to appear here!'));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final String medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}';
        return ListTile(
          leading: Text(medal, style: const TextStyle(fontSize: 20)),
          title: Text(entry['username'] ?? '???'),
          subtitle: Text('Level ${entry['level'] ?? 1}'),
          trailing: Text('${entry[scoreKey] ?? 0} XP',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    supabase.channel('leaderboard-updates').unsubscribe();
    super.dispose();
  }
}
```

---

### 8.2 Class Room System

**Creating a class (teacher side):**

```dart
// lib/services/class_service.dart

class ClassService {
  // Teacher calls this to create a class
  static Future<String> createClass({
    required String teacherUsername,
    required String className,
  }) async {
    // Generate a 6-character uppercase code
    final code = _generateCode();

    await supabase.from('classes').insert({
      'code': code,
      'teacher_username': teacherUsername,
      'class_name': className,
    });

    return code; // return to show the teacher
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Student calls this to join a class
  static Future<bool> joinClass({
    required String profileId,
    required String code,
  }) async {
    // Verify the code exists
    final classData = await supabase
        .from('classes')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();

    if (classData == null) return false; // invalid code

    // Update the student's profile
    await supabase
        .from('profiles')
        .update({'class_code': code.toUpperCase()})
        .eq('id', profileId);

    // Update local Hive profile too
    final profileBox = Hive.box('userProfile');
    profileBox.put('classCode', code.toUpperCase());

    return true;
  }
}
```

**Join class UI:** A simple dialog with a text field. Student types the code their
teacher wrote on the board. On submit, call `ClassService.joinClass()`. Show a
success or error message. Redirect to the leaderboard on success.

---

### 8.3 Weekly Tournament Reset

This runs automatically every Monday at 00:01 UTC via `pg_cron` in Supabase.

Go to **Supabase → SQL Editor** and run:

```sql
-- First, enable pg_cron if not done already
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Before resetting, snapshot the top 3 into the hall_of_fame table
-- (the function runs first, then week_xp is set to 0)
CREATE OR REPLACE FUNCTION award_weekly_hall_of_fame()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  period_label text;
  rec record;
  rank_num integer := 1;
BEGIN
  -- Generate label like "March 2026 — Week 13"
  period_label := to_char(now(), 'Month YYYY') || ' — Week ' || to_char(now(), 'IW');

  -- Get top 3 by week_xp (only if they have at least 1 XP this week)
  FOR rec IN
    SELECT id, username, week_xp
    FROM profiles
    WHERE week_xp > 0
    ORDER BY week_xp DESC
    LIMIT 3
  LOOP
    INSERT INTO hall_of_fame (profile_id, username, rank, week_xp, period_label)
    VALUES (rec.id, rec.username, rank_num, rec.week_xp, period_label);
    rank_num := rank_num + 1;
  END LOOP;

  -- Now reset week_xp for everyone
  UPDATE profiles SET week_xp = 0;
END;
$$;

-- Schedule it every Monday at 00:01 UTC
SELECT cron.schedule(
  'weekly-reset',           -- job name (must be unique)
  '1 0 * * 1',             -- cron expression: 00:01 every Monday
  'SELECT award_weekly_hall_of_fame();'
);
```

To verify the cron job is scheduled, run:

```sql
SELECT * FROM cron.job;
```

To test it manually without waiting for Monday:

```sql
SELECT award_weekly_hall_of_fame();
```

---

### 8.4 Teacher Dashboard

Build this as a separate Flutter Web route or a dedicated screen visible only
when `profile.isTeacher == true`.

The teacher dashboard shows:
- A sortable table of all students in their class
- Columns: Username, Total XP, Level, Streak, Words Answered, Accuracy
- A button to export the data to CSV (use `dart:html` on web, share_plus on mobile)

```dart
// Fetch class roster
final students = await supabase
    .from('profiles')
    .select('username, xp, level, streak_days, total_words_answered, total_correct')
    .eq('class_code', teacherClassCode)
    .order('xp', ascending: false);
```

The accuracy percentage is: `(total_correct / total_words_answered * 100).round()`

---

## 10. Phase 3 — Obsession (Week 4+)

---

### 9.1 1v1 Live Duel Engine

A duel is a 10-question battle where both players get the same words simultaneously.
The duel screen is a real-time widget — each player's score updates as the opponent
answers.

**Step 1 — Challenge another player:**

```dart
// lib/services/duel_service.dart

class DuelService {
  // Challenger calls this
  static Future<String> createDuel({
    required String challengerId,
    required String challengerUsername,
    required String opponentId,
    required String opponentUsername,
    required List<String> wordIds, // 10 word IDs selected randomly from your word bank
  }) async {
    final response = await supabase.from('duels').insert({
      'challenger_id': challengerId,
      'opponent_id': opponentId,
      'challenger_username': challengerUsername,
      'opponent_username': opponentUsername,
      'status': 'pending',
      'word_set': wordIds, // stored as JSONB
    }).select().single();

    return response['id'] as String; // the duel ID
  }

  // Opponent calls this to accept
  static Future<void> acceptDuel(String duelId) async {
    await supabase.from('duels').update({
      'status': 'active',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', duelId);
  }

  // Opponent calls this to decline
  static Future<void> declineDuel(String duelId) async {
    await supabase.from('duels').update({'status': 'declined'}).eq('id', duelId);
  }

  // Both players call this after every answer to update their score
  static Future<void> updateScore({
    required String duelId,
    required bool isChallenger,
    required int score,
  }) async {
    final column = isChallenger ? 'challenger_score' : 'opponent_score';
    await supabase.from('duels').update({column: score}).eq('id', duelId);
  }

  // Call this when one player finishes all 10 questions
  static Future<void> finishDuel({
    required String duelId,
    required int challengerFinalScore,
    required int opponentFinalScore,
    required String challengerId,
    required String opponentId,
  }) async {
    final winnerId = challengerFinalScore >= opponentFinalScore
        ? challengerId
        : opponentId;

    // XP rewards: winner gets 50, loser gets 10 (for participation)
    final challengerXp = challengerId == winnerId ? 50 : 10;
    final opponentXp = opponentId == winnerId ? 50 : 10;

    await supabase.from('duels').update({
      'status': 'finished',
      'winner_id': winnerId,
      'challenger_xp_gain': challengerXp,
      'opponent_xp_gain': opponentXp,
      'finished_at': DateTime.now().toIso8601String(),
    }).eq('id', duelId);

    // Award XP to both players in their profiles
    // Use Supabase RPC (database function) to safely increment XP
    await supabase.rpc('increment_xp', params: {
      'profile_id': challengerId,
      'amount': challengerXp,
    });
    await supabase.rpc('increment_xp', params: {
      'profile_id': opponentId,
      'amount': opponentXp,
    });
  }
}
```

**Create the `increment_xp` Supabase function** (run in SQL Editor):

```sql
CREATE OR REPLACE FUNCTION increment_xp(profile_id uuid, amount integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE profiles
  SET
    xp = xp + amount,
    week_xp = week_xp + amount,
    level = GREATEST(1, FLOOR(SQRT((xp + amount) / 50.0))::integer + 1)
  WHERE id = profile_id;
END;
$$;
```

**Step 2 — Real-time duel screen:**

```dart
// lib/screens/duel_screen.dart
// Subscribe to the duel row to get live updates of opponent's score

void _subscribeToDuel(String duelId) {
  supabase
      .channel('duel:$duelId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'duels',
        filter: PostgresChangeFilter(
          type: FilterType.eq,
          column: 'id',
          value: duelId,
        ),
        callback: (payload) {
          final data = payload.newRecord;
          setState(() {
            // Update opponent's live score on screen
            if (widget.isChallenger) {
              opponentScore = data['opponent_score'] ?? 0;
            } else {
              opponentScore = data['challenger_score'] ?? 0;
            }

            // Check if duel finished (both players done)
            if (data['status'] == 'finished') {
              _showResults(data);
            }
          });
        },
      )
      .subscribe();
}
```

**Duel word selection:** When creating a duel, select 10 random word IDs from your
existing local word bank (in Hive). Both players load those same 10 words by ID.
The words are stored in the `word_set` JSON field in Supabase.

---

### 9.2 Revenge Button

After a duel ends, the loser sees a "Rematch" button. When tapped it calls
`DuelService.createDuel()` with the players swapped — the loser becomes the
challenger this time. The same 10 words are used for rematches to make them feel
personal.

```dart
// On the results screen:
if (!isWinner)
  ElevatedButton.icon(
    icon: const Icon(Icons.replay),
    label: const Text('Rematch ↗'),
    onPressed: () async {
      await DuelService.createDuel(
        challengerId: myProfileId,
        challengerUsername: myUsername,
        opponentId: opponentProfileId,
        opponentUsername: opponentUsername,
        wordIds: previousWordIds, // same 10 words
      );
      // Show "Challenge sent!" snackbar
    },
  ),
```

Also add a "Revenge" entry point from the leaderboard: if a student sees they have
been overtaken by a classmate, show a "⚔️ Challenge" button next to that student's
name in the leaderboard list.

---

### 9.3 Wall of Fame

The Wall of Fame screen reads from the `hall_of_fame` table and groups entries by
`period_label`. Display in reverse chronological order (most recent week first).

```dart
// Fetch hall of fame grouped by period
final fame = await supabase
    .from('hall_of_fame')
    .select()
    .order('awarded_at', ascending: false)
    .limit(100);

// Group by period_label in Dart:
final Map<String, List<Map<String, dynamic>>> grouped = {};
for (final entry in fame) {
  final label = entry['period_label'] as String;
  grouped.putIfAbsent(label, () => []).add(entry);
}
```

Each period shows three entries with gold, silver, bronze emoji:
`🥇 Sardor — 2,340 XP`
`🥈 Malika — 1,980 XP`
`🥉 Jasur — 1,640 XP`

If the current user appears in any entry, highlight their row in amber.

---

### 9.4 Push Notifications

Use `flutter_local_notifications` for all notifications. These are local (device-only)
and do not require a server. They are triggered by app logic.

```dart
// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings =
        InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
  }

  // Streak protection — schedule every day at 23:00 if they haven't played
  static Future<void> scheduleStreakWarning(int streakDays) async {
    if (streakDays < 2) return; // only warn if they have a streak worth protecting

    await _plugin.zonedSchedule(
      0, // notification ID (0 = streak warning slot)
      '🔥 Your $streakDays-day streak is in danger!',
      'Open the app before midnight to keep your streak alive.',
      _todayAt(23, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails('streak', 'Streak Alerts',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Cancel the streak warning (call this after the user plays)
  static Future<void> cancelStreakWarning() async {
    await _plugin.cancel(0);
  }

  // Instant notification when you are overtaken on the leaderboard
  static Future<void> notifyOvertaken(String byUsername) async {
    await _plugin.show(
      1,
      '⚡ $byUsername just passed you!',
      'Open the game and reclaim your rank.',
      const NotificationDetails(
        android: AndroidNotificationDetails('rivalry', 'Rivalry Alerts',
            importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // Notify when a duel challenge arrives
  static Future<void> notifyDuelChallenge(String challengerUsername) async {
    await _plugin.show(
      2,
      '⚔️ $challengerUsername challenged you!',
      'Accept the duel before it expires.',
      const NotificationDetails(
        android: AndroidNotificationDetails('duels', 'Duel Challenges',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static tz.TZDateTime _todayAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
```

**Initialize in main.dart** (inside the `main()` function, after Supabase):

```dart
await NotificationService.initialize();
```

**Request permission on iOS and newer Android** — call this once, ideally on the
onboarding screen after the user picks their username:

```dart
await _plugin.resolvePlatformSpecificImplementation<
    IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
```

---

### 9.5 Duel History

Display a list of all duels the user has participated in.

```dart
// Fetch duel history for a user
final duels = await supabase
    .from('duels')
    .select()
    .or('challenger_id.eq.$myId,opponent_id.eq.$myId')
    .eq('status', 'finished')
    .order('finished_at', ascending: false)
    .limit(50);
```

For each duel, compute and display:
- Opponent name
- My score vs their score
- Win or loss (compare `winner_id` to `myId`)
- XP gained (`challenger_xp_gain` or `opponent_xp_gain` depending on role)
- Date played

---

## 11. The 6 Addiction Hooks — Implementation

---

### Hook 1 — Daily Streak with Terror (Fear of Loss)

**Implementation checklist:**
- [ ] `StreakService.checkAndUpdateStreak(profile)` called at game session start
- [ ] `StreakService.checkStreakOnAppOpen(profile)` called in root widget's `initState`
- [ ] Streak counter shown prominently on home screen (large number + 🔥 emoji)
- [ ] Glow or pulse animation on streak when `streakDays > 7`
- [ ] `NotificationService.scheduleStreakWarning(streakDays)` called every day when
  session ends — reschedule for 11pm of the same day
- [ ] `NotificationService.cancelStreakWarning()` called at the start of a game session
  (they are playing — no need to warn them)
- [ ] Message on home screen when streak > 0 and not yet played today:
  "Play today to keep your 🔥 {streakDays}-day streak alive!"

**Milestone messages to show in a dialog when streak hits certain numbers:**

| Streak | Message |
|---|---|
| 3 days | "You're on a roll! 🔥 3-day streak!" |
| 7 days | "One week strong! 💪 You're a habit now." |
| 14 days | "Two weeks! 🏆 You're in the top players." |
| 30 days | "One month! 👑 You are legendary." |

---

### Hook 2 — Live Class Leaderboard (Social Comparison)

**Implementation checklist:**
- [ ] Leaderboard screen is reachable from home screen with one tap
- [ ] Supabase Realtime subscription active while the leaderboard screen is open
- [ ] When the user's rank changes (detected by comparing their position in the list
  before and after a refresh), show a subtle animation — their row slides to its
  new position
- [ ] The user's own row is always highlighted (colored background or bold name)
- [ ] Show "You are #N in your class" on the home screen (not just in the leaderboard)
- [ ] The leaderboard loads cached data instantly (store last result in Hive), then
  refreshes from Supabase in the background

**Rival auto-match logic:** When the user opens the leaderboard, find the person
directly above them. Store that username as their "current rival" in local storage.
Show on the home screen: "Your rival: Kamila — you're 120 XP behind."

---

### Hook 3 — 1v1 Live Duels (Direct Rivalry)

**Implementation checklist:**
- [ ] "Challenge" button next to every student in the class leaderboard
- [ ] Duel invitation system: challenger creates duel → opponent receives in-app
  notification → opponent has 60 seconds to accept or it expires
- [ ] Duel screen shows both scores live updating (via Supabase Realtime)
- [ ] 10 questions with a per-question timer (10 seconds recommended for duels)
- [ ] After duel: clear winner/loser screen with XP gain shown with animation
- [ ] "Rematch" button for loser, "Share result" for winner
- [ ] Duel invite expiry: check `created_at` — if more than 5 minutes ago and still
  `pending`, auto-decline it in the UI

**Detecting incoming duel invitations:** Subscribe to the `duels` table filtered
by `opponent_id = myId` and `status = pending`. Do this in a long-lived provider
(not a screen) so it works while the user is anywhere in the app.

```dart
// In a root-level Riverpod provider or in your app's main widget:
supabase
    .channel('incoming-duels')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'duels',
      filter: PostgresChangeFilter(
        type: FilterType.eq,
        column: 'opponent_id',
        value: myProfileId,
      ),
      callback: (payload) {
        final challenger = payload.newRecord['challenger_username'];
        // Show a banner or dialog: "⚔️ $challenger challenged you!"
        NotificationService.notifyDuelChallenge(challenger);
      },
    )
    .subscribe();
```

---

### Hook 4 — XP + Speed Multiplier (Variable Reward)

**Implementation checklist:**
- [ ] Timer is visible on every question (countdown bar, not just a number)
- [ ] XP gained is shown immediately after each correct answer (+12 XP, +8 XP etc.)
  — show it as a floating "+N XP" animation that fades up and disappears
- [ ] Session summary screen shows total XP earned that session, broken down:
  "Base XP: 100 | Speed bonus: +40 | Streak multiplier: ×2 | Total: 280 XP"
- [ ] Speed bonus visual: a "⚡ FAST!" label appears when they answer in under
  3 seconds
- [ ] If the student answers incorrectly, show a brief red flash — no XP, no harsh
  message, just the correct answer revealed

**XP floating animation widget:**

```dart
// Simple +XP animation — position it over the answer buttons area
class XpFloatWidget extends StatefulWidget {
  final int xp;
  const XpFloatWidget({super.key, required this.xp});

  @override
  State<XpFloatWidget> createState() => _XpFloatWidgetState();
}

class _XpFloatWidgetState extends State<XpFloatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _position = Tween(begin: Offset.zero, end: const Offset(0, -1.5)).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _position,
        child: Text('+${widget.xp} XP',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

### Hook 5 — Weekly Class Tournament (Hope & Fresh Start)

**Implementation checklist:**
- [ ] "This Week" tab in the leaderboard uses `week_xp` not total `xp`
- [ ] Countdown timer on the leaderboard showing "Resets in X days Y hours"
- [ ] Every Monday morning, show a banner on the home screen:
  "🏆 New week! Fresh start — climb to #1!"
- [ ] If a student was in the top 3 last week, show a congratulation screen on
  Monday when they open the app: "You finished #2 last week! 🥈"
- [ ] The weekly reset (via pg_cron) is covered in section 8.3

**Countdown to Monday midnight (UTC):**

```dart
String weekResetCountdown() {
  final now = DateTime.now().toUtc();
  // Find next Monday 00:01 UTC
  int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
  if (daysUntilMonday == 0 && now.hour >= 0) daysUntilMonday = 7;
  final nextReset = DateTime.utc(
      now.year, now.month, now.day + daysUntilMonday, 0, 1);
  final diff = nextReset.difference(now);
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  final minutes = diff.inMinutes % 60;
  return 'Resets in ${days}d ${hours}h ${minutes}m';
}
```

---

### Hook 6 — Permanent Hall of Fame (Legacy & Status)

**Implementation checklist:**
- [ ] Hall of Fame screen shows all weekly winners, grouped by period, newest first
- [ ] Any student who appears in the Hall of Fame has a small trophy icon next to
  their username everywhere in the app (leaderboard rows, duel history, etc.)
- [ ] On the user's profile screen, show how many times they have been in the Hall
  of Fame and their best ranks
- [ ] The trophy icon check: query `hall_of_fame` by `username`, cache the result
  in Hive for 24 hours (do not query on every render)

```dart
// Check if a username is in the Hall of Fame
// Call this once on login and cache the result locally
Future<bool> isInHallOfFame(String username) async {
  final result = await supabase
      .from('hall_of_fame')
      .select('id')
      .eq('username', username)
      .limit(1);
  return result.isNotEmpty;
}
```

---

## 12. First Impression Onboarding Flow

> Before writing a single line of onboarding code, define who you are onboarding.
> See Section 11.1 — Dream Customer below.

### 11.1 Dream Customer Definition (DotCom Secrets)

> **DotCom Secrets principle:** Know exactly who your dream customer is before you
> design any funnel or onboarding flow. Every word on every screen should speak
> directly to them.

Vocab Game has **two dream customers** who operate in the same ecosystem:

**Dream Customer A — The Student (primary user)**
- Age 12–18, studying English as a second language (Uzbekistan context)
- Motivated by social status among classmates — being seen as smart and competitive
- Pain: vocabulary study is boring and feels pointless alone
- Desire: to beat their friends, be top of the class, earn visible recognition
- Fear: falling behind, looking dumb, losing a streak in front of peers
- Where they hang out: Telegram groups, Instagram, TikTok, school chat rooms
- Device: Android phone (primary), low-mid range hardware

**Dream Customer B — The Teacher (distribution channel)**
- Age 25–45, English teacher in a secondary school or language center
- Motivated by student engagement and measurable progress
- Pain: homework completion is low, students are disengaged, tracking is manual
- Desire: a tool students actually want to use that also gives the teacher visibility
- Fear: wasting class time on tech that doesn't work offline or is too complicated
- Where they hang out: Telegram teacher communities, Facebook groups, school staff rooms
- Decision power: they choose what tools their class uses

**How this changes the onboarding:**
- Screen 1 copy: "Learn words. Beat your class." — speaks to Student A's desire
- No email required — Student A will not create an account with an email
- Class code join — Student A enters it because their Teacher B gave it to them
- The "rank reveal" moment ("You're #7. Kamila is just ahead.") — triggers Student A's
  competitive instinct in the first 60 seconds

---

The onboarding must take under 15 seconds. No email. No password. Just a username.

**Screen 1 — Welcome (shown only on first launch):**
- App name + tagline: "Learn words. Beat your class."
- Single button: "Get started"
- Detect first launch via `SharedPreferences`: key `has_onboarded` = false

**Screen 2 — Pick a username:**
- Text field: "Choose your username"
- Real-time uniqueness check as they type (debounced 600ms delay to avoid too many
  Supabase queries):

```dart
// Debounced username check
Timer? _debounce;
void _onUsernameChanged(String value) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 600), () async {
    final exists = await _checkUsernameExists(value);
    setState(() => _usernameAvailable = !exists);
  });
}

Future<bool> _checkUsernameExists(String username) async {
  if (username.length < 3) return false;
  final result = await supabase
      .from('profiles')
      .select('id')
      .eq('username', username.trim())
      .limit(1);
  return result.isNotEmpty;
}
```

- Show green checkmark when available, red X when taken
- "Continue" button only enabled when the username is valid and available

**On "Continue":**

```dart
// Generate a UUID for this device/user — saved permanently in SharedPreferences
final prefs = await SharedPreferences.getInstance();
String? userId = prefs.getString('user_id');
if (userId == null) {
  userId = const Uuid().v4();
  await prefs.setString('user_id', userId);
}

// Create the profile in Supabase
await supabase.from('profiles').insert({
  'id': userId,
  'username': username.trim(),
  'xp': 0,
  'level': 1,
  'streak_days': 0,
});

// Save to Hive for local access
final profileBox = Hive.box('userProfile');
profileBox.put('id', userId);
profileBox.put('username', username.trim());
profileBox.put('xp', 0);
profileBox.put('level', 1);
profileBox.put('streakDays', 0);

// Mark onboarding complete
await prefs.setBool('has_onboarded', true);
```

**Screen 3 — Join a class (optional, skippable):**
- "Do you have a class code from your teacher?"
- Text field for the 6-character code
- "Join" button + "Skip for now" link
- If joined: show "Welcome to {class_name}! You're in." and navigate to home

**Immediate rank reveal (the WOW moment):**
After joining a class (or after first game session if they skip), show:
"You're currently #7 in your class. Kamila is just ahead at #6. Can you beat her?"

This is computed by fetching the class leaderboard and finding the user's position.

---

## 13. DotCom Secrets Funnel System

> **DotCom Secrets principle:** A great product with no funnel is invisible. A funnel
> is the structured path that takes a stranger and turns them into a loyal paying customer.
> The product (Sections 1–11) makes the game addictive. This section turns that
> addiction into a growth engine.

---

### 12.1 The Attractive Character

> The "Attractive Character" is the persona behind the product — the human story that
> makes people trust and follow you. It is not a mascot. It is you (the developer) or
> a carefully constructed voice.

**Your Attractive Character for Vocab Game:**

- **Name:** alienroller (your actual GitHub handle — own it)
- **Backstory:** A developer who built a vocabulary game for real students, watched them
  compete with each other, and then decided to make it so good that students would
  actually beg their teachers to use it in class.
- **Archetype:** The Reluctant Hero — you didn't set out to build an EdTech company.
  You built something that worked, and now you're sharing it.
- **Voice:** Direct, technical, unpretentious. You show the code. You show the
  leaderboard screenshots. You don't over-sell.
- **Story to lead with (for landing page, ProductHunt, Reddit):**

  > "I built a vocab game for Uzbek students learning English. I added a leaderboard.
  > Kids started playing it during lunch break. Then before school. Their teacher told
  > me they were asking to do 'homework' voluntarily for the first time. I'm building
  > this into something real."

This story is your **hook**. It is true, specific, and immediately creates curiosity
and credibility. Use it everywhere.

---

### 12.2 Funnel Map — Hook → Story → Offer

> Every piece of marketing must contain three things: a Hook (grab attention), a Story
> (build desire), and an Offer (tell them what to do next). Here is the full funnel
> mapped to Vocab Game.

```
TRAFFIC SOURCES
(Reddit, Telegram, ProductHunt, Teacher referrals)
        │
        ▼
┌─────────────────────────────────────────────────────┐
│  HOOK — The Entry Point                             │
│  "A vocab game so competitive, students play it     │
│   during lunch break without being asked."          │
│                                                     │
│  Delivery: Landing page headline / Reddit post /    │
│  ProductHunt tagline / Telegram message to teacher  │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  STORY — The Landing Page                           │
│  vocabgame.app (or GitHub Pages to start)           │
│                                                     │
│  Above fold:                                        │
│  • Hook headline                                    │
│  • 1 screenshot of the live leaderboard             │
│  • CTA: "Download Free" (links to app store)        │
│                                                     │
│  Below fold:                                        │
│  • The Attractive Character story (2 paragraphs)    │
│  • 3 screenshots: XP bar, duel screen, Hall of Fame │
│  • "For Teachers" section: "Give your class a code. │
│    Watch engagement explode."                       │
│  • Email capture: "Get notified of new word packs"  │
│    (for teachers — this is your email list entry)   │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  OFFER — The Free App (Rung 1 of Value Ladder)      │
│  No friction. No payment. Just download and play.   │
│                                                     │
│  After first session → in-app prompt:               │
│  "Share your score with your class" (Telegram link) │
│  This is your viral loop — students recruit          │
│  students who recruit teachers.                     │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────┐
│  ASCENSION — Moving Up the Value Ladder             │
│                                                     │
│  Student trigger: Streak is about to break →        │
│  "Get Streak Shield — $2.99/month"                  │
│                                                     │
│  Teacher trigger: 2nd class created → paywall →     │
│  "Upgrade to Teacher Pro — $9/month"                │
│                                                     │
│  School trigger: Teacher shares dashboard with      │
│  principal → "School License — contact us"          │
└─────────────────────────────────────────────────────┘
```

**Landing page minimum viable version:** A single HTML page on GitHub Pages costs $0.
Use this before building anything else in this section. It only needs: headline,
one screenshot, a download button, and an email field for teachers.

---

### 12.3 Email Follow-Up Sequence (For Teachers)

> The money is in the follow-up. Teachers who give you their email are your highest
> value leads. They have distribution — one teacher = 30+ students.

Use **Brevo** (formerly Sendinblue) — free up to 300 emails/day. Connect it to the
email capture form on your landing page.

**5-email sequence (send over 14 days):**

| Day | Subject | Goal |
|-----|---------|------|
| 0 (immediate) | "Here's your teacher starter guide" | Deliver value, build trust. Include the class code setup steps from Section 8.2. |
| 2 | "This is what happened when students saw the leaderboard" | Tell the Attractive Character story. Include a real screenshot. |
| 5 | "How to run a weekly vocabulary tournament in your class" | Teach them Hook 5 (Weekly Tournament). Make them feel like an expert. |
| 9 | "Your students can now challenge each other 1v1" | Announce duel feature. Show the Phase 3 feature set. |
| 14 | "Want unlimited classes + progress reports?" | Soft pitch for Teacher Pro upgrade. No pressure — "when you're ready." |

**Do not pitch in emails 1–4.** Build trust first. Teachers who trust you will upgrade
and refer colleagues. Teachers who feel sold to will unsubscribe.

---

### 12.4 Traffic Strategy — Own, Control, Earn

> DotCom Secrets divides traffic into three types. The goal is to convert all traffic
> into traffic you **own** (your email list and in-app users).

**Traffic You OWN (protect this above all else)**
- Your in-app user base (Supabase `profiles` table)
- Your teacher email list (Brevo)
- These are assets. Even if every platform bans you, these remain.
- **Action:** Every session end → prompt student to share score → grows your install base
- **Action:** Every teacher onboarding → offer email capture for "teacher tips newsletter"

**Traffic You CONTROL (pay for attention)**
- Telegram channel ads in Uzbek teacher and parent communities
- Reddit promoted posts in r/languagelearning, r/Teachers
- Google UAC (Universal App Campaign) — start with $5/day once you have 50+ reviews
- **Rule:** Only run paid traffic to a page with an email capture, not directly to the app store

**Traffic You EARN (organic, unpaid)**
- ProductHunt launch (do this on a Tuesday or Wednesday)
  - Prepare: 10 friends upvote within first hour. This determines visibility for the day.
  - Hunter: find a top ProductHunt hunter to submit it for you
- Reddit posts in r/flutter (developer audience), r/languagelearning (user audience),
  r/Teachers (teacher audience) — post the Attractive Character story, not an ad
- GitHub repo with a great README — developers who see it may share it or build on it
- Telegram: share in every Uzbek education Telegram group you can find
  (these groups have 5,000–50,000 members and zero spam filters)

**The viral loop (most important traffic mechanism):**
After every game session, show:
```
"You scored 340 XP 🔥 — share your streak with your class"
[Share on Telegram] [Copy score]
```
When a student shares this to a class group chat, every classmate who taps it and
downloads the app is **earned traffic** that cost you nothing. This is your primary
growth engine.

---

## 14. Riverpod Providers Reference

These are the key providers you need to add. They sit in `lib/providers/`.

```dart
// lib/providers/profile_provider.dart

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(null) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final box = Hive.box('userProfile');
    // Build UserProfile from Hive data
    // ... load all fields and call state = profile
  }

  Future<void> addXp(int amount) async {
    if (state == null) return;
    state!.xp += amount;
    state!.weekXp += amount;
    state!.level = XpService.levelFromXpClean(state!.xp);
    await state!.save();
    // Trigger sync (debounced — don't sync on every XP gain)
    state = state; // notify listeners
  }
}

// lib/providers/leaderboard_provider.dart

final leaderboardProvider = FutureProvider.family<
    List<Map<String, dynamic>>, LeaderboardType>((ref, type) async {
  // fetch data based on type (class, global, weekly)
});

enum LeaderboardType { myClass, global, weekly }

// lib/providers/duel_provider.dart

final incomingDuelProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  // stream from Supabase Realtime for incoming duels
});
```

---

## 15. File Structure

After completing all phases, your `lib/` directory should look like this:

```
lib/
├── config/
│   └── supabase_config.dart
├── models/
│   ├── user_profile.dart
│   └── user_profile.g.dart       (generated)
├── providers/
│   ├── profile_provider.dart
│   ├── leaderboard_provider.dart
│   └── duel_provider.dart
├── screens/
│   ├── onboarding/
│   │   ├── welcome_screen.dart
│   │   ├── username_screen.dart
│   │   └── join_class_screen.dart
│   ├── home_screen.dart          (existing — add XP bar + streak here)
│   ├── game_screen.dart          (existing — add XP calculation calls here)
│   ├── leaderboard_screen.dart
│   ├── duel/
│   │   ├── duel_lobby_screen.dart
│   │   ├── duel_game_screen.dart
│   │   └── duel_results_screen.dart
│   ├── hall_of_fame_screen.dart
│   └── profile_screen.dart
├── services/
│   ├── xp_service.dart
│   ├── streak_service.dart
│   ├── sync_service.dart
│   ├── duel_service.dart
│   ├── class_service.dart
│   └── notification_service.dart
├── widgets/
│   ├── xp_bar_widget.dart
│   ├── streak_widget.dart
│   ├── xp_float_widget.dart
│   └── leaderboard_row_widget.dart
└── main.dart
```

---

## 16. Supabase Row Level Security (RLS)

RLS ensures users can only modify their own data. Run these in SQL Editor:

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE duels ENABLE ROW LEVEL SECURITY;
ALTER TABLE hall_of_fame ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

-- Profiles: anyone can read, but you can only write your own row
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (id::text = current_setting('request.jwt.claims', true)::jsonb->>'sub');

-- For anonymous auth (no JWT sub), use a simpler policy that allows all writes
-- (appropriate for classroom use where cheating is low risk):
-- DROP POLICY "profiles_update" ON profiles;
-- CREATE POLICY "profiles_update_open" ON profiles FOR UPDATE USING (true);

-- Duels: both players can read their own duels
CREATE POLICY "duels_read" ON duels FOR SELECT
  USING (true); -- public leaderboard context — all duels are readable

CREATE POLICY "duels_insert" ON duels FOR INSERT WITH CHECK (true);
CREATE POLICY "duels_update" ON duels FOR UPDATE USING (true);

-- Hall of fame: read only
CREATE POLICY "fame_read" ON hall_of_fame FOR SELECT USING (true);

-- Classes: read only for students
CREATE POLICY "classes_read" ON classes FOR SELECT USING (true);
CREATE POLICY "classes_insert" ON classes FOR INSERT WITH CHECK (true);
```

**Note for classroom use:** Since students do not have a real login (just a UUID),
full RLS enforcement requires passing the user ID as a JWT claim. For a classroom app,
open RLS policies (allow all reads and writes) are acceptable — students are unlikely
to cheat the leaderboard. If you want stricter enforcement later, add Supabase Auth
with anonymous sign-in and the user's UUID as their auth ID.

---

## 17. Error Handling & Offline Strategy

**Golden rule: never let a network failure crash a game session.**

All Supabase calls must be wrapped in try-catch. Here is the standard pattern:

```dart
try {
  await supabase.from('profiles').upsert({...});
} on PostgrestException catch (e) {
  debugPrint('DB error ${e.code}: ${e.message}');
  // Queue for retry — store failed syncs in a Hive box called 'sync_queue'
} on SocketException {
  debugPrint('No internet — will sync later');
} catch (e) {
  debugPrint('Unknown error: $e');
}
```

**Sync queue for offline resilience:**

```dart
// When sync fails, save the pending update to Hive
final syncQueue = Hive.box('sync_queue');
syncQueue.add({
  'type': 'profile_sync',
  'data': profileData,
  'timestamp': DateTime.now().toIso8601String(),
});

// On app start (after confirming connectivity), drain the queue
final pending = syncQueue.values.toList();
for (final item in pending) {
  // retry the sync
  // if success, remove from queue
}
```

**Leaderboard offline mode:** Cache the last leaderboard result in Hive with a
timestamp. If the device is offline, show the cached data with a small label:
"Last updated 2 hours ago." Do not show an error or empty screen.

---

## 18. Testing Checklist

Before releasing each phase, verify the following:

### Phase 1
- [ ] First launch shows onboarding screens
- [ ] Username uniqueness check works (try duplicate names)
- [ ] XP is added after correct answers and NOT added for wrong answers
- [ ] Streak increments when playing on consecutive days (test by manually setting
  `lastPlayedDate` to yesterday in Hive)
- [ ] Streak resets when a day is missed (manually set `lastPlayedDate` to 3 days ago)
- [ ] Level increases when XP crosses a threshold
- [ ] XP bar fills correctly and shows the right numbers
- [ ] Profile syncs to Supabase after a session (check Supabase → Table Editor)
- [ ] App works with airplane mode on (no crashes, Hive data persists)

### Phase 2
- [ ] Leaderboard shows correct data for all 3 tabs
- [ ] Leaderboard updates live when another device plays (test with 2 devices)
- [ ] Join class with a valid code works
- [ ] Join class with an invalid code shows a clear error
- [ ] Weekly XP resets on Monday (test by running the SQL function manually)
- [ ] Hall of Fame entries are created correctly by the reset function

### Phase 3
- [ ] Challenger can create a duel
- [ ] Opponent receives an in-app notification
- [ ] Both players see each other's live scores during the duel
- [ ] XP is awarded correctly to both players after the duel
- [ ] Duel history shows past matches
- [ ] Rematch button appears for the loser and starts a new duel
- [ ] Streak warning notification fires at 11 PM if not played
- [ ] Streak warning is cancelled after playing

---

*End of implementation guide.*
*Every section in this document maps directly to a card or feature in the competitive upgrade plan.*
*Implement phases in order. Do not skip sections within a phase.*
