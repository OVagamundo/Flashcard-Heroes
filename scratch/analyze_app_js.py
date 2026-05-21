import urllib.request
import re

url = "https://ankiweb.net/_app/immutable/entry/app.CqXcrSxO.mjs"
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        
        # Save to file
        with open("scratch/app.js", "w", encoding="utf-8") as f:
            f.write(content)
        print("Saved app.js")
        
        # Find any relative paths starting with /_app/ or _app/
        paths = re.findall(r'_app/immutable/[a-zA-Z0-9_\-/]+\.[a-z0-9]+', content)
        print(f"Found paths: {set(paths)}")
except Exception as e:
    print(f"Error: {e}")
