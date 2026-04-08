# Context & Explanation for AI Assistant
## VocabGame — English→Uzbek Dictionary Pipeline

---

## Who I am and what I am building

I am building a vocabulary learning web app called **VocabGame** for Uzbek speakers who want to learn English. The app is built with **React + TypeScript** on the frontend and **Supabase** (PostgreSQL) as the backend/database. It runs on `localhost:8869` during development.

The app has these pages (bottom navigation):
- **Home** — dashboard
- **Library** — saved word collections
- **Search** — search for English words and see their Uzbek translation
- **Duels** — vocabulary game/quiz mode
- **Profile** — user profile

---

## The Problem I am solving

Right now, when a user types an English word in the **Search** page, the app calls an **external translation API** to get the Uzbek translation. This has several problems:

1. **It requires internet** — if the user is offline, search does not work at all
2. **It is slow** — every search makes a network request to an external API
3. **It costs money** — API calls have rate limits and costs
4. **It can fail** — if the API is down, the whole search feature breaks

The goal is to have a **local dictionary** with 50,000 to 100,000+ real English words pre-translated into Uzbek, stored in Supabase, so the app can look up words from its own database instead of calling an external API every time. Users should also be able to **download word packs** to their device for completely offline use.

---

## The Solution — 3-tier lookup system

When a user searches for a word, the app should check in this order:

```
User types word
      │
      ▼
TIER 1: Bundled JSON file (top 5,000 most common words)
        → Ships inside the app itself (public/top5000_bundle.json)
        → Works instantly, zero network needed, always available
        → If word found here → show result immediately
      │ (word not found)
      ▼
TIER 2: IndexedDB (browser local database on user's device)
        → Contains words the user has previously looked up
        → Also contains words from "Download Packs" the user chose to download
        → Works offline after words are cached
        → If word found here → show result immediately
      │ (word not found)
      ▼
TIER 3: Supabase database query
        → Our own database with 100,000+ word pairs
        → Requires internet connection
        → After fetching, the result is saved to IndexedDB permanently
        → Next time the same word is searched, it hits Tier 2 instead
```

This means the app gets smarter over time. Every word a user looks up gets cached forever on their device.

---

## Where the dictionary data comes from

The data source is **English Wiktionary** — a free, open-source, community-maintained dictionary at wiktionary.org. It is licensed under CC BY-SA 3.0 (free to use with attribution). Wiktionary contains translations of English words into hundreds of languages including Uzbek.

Wiktionary provides a free **data dump** — a downloadable XML file containing every single page on the site. This file is about 900MB compressed. We download this file, parse it with Python to extract English→Uzbek word pairs, clean the data, and upload it to our Supabase database.

---

## The 3 Python scripts — what each one does

### Script 1: `01_parse_wiktionary.py`

**What it does:**
- Downloads the Wiktionary XML dump file (~900MB) from `dumps.wikimedia.org`
- Reads through the file page by page WITHOUT loading the whole file into memory (uses streaming XML parsing, because the file is huge)
- For each page (which represents one English word), it looks for Uzbek translation patterns in the wikitext markup
- Wiktionary stores Uzbek translations in a specific format: `{{t|uz|yoqilgan}}` or `{{t+|uz|yoqilgan}}` — the script extracts the Uzbek word from inside these templates
- Also extracts: the part of speech (Noun, Verb, Adjective, etc.), the English definition, and an example sentence
- Skips pages that have no Uzbek translation, redirect pages, and meta/system pages
- Saves all found word pairs to `uzbek_words_raw.json`

**Why streaming parsing:**
The XML file uncompressed is ~20GB. If we tried to load it all at once, the computer would run out of memory. Instead, we use `xml.etree.ElementTree.iterparse()` which reads one XML element at a time and immediately frees memory after processing each page.

**Expected output:** 50,000–150,000 raw English→Uzbek word pairs in `uzbek_words_raw.json`

---

### Script 2: `02_enrich.py`

**What it does:**
- Reads `uzbek_words_raw.json`
- Downloads a word frequency list from Peter Norvig's dataset — this tells us how common each English word is (rank 1 = most common word like "the", rank 100,000 = rare word)
- Cleans each entry:
  - Removes words with invalid characters
  - Removes words that are too short or too long
  - Strips leftover wikitext markup
- Deduplicates entries — if the same English+Uzbek pair appears multiple times, keeps only one
- Assigns a `frequency_rank` number to each word (lower number = more common word)
- Sorts everything by frequency so rank 1 is the most common word
- Saves cleaned data to `uzbek_words_clean.json`
- Splits the data into chunk files of 5,000 words each inside a `chunks/` folder — this is for easier uploading
- Creates `top5000_bundle.json` — a minified JSON file containing only the top 5,000 most common words. This file gets copied into the app's `public/` folder so it ships with the app.

**Why frequency ranking matters:**
- The top 5,000 most common English words cover about 95% of all text a person will ever read
- By knowing which words are most common, we can prioritize them in the bundle
- We can also build "word of the day" features and beginner/advanced word sets

**Expected output:** 40,000–100,000 clean word pairs, split into chunk files

