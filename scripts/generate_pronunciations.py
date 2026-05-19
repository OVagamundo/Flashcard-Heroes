import os
import json
import urllib.request
import urllib.parse
import time

# Paths
DECKS_PATH = "decks"
OUTPUT_DIR = "assets/audio/sfx/pronunciation"

def main():
    print("Starting Japanese pronunciation audio generator...")
    
    # Create output directory
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created output directory: {OUTPUT_DIR}")
    
    # Load Hiragana deck to extract unique answers and their characters
    hiragana_file = os.path.join(DECKS_PATH, "hiragana.json")
    if not os.path.exists(hiragana_file):
        print(f"Error: {hiragana_file} not found. Please run this from the project root directory.")
        return
        
    with open(hiragana_file, "r", encoding="utf-8") as f:
        deck_data = json.load(f)
        
    cards = deck_data.get("cards", [])
    print(f"Found {len(cards)} cards in Hiragana deck.")
    
    # Map answer (romaji) -> question (Japanese character)
    # Using Hiragana characters since they are pronounced identically to Katakana
    pronunciation_map = {}
    for card in cards:
        romaji = card.get("answer", "").strip().lower()
        character = card.get("question", "").strip()
        if romaji and character:
            # If there's a collision (e.g. ji / zu), keep the primary one
            # HIRA_053 'じ' -> 'ji', HIRA_058 'ぢ' -> 'ji'. 'じ' is the standard 'ji'.
            # HIRA_054 'ず' -> 'zu', HIRA_059 'づ' -> 'zu'. 'ず' is the standard 'zu'.
            if romaji in pronunciation_map:
                # Keep the more common standard hiragana character
                existing_char = pronunciation_map[romaji]
                if character in ["ぢ", "づ"]:
                    # Prefer じ over ぢ, ず over づ
                    continue
            pronunciation_map[romaji] = character

    print(f"Found {len(pronunciation_map)} unique pronunciations to download.")
    
    # Download each audio file
    download_count = 0
    skipped_count = 0
    
    for romaji, char in sorted(pronunciation_map.items()):
        filename = f"{romaji}.mp3"
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        # Check if already exists
        if os.path.exists(filepath):
            skipped_count += 1
            continue
            
        # Avoid printing raw Japanese characters to prevent Windows CP1252 print encoding crashes
        print(f"Downloading pronunciation for '{romaji}'...")
        
        # Google Translate TTS URL
        url_encoded_text = urllib.parse.quote(char)
        url = f"https://translate.google.com/translate_tts?ie=UTF-8&tl=ja&client=tw-ob&q={url_encoded_text}"
        
        try:
            req = urllib.request.Request(
                url,
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
            )
            with urllib.request.urlopen(req) as response:
                with open(filepath, "wb") as out_file:
                    out_file.write(response.read())
            
            download_count += 1
            # Add a small delay to be polite and avoid rate limits
            time.sleep(0.3)
        except Exception as e:
            print(f"Error downloading '{romaji}': {e}")
            # If rate limited, sleep longer
            time.sleep(2.0)
            
    print("\nGeneration finished!")
    print(f"Total files in output: {len(os.listdir(OUTPUT_DIR))}")
    print(f"Successfully downloaded: {download_count}")
    print(f"Skipped (already exist): {skipped_count}")

if __name__ == "__main__":
    main()
