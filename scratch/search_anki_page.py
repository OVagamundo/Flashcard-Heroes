import re

with open("scratch/anki_page.html", "r", encoding="utf-8") as f:
    html = f.read()

print("HTML length:", len(html))

# Let's find any occurrences of 'download' or '1158850985' or 'apkg'
print("\nMatches for 'download':")
for m in re.finditer(r'.{0,30}download.{0,30}', html, re.IGNORECASE):
    print("  ", repr(m.group(0)))

print("\nMatches for '1158850985':")
for m in re.finditer(r'.{0,30}1158850985.{0,30}', html):
    print("  ", repr(m.group(0)))

print("\nMatches for 'apkg':")
for m in re.finditer(r'.{0,30}apkg.{0,30}', html, re.IGNORECASE):
    print("  ", repr(m.group(0)))

print("\nMatches for 'href=' or 'src=':")
for m in re.finditer(r'(href|src)=["\'][^"\']+["\']', html):
    print("  ", repr(m.group(0)))
