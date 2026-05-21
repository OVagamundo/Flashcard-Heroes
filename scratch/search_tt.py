import re

with open("scratch/frontend.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's search for "Tt ="
for m in re.finditer(r'\bTt\s*=\s*', js):
    start = max(0, m.start() - 100)
    end = min(len(js), m.end() + 500)
    print("MATCH Tt:")
    print(js[start:end])
    print("-" * 50)
    
# Let's search for "function K(" or similar helper functions
for m in re.finditer(r'function K\(', js):
    start = max(0, m.start() - 100)
    end = min(len(js), m.end() + 1000)
    print("MATCH K:")
    print(js[start:end])
    print("-" * 50)
