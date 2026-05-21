import urllib.request
import urllib.error
import re

shared_id = "2092196508"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Referer': f'https://ankiweb.net/shared/info/{shared_id}'
}

# First get the key
url_info = f"https://ankiweb.net/svc/shared/item-info?sharedId={shared_id}"
try:
    req = urllib.request.Request(url_info, headers=headers)
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
        match = re.search(b'eyJvcCI6InNkZCIsImlhdCI6[a-zA-Z0-9_\\-\\.\\~]+', data)
        if match:
            download_key = match.group(0).decode('ascii')
            print("Found download key:", download_key)
            
            # Now download and debug error
            download_url = f"https://ankiweb.net/svc/shared/download-deck/{shared_id}?t={download_key}"
            print("Downloading from:", download_url)
            req_dl = urllib.request.Request(download_url, headers=headers)
            try:
                with urllib.request.urlopen(req_dl) as resp_dl:
                    print("Status:", resp_dl.getcode())
                    print("Success! First 100 bytes:", resp_dl.read()[:100])
            except urllib.error.HTTPError as he:
                print("HTTPError Status:", he.code)
                print("HTTPError Body:")
                try:
                    body = he.read()
                    print(body.decode('utf-8'))
                except Exception as ex:
                    print("Could not read body:", ex)
        else:
            print("Could not find key")
except Exception as e:
    print("Error:", e)
