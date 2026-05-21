import urllib.request
import re

url = "https://ankiweb.net/_app/immutable/nodes/25.BvXGyFTp.mjs"
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        
        with open("scratch/node25.js", "w", encoding="utf-8") as f:
            f.write(content)
        print("Saved node25.js")
        
        # Search for any endpoints, fetch calls, or URLs
        urls = re.findall(r'https?://[^\s"\'\(\)]+|/[a-zA-Z0-9_\-/]+', content)
        print("URLs/paths found in node 25:")
        for u in set(urls):
            if any(k in u for k in ['shared', 'api', 'download', 'info', 'decks', 'query']):
                print("  ", u)
                
        # Also print lines around fetch/http/api/download references
        lines = content.split('\n')
        print("\nLines with fetch/download/http:")
        for i, line in enumerate(lines):
            if any(k in line for k in ['fetch', 'download', 'http', 'action', 'post']):
                print(f"  L{i+1}: {line[:150]}")
except Exception as e:
    print(f"Error: {e}")
