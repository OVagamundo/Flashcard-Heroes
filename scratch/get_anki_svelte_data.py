import urllib.request

urls = [
    "https://ankiweb.net/shared/info/1158850985?__data=1",
    "https://ankiweb.net/shared/info/1158850985?__data=true",
    "https://ankiweb.net/shared/info/1158850985/__data.json"
]

for url in urls:
    print(f"\nFetching: {url}")
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    )
    try:
        with urllib.request.urlopen(req) as response:
            content = response.read()
            print(f"Status: {response.getcode()}")
            print(f"Length: {len(content)}")
            print(f"Snippet: {content[:200]}")
    except Exception as e:
        print(f"Error: {e}")
