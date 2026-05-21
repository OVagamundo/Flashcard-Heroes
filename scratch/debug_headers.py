import urllib.request
import http.cookiejar

shared_id = "2092196508"
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
}

print("--- Step 1: Fetching Info Page ---")
req1 = urllib.request.Request(f"https://ankiweb.net/shared/info/{shared_id}", headers=headers)
try:
    with opener.open(req1) as resp1:
        print("Status:", resp1.getcode())
        print("Headers:")
        for k, v in resp1.info().items():
            print(f"  {k}: {v}")
except Exception as e:
    print("Error:", e)

print("\n--- Cookies in Jar ---")
for cookie in cj:
    print(f"  {cookie.name}={cookie.value}")

print("\n--- Step 2: Fetching Item Info ---")
info_headers = headers.copy()
info_headers['Referer'] = f'https://ankiweb.net/shared/info/{shared_id}'
info_headers['Accept'] = '*/*'
req2 = urllib.request.Request(f"https://ankiweb.net/svc/shared/item-info?sharedId={shared_id}", headers=info_headers)
try:
    with opener.open(req2) as resp2:
        print("Status:", resp2.getcode())
        print("Headers:")
        for k, v in resp2.info().items():
            print(f"  {k}: {v}")
        data2 = resp2.read()
        import re
        match = re.search(b'eyJvcCI6InNkZCIsImlhdCI6[a-zA-Z0-9_\\-\\.\\~]+', data2)
        if match:
            download_key = match.group(0).decode('ascii')
            print("Found download key:", download_key)
            
            print("\n--- Step 3: Downloading ---")
            download_url = f"https://ankiweb.net/svc/shared/download-deck/{shared_id}?t={download_key}"
            req3 = urllib.request.Request(download_url, headers=info_headers)
            try:
                with opener.open(req3) as resp3:
                    print("Status:", resp3.getcode())
            except urllib.error.HTTPError as he:
                print("HTTPError Status:", he.code)
                print("Headers:")
                for k, v in he.info().items():
                    print(f"  {k}: {v}")
                print("Body:")
                print(he.read().decode('utf-8', errors='replace'))
except Exception as e:
    print("Error:", e)
