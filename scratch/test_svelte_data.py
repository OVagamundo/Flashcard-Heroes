import urllib.request

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
}

urls = [
    "https://ankiweb.net/shared/info/2092196508/__data.json",
    "https://ankiweb.net/shared/info/2092196508?__data=1"
]

for url in urls:
    print(f"Fetching: {url}")
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            print("  Status:", resp.getcode())
            data = resp.read()
            print("  Length:", len(data))
            print("  Sample:", data[:200])
    except Exception as e:
        print("  Error:", e)
