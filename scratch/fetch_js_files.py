import urllib.request
import re

js_files = [
    "https://ankiweb.net/_app/immutable/entry/start.CqagM3cW.mjs",
    "https://ankiweb.net/_app/immutable/entry/app.CqXcrSxO.mjs"
]

for url in js_files:
    print(f"\nFetching JS: {url}")
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    )
    try:
        with urllib.request.urlopen(req) as response:
            content = response.read().decode('utf-8')
            print(f"Length: {len(content)}")
            
            # Let's search for some patterns: API URLs or fetch calls
            matches = re.findall(r'/[a-zA-Z0-9_\-/]+', content)
            api_paths = set()
            for m in matches:
                if 'shared' in m or 'api' in m or 'download' in m:
                    api_paths.add(m)
            print("API/Shared-like paths found:")
            for p in sorted(api_paths)[:30]:
                print("  ", p)
                
            # Search for "fetch" or "axios" or "get" calls
            for m in re.finditer(r'fetch\([^\)]+\)', content):
                print("  fetch call:", m.group(0))
    except Exception as e:
        print(f"Error: {e}")
