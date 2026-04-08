# English→Uzbek Dictionary Pipeline
Complete pipeline to build a 100,000+ word offline dictionary for VocabGame.

---

## 📁 Files in this folder

| File | Purpose |
|------|---------|
| `01_parse_wiktionary.py` | Downloads & parses the Wiktionary dump |
| `02_enrich.py` | Cleans, deduplicates, adds frequency ranks |
| `03_upload_supabase.py` | Uploads all words to your Supabase table |
| `DictionaryService.ts` | Drop into your app — handles all lookup tiers |
| `DownloadDictionary.tsx` | Ready-made "Download Dictionary" page for your app |

---

## 🚀 Step-by-step Guide

### Prerequisites
```bash
pip install supabase requests
```

---

### Step 1 — Download & Parse Wiktionary

```bash
python 01_parse_wiktionary.py --all
```

- Downloads the English Wiktionary dump (~900MB, takes 5–30 min)
- Parses all pages and extracts English→Uzbek pairs
- Saves to `uzbek_words_raw.json`
- **Expected output: 50,000–150,000 word pairs**

If the download is too slow, you can manually download from:
https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2
Then place it in the same folder and run `--parse` only.

---

### Step 2 — Clean & Enrich

```bash
python 02_enrich.py
```

- Downloads the word frequency list (~10MB)
- Removes junk entries, deduplicates
- Sorts by frequency (most common words first)
- Saves to `uzbek_words_clean.json`
- Splits into `chunks/` folder (5,000 words per file)
- Creates `top5000_bundle.json` — copy this to your app's `public/` folder!

---

### Step 3 — Set up Supabase Table

1. Go to your Supabase project → **SQL Editor**
2. Copy and run the SQL from the top of `03_upload_supabase.py`
   (the `SCHEMA_SQL` variable)

This creates the `dictionary_words` table with proper indexes.

---

### Step 4 — Upload to Supabase

```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_KEY="your-service-role-key"   # Settings → API → service_role

python 03_upload_supabase.py
```

- Uploads in batches of 500 rows
- Skips duplicates automatically
- Takes ~10–30 minutes for 100k words
- Shows progress bar

---

### Step 5 — Add to your App

**Copy files to your project:**
```bash
cp top5000_bundle.json  your-app/public/
cp DictionaryService.ts your-app/src/services/
cp DownloadDictionary.tsx your-app/src/pages/
```

**Use the dictionary service:**
```typescript
import { dictionary } from "./services/DictionaryService";

// Look up any word (auto tier 1→2→3)
const result = await dictionary.lookup("ephemeral");
// { english: "ephemeral", uzbek: "qisqa muddatli", part_of_speech: "Adjective", ... }

// Search as you type
const suggestions = await dictionary.search("epi", 10);

// Download offline pack
await dictionary.downloadPack("standard", (pct) => {
  console.log(`${pct}% downloaded`);
});
```

**Add the Download page to your router:**
```typescript
import DownloadDictionary from "./pages/DownloadDictionary";

// In your router:
<Route path="/download-dictionary" element={<DownloadDictionary />} />
```

**Add to your bottom nav:**
```typescript
{ label: "Download", icon: DownloadIcon, path: "/download-dictionary" }
```

---

## 📊 Expected Results

| Metric | Value |
|--------|-------|
| Raw word pairs from Wiktionary | 50,000–150,000 |
| After cleaning & dedup | 40,000–100,000 |
| Supabase storage size | ~50MB |
| App bundle (top-5,000) | ~100KB |
| Starter offline pack | ~100KB |
| Standard offline pack | ~400KB |
| Full offline pack | ~2MB |

---

## 🏗️ Architecture

```
User types a word
       │
       ▼
[Tier 1] Bundled JSON (top 5,000)     ← 0ms, always works
       │ miss
       ▼
[Tier 2] IndexedDB cache              ← 1ms, offline if downloaded
       │ miss
       ▼
[Tier 3] Supabase query               ← 100–300ms, needs internet
       │ result
       ▼
  Auto-cached in IndexedDB forever
```

---

## 💡 Tips

- Run Step 1 on a machine with fast internet (the dump is 900MB)
- The Wiktionary dump is updated monthly — re-run quarterly for new words
- Uzbek on Wiktionary uses Latin script — this is correct for modern Uzbek
- Words not in Wiktionary will fall back to your existing API translation
- The `frequency_rank` column lets you build "word of the day" by picking low-ranked words

---

## 📜 License

Wiktionary data is licensed under **CC BY-SA 3.0**.
You must attribute Wiktionary if you distribute the data.
Add "Dictionary data from Wiktionary (CC BY-SA)" to your app's About page.
