import re

with open("scratch/app.js", "r", encoding="utf-8") as f:
    js = f.read()

# Let's find where route /shared/info/[sid=integer] is defined
# We'll print 500 characters around it.
for m in re.finditer(r'/shared/info/\[sid=integer\]', js):
    start = max(0, m.start() - 300)
    end = min(len(js), m.end() + 300)
    print("MATCH CONTEXT:")
    print(js[start:end])
    print("-" * 50)
