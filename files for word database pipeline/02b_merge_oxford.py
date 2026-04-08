import csv
import json
import re

def clean_for_lookup(w):
    # Remove text in parentheses, e.g. "bank (money)" -> "bank "
    w = re.sub(r'\(.*?\)', '', w)
    # If comma-separated, take the first word. e.g. "a, an" -> "a"
    w = w.split(',')[0]
    # Clean up any trailing/leading whitespace and lowercase
    return w.strip().lower()

def main():
    json_path = 'c:/Users/99899/VocabGame/vocab_game/files for word database pipeline/uzbek_words_clean.json'
    csv_path = 'c:/Users/99899/VocabGame/vocab_game/oxford_4897_uzbek.csv'
    out_path = 'c:/Users/99899/VocabGame/vocab_game/files for word database pipeline/oxford_enriched.json'
    
    print("Loading Wiktionary JSON...")
    with open(json_path, 'r', encoding='utf-8') as f:
        json_data = json.load(f)
        
    # Create lookup table from JSON
    # JSON is already frequency sorted, so the first match per word is the most common definition
    lookup = {}
    for entry in json_data:
        eng = entry.get('english', '').lower().strip()
        if eng not in lookup:
            lookup[eng] = entry
            
    enriched = []
    
    print("Merging with Oxford CSV...")
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            original_word = row['word'].strip()
            pos = row['pos'].strip()
            cefr = row['cefr_level'].strip()
            uzbek = row['uzbek_translation'].strip()
            
            search_word = clean_for_lookup(original_word)
            
            definition = ""
            example = ""
            freq_rank = 999999
            
            match = lookup.get(search_word)
            if match:
                definition = match.get('definition', '')
                example = match.get('example', '')
                freq_rank = match.get('frequency_rank', 999999)
                
            entry = {
                "english": original_word,
                "uzbek": uzbek,
                "part_of_speech": pos,
                "cefr_level": cefr,
                "definition": definition,
                "example": example,
                "frequency_rank": freq_rank
            }
            enriched.append(entry)
            
    # Sort enriched by frequency rank so the top words appear first
    enriched.sort(key=lambda x: x['frequency_rank'])
            
    print("Saving enriched dictionary...")
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(enriched, f, indent=2, ensure_ascii=False)
        
    print(f"Successfully built super-dictionary with {len(enriched)} words!")
    print(f"Output saved to: {out_path}")

if __name__ == "__main__":
    main()
