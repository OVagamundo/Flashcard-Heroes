import re

with open("scratch/node25.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's find occurrences of /svc/shared/download-deck/
for m in re.finditer(r'/svc/shared/download-deck/', js):
    start = max(0, m.start() - 500)
    end = min(len(js), m.end() + 1000)
    print("FOUND CONTEXT:")
    print(js[start:end])
    print("-" * 50)
