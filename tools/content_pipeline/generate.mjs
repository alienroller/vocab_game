import Anthropic from '@anthropic-ai/sdk';
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// ─── CONFIG — set these before running ───────────────────────────────
const COLLECTION_TITLE = 'Animal Farm';
const COLLECTION_SHORT_TITLE = 'Animal Farm';
const COLLECTION_DESCRIPTION = 'Vocabulary from George Orwell\'s Animal Farm';
const COLLECTION_CATEGORY = 'fiction'; // 'fiction' | 'esl' | 'academic'
const COLLECTION_DIFFICULTY = 'B1';
const COLLECTION_EMOJI = '🐷';
const COLLECTION_COLOR = '#16A34A';
const NUM_UNITS = 6;
const WORDS_PER_UNIT = 10;
// ─────────────────────────────────────────────────────────────────────

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

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
  - "example_sentence": a short, clear example sentence (NOT copied from the book)
  - "word_type": one of "noun", "verb", "adjective", "adverb", "phrase"
  - "difficulty": one of "A1", "A2", "B1", "B2"
- Units must be ordered from easier to harder vocabulary
- Unit titles should be descriptive (e.g. "Chapter 1 — The Revolution Begins")

Respond with ONLY a valid JSON array. No markdown, no explanation.
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
    model: 'claude-sonnet-4-20250514',
    max_tokens: 8000,
    messages: [{ role: 'user', content: GENERATION_PROMPT }]
  });

  const rawText = response.content[0].text.trim();
  const jsonText = rawText.replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();

  let units;
  try {
    units = JSON.parse(jsonText);
  } catch (e) {
    console.error('❌ Failed to parse JSON. Raw response saved to output_raw.txt');
    fs.writeFileSync('output_raw.txt', rawText);
    process.exit(1);
  }

  fs.writeFileSync('output_review.json', JSON.stringify(units, null, 2));
  console.log(`✅ Generated ${units.length} units`);
  console.log(`📄 Saved to output_review.json — REVIEW BEFORE INSERTING\n`);

  units.forEach(u => {
    console.log(`  Unit ${u.unit_number}: ${u.unit_title} (${u.words.length} words)`);
    u.words.slice(0, 3).forEach(w => console.log(`    • ${w.word} → ${w.translation}`));
    console.log(`    ...`);
  });

  return units;
}

async function insertToSupabase(units) {
  console.log(`\n📤 Inserting into Supabase...`);

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
      is_published: false
    })
    .select()
    .single();

  if (collErr) { console.error('Collection insert failed:', collErr); process.exit(1); }
  console.log(`✅ Collection created: ${collection.id}`);

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

// ─── Main ─────────────────────────────────────────────────────────────
const args = process.argv.slice(2);

if (args[0] === '--insert') {
  if (!fs.existsSync('output_review.json')) {
    console.error('❌ Run without --insert first to generate and review content.');
    process.exit(1);
  }
  const units = JSON.parse(fs.readFileSync('output_review.json', 'utf8'));
  await insertToSupabase(units);
} else {
  await generateContent();
  console.log('\n✋ Review output_review.json, then run: node generate.mjs --insert');
}
