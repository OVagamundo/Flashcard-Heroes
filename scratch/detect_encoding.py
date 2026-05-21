for enc in ['utf-8', 'cp1252', 'iso-8859-1']:
    try:
        with open("localization/game.csv", "r", encoding=enc) as f:
            content = f.read()
        print(f"Success reading with {enc}")
        # Print lines containing "pron" to see how they look
        for line in content.split('\n'):
            if "deck.korean_hangul.desc" in line:
                print(f"  Line: {line.strip()}")
    except UnicodeDecodeError:
        print(f"Failed to decode with {enc}")
