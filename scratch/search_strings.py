import re

with open("scratch/app.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's print any word ending in .mjs or .js or containing /nodes/
print("Nodes or components:")
for m in re.finditer(r'[^"\']+\.(?:mjs|js)[^"\']*', js):
    print("  ", repr(m.group(0)))

# Let's find any import() statements
print("\nDynamic imports:")
for m in re.finditer(r'import\([^\)]+\)', js):
    print("  ", repr(m.group(0)))
