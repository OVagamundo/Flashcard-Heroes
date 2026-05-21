import urllib.request
import re

url = "https://ankiweb.net/svc/shared/item-info?sharedId=2092196508"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Referer': 'https://ankiweb.net/shared/info/2092196508'
}

req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        data = response.read()
        print(f"Response length: {len(data)}")
        
        # Save raw binary
        with open("scratch/item_info_real.bin", "wb") as f:
            f.write(data)
            
        # Search for ASCII strings of length 8-64
        # We escape the dash correctly here to avoid syntax warning
        strings = re.findall(b'[a-zA-Z0-9_\\-\\.\\~]{8,128}', data)
        print("Strings found:")
        for s in strings:
            decoded = s.decode('ascii')
            # Let's see if we can find any string that is likely the download key
            print("  ", decoded)
except Exception as e:
    print(f"Error: {e}")
