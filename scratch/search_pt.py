import re

with open("scratch/frontend.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's search for "gt ="
# (We need to be careful as gt might be a common substring, so search with word boundaries or \bgt\s*=)
for m in re.finditer(r'\bgt\s*=\s*', js):
    start = max(0, m.start() - 100)
    end = min(len(js), m.end() + 1000)
    print("MATCH gt:")
    print(js[start:end])
    print("-" * 50)
