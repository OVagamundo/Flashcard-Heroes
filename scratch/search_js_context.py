import os
import re

scratch_dir = "scratch"
js_files = ["frontend.js", "node25.js"]

for js_file in js_files:
    path = os.path.join(scratch_dir, js_file)
    print(f"=== {js_file} ===")
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        # Search for surrounding characters (150 chars before and after) of 'item-info' and 'download'
        for term in ['item-info', 'download-deck', 'download']:
            for match in re.finditer(re.escape(term), content, re.IGNORECASE):
                start = max(0, match.start() - 100)
                end = min(len(content), match.end() + 100)
                snippet = content[start:end].replace('\n', ' ')
                print(f"  [{term}]: ... {snippet} ...")
