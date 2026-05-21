import re

with open("scratch/node25.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's search for downloadKey
print("Matches for downloadKey:")
for m in re.finditer(r'downloadKey', js):
    start = max(0, m.start() - 200)
    end = min(len(js), m.end() + 200)
    print("MATCH:")
    print(js[start:end])
    print("-" * 50)
    
# Let's also print lines containing "universal" or "load" or "data"
for m in re.finditer(r'universal', js):
    start = max(0, m.start() - 200)
    end = min(len(js), m.end() + 200)
    print("UNIVERSAL/LOAD MATCH:")
    print(js[start:end])
    print("-" * 50)
