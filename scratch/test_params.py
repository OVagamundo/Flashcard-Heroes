import urllib.request

params = [
    "sharedId=1158850985",
    "shared_id=1158850985",
    "sid=1158850985",
    "id=1158850985"
]

for p in params:
    url = f"https://ankiweb.net/svc/shared/item-info?{p}"
    req = urllib.request.Request(
        url,
        headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
            'Referer': 'https://ankiweb.net/shared/info/1158850985'
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            data = response.read()
            print(f"Param: {p} -> Status: {response.getcode()}, Length: {len(data)}, Hex: {data.hex()}")
    except Exception as e:
        print(f"Param: {p} -> Error: {e}")
