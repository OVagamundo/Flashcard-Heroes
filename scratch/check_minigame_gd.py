with open("scripts/FlashcardMinigame.gd", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if "KOR_" in line:
            print(f"Line {i+1}: {line.strip()}")
