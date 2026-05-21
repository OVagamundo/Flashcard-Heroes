import urllib.request

urls = [
    "https://ankiweb.net/shared/info/1158850985",
    "https://ankiweb.net/shared/download/1158850985"
]

for url in urls:
    print(f"\nChecking URL: {url}")
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    )
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Status Code: {response.getcode()}")
            print(f"Final URL: {response.geturl()}")
            print("Headers:")
            for k, v in response.info().items():
                print(f"  {k}: {v}")
    except Exception as e:
        print(f"Error checking {url}: {e}")
