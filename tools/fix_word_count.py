"""
Fix word_count in seed_content.sql: set all unit INSERT word_count values to 0.
The DB trigger (update_unit_word_count) will handle counting automatically.
"""
import re
import os

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))

def fix_sql_file(filepath):
    """Replace word_count values in unit INSERT statements with 0."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match: VALUES ('uuid', 'uuid', 'title', number, NUMBER);
    # Replace the last number (word_count) with 0
    pattern = r"(VALUES\s*\('[^']+',\s*'[^']+',\s*'[^']+',\s*\d+,\s*)\d+(\);)"
    new_content = re.sub(pattern, r'\g<1>0\2', content)

    changes = content != new_content
    if changes:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"  FIXED: {os.path.basename(filepath)}")
    else:
        print(f"  NO CHANGE: {os.path.basename(filepath)}")
    return changes

if __name__ == '__main__':
    print("Fixing word_count in seed SQL files...")
    fix_sql_file(os.path.join(TOOLS_DIR, 'seed_content.sql'))
    fix_sql_file(os.path.join(TOOLS_DIR, 'seed_navigate_a1.sql'))
    fix_sql_file(os.path.join(TOOLS_DIR, 'seed_navigate_a2.sql'))
    fix_sql_file(os.path.join(TOOLS_DIR, 'seed_round_up.sql'))
    fix_sql_file(os.path.join(TOOLS_DIR, 'seed_irregular_verbs.sql'))
    print("Done!")
