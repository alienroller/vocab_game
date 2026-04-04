"""
Parse A1_Wordlist_All Units.md and generate a Supabase SQL seed file for Navigate A1.
Handles variable table formats (main vocab with 5 cols, supplementary with 3-4 cols).
"""
import re
import os

MD_PATH = os.path.join(os.path.dirname(__file__), '..', 'A1_Wordlist_All Units.md')
OUT_PATH = os.path.join(os.path.dirname(__file__), 'seed_navigate_a1.sql')

COLLECTION_ID = 'c0000006-0001-4000-8000-000000000001'

# Map abbreviations to DB word_type
POS_MAP = {
    'adj': 'adjective',
    'adv': 'adverb',
    'conj': 'phrase',
    'det': 'phrase',
    'exclamation': 'phrase',
    'n': 'noun',
    'n pl': 'noun',
    'pl': 'noun',
    'phr': 'phrase',
    'phr v': 'phrase',
    'phr, pl': 'phrase',
    'prep': 'phrase',
    'pron': 'noun',
    'pron, pl': 'noun',
    'v': 'verb',
    '—': 'phrase',
    '': 'phrase',
}

def escape_sql(s):
    return s.replace("'", "''")

def clean_example(raw):
    """Extract just the English part of the example sentence."""
    if not raw:
        return ''
    # Remove the Uzbek part after the em dash
    parts = raw.split('—')
    eng = parts[0].strip()
    # Remove trailing punctuation artifacts
    eng = eng.rstrip(' —-')
    return eng.strip()

