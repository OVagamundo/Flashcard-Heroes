import re

with open("scratch/node25.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's search for "const ul" or "let ul" or "function ul" or "ul ="
print("Matches for ul:")
for m in re.finditer(r'\bul\b', js):
    start = max(0, m.start() - 100)
    end = min(len(js), m.end() + 100)
    print("MATCH:")
    print(js[start:end])
    print("-" * 50)
