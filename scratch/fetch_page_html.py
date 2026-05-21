import urllib.request
import re

url = "https://ankiweb.net/shared/info/1126629988"
req = urllib.request.Request(
    url,
    headers={
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
    }
)

try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        print(f"Loaded page html. Length: {len(html)}")
        
        # Save to file
        with open("scratch/anki_page_new.html", "w", encoding="utf-8") as f:
            f.write(html)
        print("Saved to scratch/anki_page_new.html")
        
        # Search for any large script blocks or JSON-like blocks
        scripts = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL)
        print(f"Found {len(scripts)} script tags:")
        for idx, s in enumerate(scripts):
            print(f"  Script {idx+1} length: {len(s)}")
            if len(s) > 100:
                print(f"    Snippet: {s[:300]}")
except Exception as e:
    print(f"Error: {e}")
