import urllib.request
import re

url = "https://ankiweb.net/_app/immutable/chunks/frontend.BA434DQn.mjs"
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        
        with open("scratch/frontend.js", "w", encoding="utf-8") as f:
            f.write(content)
        print("Saved frontend.js")
        
        # Let's search for the definition of gt (which is imported as T)
        # Search for "function T(" or "const T =" or similar.
        # SvelteKit/esbuild usually exports it at the end, let's search for "export"
        # but let's search for "/svc/" or similar
        svc_matches = re.findall(r'/[a-zA-Z0-9_\-/]+', content)
        print("SVC/API paths in frontend.js:")
        for p in set(svc_matches):
            if 'svc' in p or 'api' in p or 'shared' in p:
                print("  ", p)
except Exception as e:
    print(f"Error: {e}")
