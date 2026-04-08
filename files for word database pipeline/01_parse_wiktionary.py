#!/usr/bin/env python3
"""
Wiktionary English→Uzbek Parser
================================
Parses the English Wiktionary XML dump to extract English words
with their Uzbek translations.

Usage:
    1. Download dump: python 01_parse_wiktionary.py --download
    2. Parse dump:    python 01_parse_wiktionary.py --parse
    3. Both at once:  python 01_parse_wiktionary.py --all
"""

import re
import bz2
import json
import argparse
import urllib.request
from pathlib import Path
from xml.etree import ElementTree as ET

# ── Config ────────────────────────────────────────────────────────────────────
DUMP_URL  = "https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2"
DUMP_FILE = Path("enwiktionary-latest.xml.bz2")
OUT_JSON  = Path("uzbek_words_raw.json")
OUT_LOG   = Path("parse.log")

# Wiktionary template patterns for Uzbek translations
# Matches: {{t|uz|yoqilgan}}, {{t+|uz|yoqilgan}}, {{t-|uz|yoqilgan}}
UZ_PATTERN = re.compile(
    r'\{\{t[+\-]?\|uz\|([^|}\]]+)',  # capture the Uzbek word
    re.IGNORECASE
)

# Part of speech headers we care about
POS_HEADERS = {
    "Noun", "Verb", "Adjective", "Adverb", "Pronoun",
    "Preposition", "Conjunction", "Interjection", "Phrase",
    "Numeral", "Determiner", "Particle"
}

# ── Download ──────────────────────────────────────────────────────────────────
def download_dump():
    if DUMP_FILE.exists():
        print(f"✅ Dump already exists: {DUMP_FILE} ({DUMP_FILE.stat().st_size // 1_000_000}MB)")
        return

    print("⬇️  Downloading English Wiktionary dump (~900MB)...")
    print("   This will take 5–30 minutes depending on your connection.")
    print(f"   URL: {DUMP_URL}\n")

    def progress(block_num, block_size, total_size):
        downloaded = block_num * block_size
        pct = min(downloaded / total_size * 100, 100) if total_size > 0 else 0
        mb  = downloaded / 1_000_000
        print(f"\r   {pct:.1f}% — {mb:.0f}MB downloaded", end="", flush=True)

    urllib.request.urlretrieve(DUMP_URL, DUMP_FILE, reporthook=progress)
    print(f"\n✅ Download complete: {DUMP_FILE}")


# ── Parse helpers ─────────────────────────────────────────────────────────────
def extract_pos(wikitext: str) -> str:
    """Find the first part-of-speech section in the wikitext."""
    for line in wikitext.splitlines():
        m = re.match(r'^={2,4}(.+?)={2,4}$', line.strip())
        if m:
            header = m.group(1).strip()
            if header in POS_HEADERS:
                return header
    return "Unknown"


def extract_definition(wikitext: str) -> str:
    """Pull the first English definition line (#...)."""
    in_english = False
    for line in wikitext.splitlines():
        if re.match(r'^==English==', line):
            in_english = True
        if in_english and line.startswith("# "):
            # Strip wikitext markup from definition
            defn = line[2:].strip()
            defn = re.sub(r'\[\[([^\]|]+\|)?([^\]]+)\]\]', r'\2', defn)  # [[link|text]]
            defn = re.sub(r'\{\{[^}]+\}\}', '', defn)                     # {{templates}}
            defn = re.sub(r"'{2,3}", '', defn)                             # bold/italic
            defn = re.sub(r'\s+', ' ', defn).strip()
            if defn and len(defn) > 3:
                return defn
    return ""


def extract_example(wikitext: str) -> str:
    """Pull the first usage example (#: ...) line."""
    in_english = False
    for line in wikitext.splitlines():
        if re.match(r'^==English==', line):
            in_english = True
        if in_english and line.startswith("#: "):
            example = line[3:].strip()
            example = re.sub(r'\{\{[^}]+\}\}', '', example)
            example = re.sub(r'\[\[([^\]|]+\|)?([^\]]+)\]\]', r'\2', example)
            example = re.sub(r"'{2,3}|<[^>]+>", '', example)
            example = re.sub(r'\s+', ' ', example).strip()
            if example and len(example) > 5:
                return example
    return ""


