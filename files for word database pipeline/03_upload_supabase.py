#!/usr/bin/env python3
"""
Supabase Bulk Uploader
=======================
Uploads the cleaned word pairs to your Supabase words table in batches.

Setup:
    No pip dependencies required! Uses raw Python built-in features.

Usage:
    python 03_upload_supabase.py

Config:
    Set your credentials in the SUPABASE_URL and SUPABASE_KEY variables below,
    or export them as environment variables.
"""

import json
import os
import time
from pathlib import Path
import urllib.request
import urllib.error

# ── Config — fill these in ────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://qlfupxbxbevnljrgawrn.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZnVweGJ4YmV2bmxqcmdhd3JuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDg1NzEwOSwiZXhwIjoyMDkwNDMzMTA5fQ.aJqgStz4OZWdWQp5NDxvljziqc3fWGvu9Zxkb1EFnZI")   # use service role key for bulk insert
TABLE_NAME   = "dictionary_words"

CLEAN_FILE  = Path("oxford_enriched.json")
BATCH_SIZE  = 500       # Supabase handles 500 rows per request comfortably
SLEEP_MS    = 100       # ms between batches to avoid rate limiting


# ── Supabase SQL schema (run this in Supabase SQL editor first!) ───────────────
SCHEMA_SQL = """
-- Run this in your Supabase SQL editor BEFORE uploading:

CREATE TABLE IF NOT EXISTS dictionary_words (
    id              BIGSERIAL PRIMARY KEY,
    english         TEXT NOT NULL,
    uzbek           TEXT NOT NULL,
    part_of_speech  TEXT DEFAULT 'Unknown',
    definition      TEXT DEFAULT '',
    example         TEXT DEFAULT '',
    frequency_rank  INTEGER DEFAULT 999999,
    cefr_level      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(english, uzbek)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_dict_english ON dictionary_words(english);
CREATE INDEX IF NOT EXISTS idx_dict_uzbek   ON dictionary_words(uzbek);
CREATE INDEX IF NOT EXISTS idx_dict_freq    ON dictionary_words(frequency_rank);

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_dict_english_fts ON dictionary_words USING GIN(to_tsvector('english', english));

-- Allow public read (for your app)
ALTER TABLE dictionary_words ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read" ON dictionary_words FOR SELECT USING (true);
"""


# ── Upload ────────────────────────────────────────────────────────────────────
def upload():
    print("🗄️  Supabase Bulk Dictionary Uploader (Dependency-Free Edition)")
    print("=" * 60)

    # Validate config
    if "YOUR_PROJECT" in SUPABASE_URL or "YOUR_SERVICE" in SUPABASE_KEY:
        print("\n❌ Please set your Supabase credentials!")
        print("   Edit SUPABASE_URL and SUPABASE_KEY in this file,")
        print("   or export them as environment variables:\n")
        print("   export SUPABASE_URL='https://xxx.supabase.co'")
        print("   export SUPABASE_KEY='your-service-role-key'")
        return

    if not CLEAN_FILE.exists():
        print(f"\n❌ Clean file not found: {CLEAN_FILE}")
        print("   Run 02_enrich.py first.")
        return

    # Load data
    print(f"\n📂 Loading {CLEAN_FILE} ...")
    with open(CLEAN_FILE, encoding="utf-8") as f:
        words = json.load(f)
    print(f"   {len(words):,} word pairs to upload")

    # Connect
    print(f"\n🔌 Targeting Supabase REST API...")
    url = SUPABASE_URL.rstrip('/') + f"/rest/v1/{TABLE_NAME}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal, resolution=merge-duplicates"
    }
    print(f"   ✅ Target URL → {url}")

    # Print schema reminder
    print(f"\n⚠️  Make sure you ran the schema SQL in Supabase first!")
    print(f"   (see SCHEMA_SQL variable in this file)")
    input("   Press Enter to continue, Ctrl+C to cancel...")

    # Prepare rows (strip the 'id' field — let Supabase auto-assign)
    rows = []
    for w in words:
        rows.append({
            "english":        w.get("english", ""),
            "uzbek":          w.get("uzbek", ""),
            "part_of_speech": w.get("part_of_speech", "Unknown"),
            "definition":     w.get("definition", ""),
            "example":        w.get("example", ""),
            "frequency_rank": w.get("frequency_rank", 999999),
            "cefr_level":     w.get("cefr_level", ""),
        })

    # Upload in batches
    total    = len(rows)
    batches  = [rows[i:i+BATCH_SIZE] for i in range(0, total, BATCH_SIZE)]
    uploaded = 0
    errors   = 0

    print(f"\n🚀 Uploading {total:,} rows in {len(batches)} batches...")
    start = time.time()

    for i, batch in enumerate(batches):
        req = urllib.request.Request(
            url,
            data=json.dumps(batch).encode('utf-8'),
            headers=headers,
            method='POST'
        )
        try:
            with urllib.request.urlopen(req) as response:
                pass
            uploaded += len(batch)
        except urllib.error.HTTPError as e:
            errors += len(batch)
            print(f"\n   ⚠️  Batch {i+1} error: HTTP {e.code} - {e.read().decode('utf-8')}")
        except Exception as e:
            errors += len(batch)
            print(f"\n   ⚠️  Batch {i+1} error: {e}")

        # Progress
        pct = (i + 1) / len(batches) * 100
        elapsed = time.time() - start
        eta = (elapsed / (i + 1)) * (len(batches) - i - 1) if (i + 1) > 0 else 0
        print(f"\r   {pct:.1f}% — {uploaded:,} uploaded | {errors} errors | ETA {eta:.0f}s  ", end="", flush=True)

        time.sleep(SLEEP_MS / 1000)

    elapsed = time.time() - start
    print(f"\n\n✅ Upload complete in {elapsed:.0f}s!")
    print(f"   Uploaded : {uploaded:,}")
    print(f"   Errors   : {errors}")
    print(f"\n🎉 Your Supabase dictionary is ready!")
    print(f"   Table: {TABLE_NAME}")
    print(f"   Rows:  {uploaded:,}")


if __name__ == "__main__":
    # Print schema for reference
    print("📋 Supabase Schema (run this in SQL editor first):")
    print("-" * 50)
    print(SCHEMA_SQL)
    print("-" * 50)
    upload()
