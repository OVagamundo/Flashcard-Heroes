with open("localization/game.csv", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if "korean" in line.lower() or "hangul" in line.lower():
            print(f"Line {i+1}: {line.strip()}")
