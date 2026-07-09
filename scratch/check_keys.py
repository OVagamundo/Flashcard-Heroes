import os
import re

csv_keys = set()
with open("localization/game.csv", "r", encoding="utf-8") as f:
    for line in f:
        if line.strip() and "," in line:
            key = line.split(",")[0].strip()
            csv_keys.add(key)

abilities_dir = "resources/abilities"
for root, _, files in os.walk(abilities_dir):
    for file in files:
        if file.endswith(".tres"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                
                name_match = re.search(r'name_key\s*=\s*"([^"]+)"', content)
                desc_match = re.search(r'description_key\s*=\s*"([^"]+)"', content)
                
                if name_match:
                    name_key = name_match.group(1)
                    if name_key not in csv_keys:
                        print(f"{file} missing name_key: {name_key}")
                if desc_match:
                    desc_key = desc_match.group(1)
                    if desc_key not in csv_keys:
                        print(f"{file} missing desc_key: {desc_key}")
