"""
Parse Irregular_Verbs_Uzbek.md and generate a Supabase SQL seed file.
Since there are no units defined, we will put all verbs into a single Unit 1.
"""
import re
import os

MD_PATH = os.path.join(os.path.dirname(__file__), '..', 'Irregular_Verbs_Uzbek.md')
OUT_PATH = os.path.join(os.path.dirname(__file__), 'seed_irregular_verbs.sql')

COLLECTION_ID = 'c0000007-0001-4000-8000-000000000001'
UNIT_ID = 'a0000007-0001-4000-8000-000000000001'

def escape_sql(s):
    return s.replace("'", "''")

def parse_markdown(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    words = []
    lines = content.strip().split('\n')
    
    header_found = False
    
    for line in lines:
        line = line.strip()
        if not line.startswith('|'):
            continue
            
        cells = [c.strip() for c in line.split('|')]
        cells = [c for c in cells if c != '']
        if not cells:
            continue
            
        # Detect header
        if 'v1' in cells[0].lower() or 'present simple' in cells[0].lower():
            header_found = True
            continue
            
        # Skip separator
        if all(re.match(r'^[-:]+$', c) for c in cells):
            continue
            
        if not header_found or len(cells) < 4:
            continue
            
        v1 = cells[0].strip()
        
        # Clean up asterisk (like Lie*)
        v1 = v1.replace('*', '')
        
        v2 = cells[1].strip()
        v3 = cells[2].strip()
        
        # Clean up pronunciation guides in brackets if present (e.g. read [red])
        v2 = re.sub(r'\[.*?\]', '', v2).strip()
        v3 = re.sub(r'\[.*?\]', '', v3).strip()
        
        translation = cells[3].strip()
        
        # For example sentence, combine the 3 forms
        example = f"Forms: {v1} - {v2} - {v3}"
        
        words.append({
            'word': v1.lower(),
            'pos': 'verb',
            'translation': translation,
            'example': example,
        })
            
    return words

def generate_sql(words, out_path):
    with open(out_path, 'w', encoding='utf-8') as f:
        total_words = len(words)
        f.write('-- ============================================================================\n')
        f.write('-- VocabGame — Irregular Verbs Seed Content\n')
        f.write('-- Paste this into Supabase → SQL Editor → New Query → Run\n')
        f.write(f'-- Creates 1 collection with 1 unit ({total_words} words total)\n')
        f.write('-- ============================================================================\n\n')

        f.write('-- ─── Collection: Irregular Verbs ────────────────────────────────────────\n\n')
        f.write("INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)\n")
        f.write(f"VALUES ('{COLLECTION_ID}', 'Irregular Verbs', 'Irregular Verbs', 'A complete reference of vital English irregular verbs with their forms and Uzbek translations', 'esl', 'A2', '🔁', '#EC4899', 1, true);\n\n")

        f.write(f'-- Unit 1 ({total_words} words)\n')
        f.write(f"INSERT INTO units (id, collection_id, title, unit_number, word_count)\n")
        f.write(f"VALUES ('{UNIT_ID}', '{COLLECTION_ID}', 'All Irregular Verbs', 1, {total_words});\n\n")
        
        f.write(f"INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES\n")
        
        word_lines = []
        for idx, w in enumerate(words, 1):
            word_esc = escape_sql(w['word'])
            trans_esc = escape_sql(w['translation'])
            example_esc = escape_sql(w['example'])
            pos = w['pos']
            
            word_lines.append(
                f"('{UNIT_ID}', '{COLLECTION_ID}', '{word_esc}', '{trans_esc}', '{example_esc}', '{pos}', 'A2', {idx})"
            )
        
        f.write(',\n'.join(word_lines))
        f.write(';\n\n')

        f.write('-- ─── Update collection total_units counts ──────────────────────────────\n')
        f.write(f"UPDATE collections SET total_units = (SELECT COUNT(*) FROM units WHERE collection_id = '{COLLECTION_ID}') WHERE id = '{COLLECTION_ID}';\n")

    print(f'Generated {out_path}')
    print(f'  1 unit')
    print(f'  {total_words} total words')


if __name__ == '__main__':
    words = parse_markdown(MD_PATH)
    generate_sql(words, OUT_PATH)
