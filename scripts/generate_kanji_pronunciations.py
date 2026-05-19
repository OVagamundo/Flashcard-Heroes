import os
import json
import urllib.request
import urllib.parse
import time

# Paths
DECKS_PATH = "decks"
OUTPUT_DIR = "assets/audio/sfx/pronunciation"

def main():
    print("Starting Japanese Kanji pronunciation audio generator...")
    
    # Create output directory
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created output directory: {OUTPUT_DIR}")
    
    # Load Kanji deck to extract card IDs and Kanji characters
    kanji_file = os.path.join(DECKS_PATH, "kanji_100.json")
    if not os.path.exists(kanji_file):
        print(f"Error: {kanji_file} not found. Please run this from the project root directory.")
        return
        
    with open(kanji_file, "r", encoding="utf-8") as f:
        deck_data = json.load(f)
        
    cards = deck_data.get("cards", [])
    print(f"Found {len(cards)} cards in Kanji deck.")
    
    # Download each audio file
    download_count = 0
    skipped_count = 0
    
    for card in cards:
        card_id = card.get("id", "").strip()
        char = card.get("question", "").strip()
        
        if not card_id or not char:
            continue
            
        filename = f"{card_id}.mp3"
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        # Check if already exists
        if os.path.exists(filepath):
            skipped_count += 1
            continue
            
        # Avoid printing raw Japanese characters to prevent Windows CP1252 print encoding crashes
        print(f"Downloading pronunciation for '{card_id}'...")
        
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
            print(f"Error downloading '{card_id}': {e}")
            # If rate limited, sleep longer
            time.sleep(2.0)
            
    print("\nKanji Generation finished!")
    print(f"Total files in output: {len(os.listdir(OUTPUT_DIR))}")
    print(f"Successfully downloaded: {download_count}")
    print(f"Skipped (already exist): {skipped_count}")

if __name__ == "__main__":
    main()
