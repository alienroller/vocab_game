#!/usr/bin/env python3
"""
Word Enricher & Cleaner
========================
Takes the raw parsed output and:
  1. Adds frequency rank (most common English words ranked 1–N)
  2. Deduplicates
  3. Filters junk entries
  4. Splits into chunk files ready for Supabase bulk import

Usage:
    python 02_enrich.py
"""

import json
import re
import urllib.request
from pathlib import Path

IN_JSON   = Path("uzbek_words_raw.json")
OUT_JSON  = Path("uzbek_words_clean.json")
FREQ_FILE = Path("word_frequency.txt")
CHUNKS_DIR = Path("chunks")

# Word frequency list source (Peter Norvig's count_1w.txt — top 333,333 words)
FREQ_URL = "https://norvig.com/ngrams/count_1w.txt"


# ── Download frequency list ───────────────────────────────────────────────────
def get_frequency_list() -> dict[str, int]:
    """Returns {word: rank} for the top 333k English words by frequency."""
    if not FREQ_FILE.exists():
        print("⬇️  Downloading word frequency list (~10MB)...")
        urllib.request.urlretrieve(FREQ_URL, FREQ_FILE)
        print("✅ Downloaded word_frequency.txt")

    freq = {}
    with open(FREQ_FILE, encoding="utf-8") as f:
        for rank, line in enumerate(f, start=1):
            parts = line.strip().split("\t")
            if parts:
                word = parts[0].lower().strip()
                if word:
                    freq[word] = rank
    print(f"✅ Loaded {len(freq):,} word frequency entries")
    return freq


# ── Cleaning helpers ──────────────────────────────────────────────────────────
JUNK_PATTERN = re.compile(r'[^a-zA-Z\s\'\-]')  # English words should be clean

def is_valid_english(word: str) -> bool:
    if not word or len(word) < 2 or len(word) > 40:
        return False
    if JUNK_PATTERN.search(word):
        return False
    if word.isnumeric():
        return False
    return True


UZBEK_JUNK = re.compile(r'[^\w\s\'\-]')

def is_valid_uzbek(word: str) -> bool:
    if not word or len(word) < 2 or len(word) > 60:
        return False
    # Uzbek uses Latin and Cyrillic — allow both
    if word.isnumeric():
        return False
    return True


def clean_entry(entry: dict) -> dict:
    entry["english"] = entry["english"].strip().lower()
    entry["uzbek"]   = entry["uzbek"].strip().lower()
    return entry


# ── Main ──────────────────────────────────────────────────────────────────────
def enrich():
    if not IN_JSON.exists():
        print(f"❌ Input file not found: {IN_JSON}")
        print("   Run 01_parse_wiktionary.py --parse first.")
        return

    print(f"📂 Loading {IN_JSON} ...")
    with open(IN_JSON, encoding="utf-8") as f:
        raw = json.load(f)
    print(f"   Loaded {len(raw):,} raw entries")

    freq = get_frequency_list()

    # ── Clean & validate ──────────────────────────────────────────────────────
    cleaned = []
    skipped = 0
    for entry in raw:
        entry = clean_entry(entry)
        if not is_valid_english(entry["english"]):
            skipped += 1
            continue
        if not is_valid_uzbek(entry["uzbek"]):
            skipped += 1
            continue
        entry["frequency_rank"] = freq.get(entry["english"], 999999)
        cleaned.append(entry)

    print(f"   After cleaning  : {len(cleaned):,} entries ({skipped} skipped)")

    # ── Deduplicate (keep best entry per english+uzbek pair) ──────────────────
    seen  = {}
    for entry in cleaned:
        key = (entry["english"], entry["uzbek"])
        if key not in seen:
            seen[key] = entry
        else:
            # Keep the one with better frequency rank (lower = more common)
            if entry["frequency_rank"] < seen[key]["frequency_rank"]:
                seen[key] = entry

    deduped = sorted(seen.values(), key=lambda x: x["frequency_rank"])
    print(f"   After dedup     : {len(deduped):,} entries")

    # ── Add sequential IDs ────────────────────────────────────────────────────
    for i, entry in enumerate(deduped, start=1):
        entry["id"] = i

    # ── Save full clean file ──────────────────────────────────────────────────
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(deduped, f, ensure_ascii=False, indent=2)
    print(f"\n💾 Saved full clean file → {OUT_JSON}")

    # ── Print stats ───────────────────────────────────────────────────────────
    pos_counts = {}
    for e in deduped:
        pos = e.get("part_of_speech", "Unknown")
        pos_counts[pos] = pos_counts.get(pos, 0) + 1

    print(f"\n📊 Stats:")
    print(f"   Total word pairs  : {len(deduped):,}")
    for pos, count in sorted(pos_counts.items(), key=lambda x: -x[1]):
        print(f"   {pos:<15}: {count:,}")

    # ── Split into chunks for Supabase import ─────────────────────────────────
    CHUNKS_DIR.mkdir(exist_ok=True)
    chunk_size = 5000
    chunks = [deduped[i:i+chunk_size] for i in range(0, len(deduped), chunk_size)]

    for idx, chunk in enumerate(chunks):
        chunk_file = CHUNKS_DIR / f"words_chunk_{idx+1:04d}.json"
        with open(chunk_file, "w", encoding="utf-8") as f:
            json.dump(chunk, f, ensure_ascii=False)

    print(f"\n📦 Split into {len(chunks)} chunk files → {CHUNKS_DIR}/")
    print(f"   Each chunk: {chunk_size:,} words")
    print(f"\n✅ Ready! Next step: run  python 03_upload_supabase.py")

    # ── Also export top-5000 for bundling in app ──────────────────────────────
    top5000 = deduped[:5000]
    with open("top5000_bundle.json", "w", encoding="utf-8") as f:
        json.dump(top5000, f, ensure_ascii=False, separators=(",", ":"))  # minified
    top_size = Path("top5000_bundle.json").stat().st_size / 1024
    print(f"\n📱 App bundle (top 5,000 words) → top5000_bundle.json ({top_size:.0f}KB)")
    print(f"   Embed this in your app for instant offline lookup!")


if __name__ == "__main__":
    enrich()