---

### Script 3: `03_upload_supabase.py`

**What it does:**
- Connects to the Supabase project using the URL and API key
- Reads `uzbek_words_clean.json`
- Uploads all words to the `dictionary_words` table in Supabase
- Uploads in batches of 500 rows at a time (Supabase handles this efficiently)
- Uses "upsert" — if a word already exists in the database, it skips it instead of creating a duplicate
- Shows upload progress

**The Supabase table structure it expects:**
```sql
CREATE TABLE dictionary_words (
    id              BIGSERIAL PRIMARY KEY,
    english         TEXT NOT NULL,        -- the English word
    uzbek           TEXT NOT NULL,        -- the Uzbek translation
    part_of_speech  TEXT,                 -- Noun, Verb, Adjective, etc.
    definition      TEXT,                 -- English definition text
    example         TEXT,                 -- example sentence
    frequency_rank  INTEGER,              -- 1 = most common, 999999 = rare
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(english, uzbek)                -- no duplicate pairs
);
```

**Before running this script**, the user must go to their Supabase project, open the SQL Editor, and run the table creation SQL. The script prints this SQL at the start.

**Configuration required:**
The user must set two environment variables (or edit them directly in the file):
- `SUPABASE_URL` — the project URL like `https://abc123.supabase.co`
- `SUPABASE_KEY` — the **service role** key (not the anon key) — found in Supabase Settings → API

---

## The 2 TypeScript files — what each one does

### `DictionaryService.ts`

**What it does:**
This is a TypeScript service class that handles all dictionary lookups in the app. It implements the 3-tier system described above.

Key methods:
- `dictionary.lookup("word")` — looks up one word, tries all 3 tiers automatically, returns a `WordEntry` object or null
- `dictionary.search("partial", limit)` — for search-as-you-type autocomplete, returns multiple results
- `dictionary.downloadPack("starter"|"standard"|"full", onProgress)` — downloads a word pack to IndexedDB
- `dictionary.getDownloadedPacks()` — returns which packs the user has downloaded
- `dictionary.getCachedWordCount()` — how many words are stored offline on this device

The three download packs:
- **Starter**: top 5,000 words (~100KB)
- **Standard**: top 20,000 words (~400KB) ← recommended
- **Full**: all 100,000+ words (~2MB)

**Where to place this file:** `src/services/DictionaryService.ts`

**How to use it in the Search page:**
```typescript
import { dictionary } from "../services/DictionaryService";

// Replace the existing API call with:
const result = await dictionary.lookup(searchQuery);
if (result) {
  setEnglishWord(result.english);
  setUzbekWord(result.uzbek);
  setDefinition(result.definition);
}
```

---

### `DownloadDictionary.tsx`

**What it does:**
A complete React page component that provides the "Download Dictionary" user interface. It matches the dark purple color scheme of the existing app.

It shows:
- A status banner showing how many words are currently stored offline on the device
- Three pack cards (Starter, Standard, Full) with descriptions and file sizes
- A download button for each pack
- A progress bar that fills up while downloading (0% to 100%)
- A checkmark on packs that have already been downloaded
- An info section explaining how offline mode works

**Where to place this file:** `src/pages/DownloadDictionary.tsx`

**How to add it to the app router:**
```typescript
import DownloadDictionary from "./pages/DownloadDictionary";
// Add this route:
<Route path="/download-dictionary" element={<DownloadDictionary />} />
```

**How to add it to the bottom navigation:**
Add a new nav item with a download icon linking to `/download-dictionary`

---

## How to run the Python scripts (order matters)

```bash
# Install dependencies
pip install supabase

# Step 1: Download Wiktionary dump and parse it (takes 30–60 min total)
python 01_parse_wiktionary.py --all

# Step 2: Clean, enrich, and split the data (takes 2–5 min)
python 02_enrich.py

# Step 3: Copy top5000_bundle.json to your app
cp top5000_bundle.json path/to/your/app/public/

# Step 4: Set credentials and upload to Supabase (takes 10–30 min)
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_KEY="your-service-role-key"
python 03_upload_supabase.py
```

---

## Important notes

1. **Run the scripts on a computer with good internet**, not a server — the Wiktionary dump is 900MB
2. **The scripts only need to be run once** — after the data is in Supabase, you never need to run them again unless you want to update the dictionary
3. **The `top5000_bundle.json` file must be in the `public/` folder** of the React app so it's served as a static file
4. **Use the service role key** (not anon key) for uploading — the anon key does not have write permission
5. **Wiktionary license**: Add "Dictionary data from Wiktionary (CC BY-SA 3.0)" to the app's About page
6. **Uzbek script**: Wiktionary uses Latin-script Uzbek (the modern standard), which is correct for modern usage

---

## What I need help with

*(Fill in what you want the AI to help you with here)*

For example:
- "Help me integrate `DictionaryService.ts` into my existing Search page component"
- "Help me add the Download Dictionary page to my app's navigation"
- "The upload script is failing with this error: [paste error]"
- "Help me modify the search to show the definition and example sentence"