def parse_page(title: str, wikitext: str) -> list[dict]:
    """
    Parse one Wiktionary page and return a list of word entries.
    One English word can have multiple meanings → multiple Uzbek translations.
    """
    # Skip non-English pages, meta pages, redirect pages
    if not title or ":" in title or title.startswith("#"):
        return []
    if "==English==" not in wikitext:
        return []
    if "#REDIRECT" in wikitext.upper():
        return []

    # Find all Uzbek translations on this page
    uzbek_words = UZ_PATTERN.findall(wikitext)
    if not uzbek_words:
        return []

    # Clean up Uzbek words (remove trailing annotations like |sc=Latn|g=...)
    uzbek_clean = []
    for uz in uzbek_words:
        word = uz.split("|")[0].strip()  # take only the word part
        word = re.sub(r'[^\w\s\'-]', '', word).strip()  # strip odd chars
        if word and 1 < len(word) < 50:
            uzbek_clean.append(word)

    if not uzbek_clean:
        return []

    pos     = extract_pos(wikitext)
    defn    = extract_definition(wikitext)
    example = extract_example(wikitext)

    entries = []
    seen    = set()
    for uz_word in uzbek_clean:
        key = (title.lower(), uz_word.lower())
        if key in seen:
            continue
        seen.add(key)
        entries.append({
            "english":         title.strip(),
            "uzbek":           uz_word,
            "part_of_speech":  pos,
            "definition":      defn,
            "example":         example,
            "frequency_rank":  0,   # filled later by 02_enrich.py
        })

    return entries


# ── Main parse loop ───────────────────────────────────────────────────────────
def parse_dump():
    if not DUMP_FILE.exists():
        print(f"❌ Dump file not found: {DUMP_FILE}")
        print("   Run with --download first.")
        return

    print(f"🔍 Parsing {DUMP_FILE} ...")
    print("   This takes 10–30 minutes. Progress shown every 10,000 pages.\n")

    results    = []
    page_count = 0
    hit_count  = 0
    errors     = 0

    ns = "http://www.mediawiki.org/xml/DTD/mediawiki"

    # Stream parse the bz2 file — never loads the whole file into RAM
    with bz2.open(DUMP_FILE, "rb") as f:
        context = ET.iterparse(f, events=("end",))

        title    = None
        wikitext = None

        for event, elem in context:
            tag = elem.tag.split("}")[-1]  # strip namespace

            if tag == "title":
                title = elem.text
            elif tag == "text":
                wikitext = elem.text or ""
            elif tag == "page":
                page_count += 1

                if title and wikitext:
                    try:
                        entries = parse_page(title, wikitext)
                        if entries:
                            results.extend(entries)
                            hit_count += 1
                    except Exception as e:
                        errors += 1

                # Reset for next page
                title    = None
                wikitext = None

                # Free memory — crucial for large dumps
                elem.clear()

                if page_count % 10_000 == 0:
                    print(f"   Pages: {page_count:,} | Words found: {len(results):,} | Errors: {errors}")

    print(f"\n✅ Parse complete!")
    print(f"   Total pages scanned : {page_count:,}")
    print(f"   Pages with Uzbek    : {hit_count:,}")
    print(f"   Total word pairs    : {len(results):,}")
    print(f"   Errors              : {errors}")

    # Save results
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n💾 Saved to {OUT_JSON}")
    print(f"   Next step: run  python 02_enrich.py")


# ── CLI ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Wiktionary EN→UZ parser")
    parser.add_argument("--download", action="store_true", help="Download the dump file")
    parser.add_argument("--parse",    action="store_true", help="Parse the dump file")
    parser.add_argument("--all",      action="store_true", help="Download then parse")
    args = parser.parse_args()

    if args.all or args.download:
        download_dump()
    if args.all or args.parse:
        parse_dump()
    if not any(vars(args).values()):
        parser.print_help()
