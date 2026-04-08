import json
import re
from collections import defaultdict

with open('assets/top5000_bundle.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Track the parts of speech found for each word
# We want to identify words that have BOTH 'n.' (noun) and 'v.' (verb)
# They could either be in the same entry (e.g., "part_of_speech": "n., v.")
# or across multiple entries for the same word.

word_pos_map = defaultdict(set)
word_details = defaultdict(list)

for entry in data:
    word = entry['english'].lower()
    pos_str = entry.get('part_of_speech', '')
    
    # Extract individual parts of speech, e.g., "n., v." -> ["n.", "v."]
    parts = [p.strip() for p in pos_str.replace('/', ',').split(',')]
    
    for p in parts:
        word_pos_map[word].add(p)
    
    word_details[word].append(entry)

results = []
for word, pos_set in word_pos_map.items():
    if 'n.' in pos_set and ('v.' in pos_set or 'modal v.' in pos_set):
        results.append(word)

# Output summary
print(f"Total entries analyzed: {len(data)}")
print(f"Total unique words: {len(word_pos_map)}")
print(f"Number of words that act as BOTH a noun ('n.') and a verb ('v.'): {len(results)}")

print("\n--- Here are 10 examples ---")
for word in results[:10]:
    print(f"\nWord: {word}")
    for entry in word_details[word]:
        pos = entry.get('part_of_speech', '')
        uzb = entry.get('uzbek', '')
        cefr = entry.get('cefr_level', '')
        print(f" - [{cefr}] {pos} : {uzb}")
