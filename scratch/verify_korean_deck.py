import json
import os
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def main():
    print("--- STARTING OFFLINE PYTHON VERIFICATION ---")
    
    # 1. Check localization
    csv_path = "localization/game.csv"
    if not os.path.exists(csv_path):
        print(f"FAILURE: Localization file {csv_path} not found.")
        sys.exit(1)
        
    has_loc = False
    with open(csv_path, "r", encoding="iso-8859-1") as f:
        for line in f:
            if "deck.korean_hangul.desc" in line:
                has_loc = True
                print(f"SUCCESS: Found localization key in game.csv: {line.strip()}")
                break
                
    if not has_loc:
        print("FAILURE: Localization key 'deck.korean_hangul.desc' not found in game.csv.")
        sys.exit(1)

    # 2. Check JSON deck definition
    deck_path = "decks/korean_hangul.json"
    if not os.path.exists(deck_path):
        print(f"FAILURE: Deck file {deck_path} not found.")
        sys.exit(1)
        
    try:
        with open(deck_path, "r", encoding="utf-8") as f:
            deck = json.load(f)
    except Exception as e:
        print(f"FAILURE: Could not parse JSON in {deck_path}: {e}")
        sys.exit(1)
        
    cards = deck.get("cards", [])
    print(f"SUCCESS: Parsed deck file. Card count: {len(cards)}")
    
    if len(cards) != 103:
        print(f"FAILURE: Expected exactly 103 cards, but found {len(cards)}")
        sys.exit(1)
        
    # 3. Verify each card
    missing_audio = 0
    bad_cards = 0
    audio_dir = "assets/audio/sfx/pronunciation"
    
    for idx, card in enumerate(cards):
        c_id = card.get("id")
        q = card.get("question")
        a = card.get("answer")
        exp = card.get("explanation")
        exp_pt = card.get("explanation_pt")
        tts = card.get("tts_query")
        
        # Check basic fields
        if not c_id or not q or not a or not exp or not exp_pt or not tts:
            print(f"FAILURE: Card at index {idx} has missing fields: {card}")
            bad_cards += 1
            continue
            
        # Check ID format
        expected_id = f"KOR_{idx+1:03d}"
        if c_id != expected_id:
            print(f"FAILURE: Card at index {idx} has ID {c_id}, expected {expected_id}")
            bad_cards += 1
            
        # Check audio file
        audio_path = os.path.join(audio_dir, f"{c_id}.mp3")
        if not os.path.exists(audio_path):
            print(f"FAILURE: Missing audio file for {c_id} at {audio_path}")
            missing_audio += 1
            
    if bad_cards > 0 or missing_audio > 0:
        print(f"VERIFICATION FAILED: {bad_cards} malformed cards, {missing_audio} missing audio files.")
        sys.exit(1)
        
    print("SUCCESS: All 103 cards are well-formed and have unique KOR_XXX IDs.")
    print(f"SUCCESS: All 103 pronunciation audio files exist in {audio_dir}.")
    print("--- VERIFICATION SUCCEEDED ---")
    sys.exit(0)

if __name__ == "__main__":
    main()
