import re

with open("scratch/frontend.js", "r", encoding="utf-8") as f:
    js = f.read()

# Search for /svc/shared/item-info
for m in re.finditer(r'/svc/shared/item-info', js):
    start = max(0, m.start() - 300)
    end = min(len(js), m.end() + 1000)
    print("MATCH CONTEXT:")
    print(js[start:end])
    print("-" * 50)
