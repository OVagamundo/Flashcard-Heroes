import os
import re

scratch_dir = "scratch"
js_files = [f for f in os.listdir(scratch_dir) if f.endswith(".js")]

pattern = re.compile(r'/[a-zA-Z0-9_\-\.\/]+', re.IGNORECASE)

for js_file in js_files:
    path = os.path.join(scratch_dir, js_file)
    print(f"=== {js_file} ===")
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        # Find all occurrences of "svc/"
        svcs = re.findall(r'/[a-zA-Z0-9_\-\/]*/svc/[a-zA-Z0-9_\-\/]*', content)
        if svcs:
            print("  Found svc paths:", set(svcs))
        # Find fetch calls
        fetches = re.findall(r'fetch\([^)]*\)', content)
        if fetches:
            print("  Found fetch calls:", len(fetches))
            for fetch in fetches[:10]:
                print("    ", fetch)
