"""
Parse Round_Up_Vocabulary_Uzbek.md and generate a Supabase SQL seed file.
Books:
- Round Up Starter (Half of R0)
- Round Up 1 (Half of R0)
- Round Up 2 (All R2)
- Round Up 3 (All R3)
- Round Up 4 (All R4)
Units: 25-30 words each.
"""
import re
import os
import math

MD_PATH = os.path.join(os.path.dirname(__file__), '..', 'Round_Up_Vocabulary_Uzbek.md')
OUT_PATH = os.path.join(os.path.dirname(__file__), 'seed_round_up.sql')

def escape_sql(s):
    return s.replace("'", "''")

def get_words_for_section(content, section_marker):
    """Finds a section like '## Round Up 0 (R0)' and extracts all its words."""
    words = []
    
    # Try to find the section block
    # Splitting by '## '
    blocks = content.split('## ')
    for block in blocks:
        if block.startswith(section_marker) or f'({section_marker})' in block:
            lines = block.strip().split('\n')
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
                if 'english' in cells[0].lower():
                    header_found = True
                    continue
                    
                # Skip separator
                if all(re.match(r'^[-:]+$', c) for c in cells):
                    continue
                    
                if not header_found or len(cells) < 2:
                    continue
                    
                eng = cells[0].strip()
                uzb = cells[1].strip()
                words.append({'word': eng, 'translation': uzb, 'pos': 'phrase'})
            break
    return words

def chunk_into_units(words):
    """
    Divide words into evenly-sized units (targeting ~27 words each)
    so that sizes perfectly stay in the 25-30 range without 
    tiny left-over remainder units.
    """
    total = len(words)
    if total == 0:
        return []
        
    # Calculate the ideal number of units to keep average size around 27
    num_units = max(1, round(total / 27.0))
    
    base_size = total // num_units
    remainder = total % num_units
    
    units = []
    start = 0
    for i in range(num_units):
        # Distribute the remainder by adding 1 extra word to the first few units
        size = base_size + 1 if i < remainder else base_size
        units.append(words[start:start + size])
        start += size
        
    return units

def parse_markdown(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    r0_words = get_words_for_section(content, 'R0')
    r2_words = get_words_for_section(content, 'R2')
    r3_words = get_words_for_section(content, 'R3')
    r4_words = get_words_for_section(content, 'R4')
    
    print(f"R0: {len(r0_words)}, R2: {len(r2_words)}, R3: {len(r3_words)}, R4: {len(r4_words)}")

    # Split R0 cleanly in half
    r0_half = len(r0_words) // 2
    r0_first_half = r0_words[:r0_half]
    r0_second_half = r0_words[r0_half:]
    
    books = [
        {'title': 'Round Up Starter', 'words': r0_first_half, 'col_id': 'c0000008-0000-4000-8000-000000000001'},
        {'title': 'Round Up 1', 'words': r0_second_half, 'col_id': 'c0000008-0001-4000-8000-000000000001'},
        {'title': 'Round Up 2', 'words': r2_words, 'col_id': 'c0000008-0002-4000-8000-000000000001'},
        {'title': 'Round Up 3', 'words': r3_words, 'col_id': 'c0000008-0003-4000-8000-000000000001'},
        {'title': 'Round Up 4', 'words': r4_words, 'col_id': 'c0000008-0004-4000-8000-000000000001'}
    ]
    
    return books

def generate_sql(books, out_path):
    with open(out_path, 'w', encoding='utf-8') as f:
        total_collections = len(books)
        f.write('-- ============================================================================\n')
        f.write('-- VocabGame — Round Up Seed Content\n')
        f.write('-- Paste this into Supabase → SQL Editor → New Query → Run\n')
        f.write(f'-- Creates {total_collections} collections (books).\n')
        f.write('-- ============================================================================\n\n')

        # Create idempotent cleanup
        c_ids = [book['col_id'] for book in books]
        c_ids_list = ", ".join(f"'{cid}'" for cid in c_ids)
        f.write('-- ─── Idempotent Cleanup (Removes old records safely before replacing) ───\n')
        f.write(f"DELETE FROM words WHERE collection_id IN ({c_ids_list});\n")
        f.write(f"DELETE FROM units WHERE collection_id IN ({c_ids_list});\n")
        f.write(f"DELETE FROM collections WHERE id IN ({c_ids_list});\n\n")

        for b_idx, book in enumerate(books):
            c_id = book['col_id']
            b_title = book['title']
            
            units = chunk_into_units(book['words'])
            total_units = len(units)
            
            f.write(f'-- ─── Collection: {b_title} ────────────────────────────────────────\n\n')
            f.write("INSERT INTO collections (id, title, short_title, description, category, difficulty, cover_emoji, cover_color, total_units, is_published)\n")
            f.write(f"VALUES ('{c_id}', '{b_title}', '{b_title}', 'Vocabulary words from {b_title}', 'esl', 'A1', '📙', '#EAB308', {total_units}, true);\n\n")

            for u_idx, unit_words in enumerate(units):
                unit_number = u_idx + 1
                u_id = f'a0000008-{b_idx:04d}-40{unit_number:02d}-8000-000000000001'
                word_count = len(unit_words)
                
                f.write(f'-- Unit {unit_number} ({word_count} words)\n')
                f.write(f"INSERT INTO units (id, collection_id, title, unit_number, word_count)\n")
                f.write(f"VALUES ('{u_id}', '{c_id}', 'Unit {unit_number}', {unit_number}, {word_count});\n\n")
                
                f.write(f"INSERT INTO words (unit_id, collection_id, word, translation, example_sentence, word_type, difficulty, word_number) VALUES\n")
                
                word_lines = []
                for w_idx, w in enumerate(unit_words, 1):
                    word_esc = escape_sql(w['word'])
                    trans_esc = escape_sql(w['translation'])
                    # Since we don't have example sentences, just use a generic one or empty
                    example_esc = ''
                    pos = w['pos']
                    
                    word_lines.append(
                        f"('{u_id}', '{c_id}', '{word_esc}', '{trans_esc}', '{example_esc}', '{pos}', 'A1', {w_idx})"
                    )
                
                f.write(',\n'.join(word_lines))
                f.write(';\n\n')

            f.write('-- ─── Update collection total_units counts ───\n')
            f.write(f"UPDATE collections SET total_units = (SELECT COUNT(*) FROM units WHERE collection_id = '{c_id}') WHERE id = '{c_id}';\n\n")

    print(f'Generated {out_path}')


if __name__ == '__main__':
    books = parse_markdown(MD_PATH)
    generate_sql(books, OUT_PATH)
