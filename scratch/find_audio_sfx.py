import os

for root, dirs, files in os.walk("c:/Users/danhh/Desktop/Flashcard-Heroes/scripts"):
    for file in files:
        if file.endswith(".gd"):
            p = os.path.join(root, file)
            with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                if "pronunciation" in content or "play_sfx" in content:
                    print(f"File: {p}")
                    # print lines
                    for idx, line in enumerate(content.split('\n')):
                        if "pronunciation" in line or "play_sfx" in line:
                            print(f"  Line {idx+1}: {line.strip()}")