def parse_markdown(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    units = []
    # Split by UNIT headers (# UNIT N)
    unit_blocks = re.split(r'^#\s+UNIT\s+(\d+)\s*$', content, flags=re.MULTILINE)

    i = 1
    while i < len(unit_blocks):
        unit_num = int(unit_blocks[i])
        unit_content = unit_blocks[i + 1]
        
        words = []
        
        # Parse all tables in this unit
        # Split into sections by ## headers
        sections = re.split(r'^##\s+(.+)$', unit_content, flags=re.MULTILINE)
        
        # sections: ['pre', 'Section Title 1', 'section1 content', 'Section Title 2', ...]
        j = 1
        while j < len(sections):
            section_title = sections[j].strip()
            section_content = sections[j + 1] if j + 1 < len(sections) else ''
            
            lines = section_content.strip().split('\n')
            
            # Find table rows
            table_rows = []
            header_row = None
            for line in lines:
                line = line.strip()
                if not line.startswith('|'):
                    continue
                cells = [c.strip() for c in line.split('|')]
                cells = [c for c in cells if c != '']
                if not cells:
                    continue
                # Skip separator rows
                if all(re.match(r'^[-:]+$', c) for c in cells):
                    continue
                if header_row is None:
                    header_row = cells
                    continue
                table_rows.append(cells)
            
            if not header_row or not table_rows:
                j += 2
                continue
            
            num_cols = len(header_row)
            
            # Determine table type by headers and section title
            header_lower = [h.lower() for h in header_row]
            section_lower = section_title.lower()
            
            if num_cols >= 5 and 'example sentence' in ' '.join(header_lower):
                # Main vocabulary table: Word | POS | Pronunciation | Uzbek | Example
                for row in table_rows:
                    if len(row) >= 5:
                        word = row[0].strip()
                        pos_raw = row[1].strip()
                        translation = row[3].strip()
                        example = clean_example(row[4].strip())
                        pos = POS_MAP.get(pos_raw, 'phrase')
                        words.append({
                            'word': word,
                            'pos': pos,
                            'translation': translation,
                            'example': example if example else f'This is an example with {word}.',
                        })
                    elif len(row) >= 4:
                        word = row[0].strip()
                        pos_raw = row[1].strip()
                        translation = row[3].strip() if len(row) > 3 else row[2].strip()
                        pos = POS_MAP.get(pos_raw, 'phrase')
                        words.append({
                            'word': word,
                            'pos': pos,
                            'translation': translation,
                            'example': f'This is an example with {word}.',
                        })
            
            else:
                # Supplementary tables: Numbers, Countries, Days, Months, Ordinals
                # Detect type using section title
                is_country = 'countr' in section_lower or 'mamlakat' in section_lower
                is_month = 'month' in section_lower or 'oylar' in section_lower
                is_day = 'day' in section_lower or 'hafta' in section_lower
                
                for row in table_rows:
                    if len(row) < 3:
                        continue
                    # Figure out which column is the word and translation
                    if num_cols == 4:
                        # Number | Word | Pronunciation | Uzbek
                        word = row[1].strip()
                        translation = row[3].strip()
                    else:
                        # Word/Country/Month | Pronunciation | Uzbek
                        word = row[0].strip()
                        translation = row[2].strip()
                    
                    # Choose contextual example sentence
                    if is_country:
                        example = f'{word} is a country in the world.'
                    elif is_month:
                        example = f'{word} is a month of the year.'
                    elif is_day:
                        example = f'I like {word} because it is a nice day.'
                    else:
                        example = f'Can you say {word} in English?'
                    
                    words.append({
                        'word': word,
                        'pos': 'noun',
                        'translation': translation,
                        'example': example,
                    })
            
            j += 2
        
        if words:
            units.append({
                'unit_number': unit_num,
                'title': f'Unit {unit_num}',
                'words': words,
            })
        i += 2
    
    return units

def generate_sql(units, out_path):
    with open(out_path, 'w', encoding='utf-8') as f:
        total_words = sum(len(u['words']) for u in units)
        f.write('-- ============================================================================\n')
        f.write('-- VocabGame — Navigate A1 Seed Content\n')
        f.write('-- Paste this into Supabase → SQL Editor → New Query → Run\n')
        f.write(f'-- Creates 1 collection with {len(units)} units ({total_words} words total)\n')
        f.write('-- ============================================================================\n\n')

        f.write('-- ─── Collection: Navigate A1 ──────────────────────────────────────────\n\n')
        f.write("INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)\n")
        f.write(f"VALUES ('{COLLECTION_ID}', 'Navigate A1', 'Navigate A1', 'A1-level vocabulary from the Navigate coursebook with Uzbek translations', 'esl', 'A1', '📗', '#22C55E', {len(units)}, true);\n\n")

        for unit in units:
            un = unit['unit_number']
            unit_id = f'a0000006-{un:04d}-4000-8000-000000000001'
            word_count = len(unit['words'])
            
            f.write(f'-- Unit {un} ({word_count} words)\n')
            f.write(f"INSERT INTO units (id, collection_id, title, unit_number, word_count)\n")
            f.write(f"VALUES ('{unit_id}', '{COLLECTION_ID}', '{escape_sql(unit['title'])}', {un}, {word_count});\n\n")
            
            f.write(f"INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES\n")
            
            word_lines = []
            for idx, w in enumerate(unit['words'], 1):
                word_esc = escape_sql(w['word'])
                trans_esc = escape_sql(w['translation'])
                example_esc = escape_sql(w['example'])
                pos = w['pos']
                
                word_lines.append(
                    f"('{unit_id}', '{COLLECTION_ID}', '{word_esc}', '{trans_esc}', '{example_esc}', '{pos}', 'A1', {idx})"
                )
            
            f.write(',\n'.join(word_lines))
            f.write(';\n\n')

        f.write('-- ─── Update collection total_units counts ──────────────────────────────\n')
        f.write(f"UPDATE collections SET total_units = (SELECT COUNT(*) FROM units WHERE collection_id = '{COLLECTION_ID}') WHERE id = '{COLLECTION_ID}';\n")

    print(f'Generated {out_path}')
    print(f'  {len(units)} units')
    print(f'  {total_words} total words')
    for u in units:
        print(f'  Unit {u["unit_number"]}: {len(u["words"])} words')


if __name__ == '__main__':
    units = parse_markdown(MD_PATH)
    generate_sql(units, OUT_PATH)
