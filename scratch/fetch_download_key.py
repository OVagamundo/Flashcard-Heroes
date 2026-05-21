import urllib.request
import re

url = "https://ankiweb.net/svc/shared/item-info?sharedId=1158850985"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Referer': 'https://ankiweb.net/shared/info/1158850985'
}

req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        data = response.read()
        print(f"Response status: {response.getcode()}")
        print(f"Response length: {len(data)}")
        
        # Save raw binary for reference
        with open("scratch/item_info_resp.bin", "wb") as f:
            f.write(data)
        print("Saved scratch/item_info_resp.bin")
        
        # Let's extract ASCII printable strings of length 8 or more
        strings = re.findall(b'[a-zA-Z0-9_\-\.\~]{8,128}', data)
        print("Possible strings in binary:")
        for s in strings:
            try:
                decoded = s.decode('ascii')
                print("  ", decoded)
            except Exception:
                pass
except Exception as e:
    print(f"Error: {e}")
