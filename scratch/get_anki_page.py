import urllib.request

url = "https://ankiweb.net/shared/info/1158850985"
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        print(f"Loaded page. Length: {len(html)}")
        # Let's save a snippet or write to file to inspect
        with open("scratch/anki_page.html", "w", encoding="utf-8") as f:
            f.write(html)
        print("Saved to scratch/anki_page.html")
except Exception as e:
    print(f"Error: {e}")
