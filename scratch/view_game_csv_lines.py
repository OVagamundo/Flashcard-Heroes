with open("localization/game.csv", "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()
    for idx in range(310, min(330, len(lines))):
        print(f"Line {idx+1}: {lines[idx].strip()}")
