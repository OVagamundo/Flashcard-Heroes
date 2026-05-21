import urllib.request

url = "https://ankiweb.net/shared/info/1158850985/__data.json"
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        content = response.read()
        print(f"Loaded json. Length: {len(content)}")
        with open("scratch/anki_data.json", "wb") as f:
            f.write(content)
        print("Saved to scratch/anki_data.json")
except Exception as e:
    print(f"Error: {e}")
