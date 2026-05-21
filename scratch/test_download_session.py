import urllib.request
import urllib.parse
import http.cookiejar
import re
import os
import zipfile

def main():
    shared_id = "2092196508"
    
    # Create cookie jar to maintain session cookies
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    
    # Common headers
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    }
    
    # Step 1: Fetch the shared info page to get initial cookies
    print(f"Step 1: Fetching shared info page for {shared_id}...")
    req = urllib.request.Request(f"https://ankiweb.net/shared/info/{shared_id}", headers=headers)
    try:
        with opener.open(req) as response:
            html = response.read().decode('utf-8')
            print(f"Loaded page html. Cookies in jar:")
            for cookie in cj:
                print(f"  {cookie.name}={cookie.value}")
    except Exception as e:
        print(f"Step 1 Error: {e}")
        return

    # Step 2: Fetch item-info API to get the download key
    print(f"\nStep 2: Fetching item-info for {shared_id}...")
    info_headers = headers.copy()
    info_headers['Referer'] = f'https://ankiweb.net/shared/info/{shared_id}'
    req = urllib.request.Request(f"https://ankiweb.net/svc/shared/item-info?sharedId={shared_id}", headers=info_headers)
    
    download_key = None
    try:
        with opener.open(req) as response:
            data = response.read()
            print(f"Item-info response length: {len(data)}")
            
            # Find the download key (JWT token) in the binary response
            match = re.search(b'eyJvcCI6InNkZCIsImlhdCI6[a-zA-Z0-9_\\-\\.\\~]+', data)
            if match:
                download_key = match.group(0).decode('ascii')
                print(f"Found download key: {download_key}")
            else:
                print("Could not find download key in response data.")
                # Print hex snippet
                print("Hex snippet of data:", data[:200].hex())
                return
    except Exception as e:
        print(f"Step 2 Error: {e}")
        return

    # Step 3: Download the deck package
    if not download_key:
        return
        
    print(f"\nStep 3: Downloading deck package from svc/shared/download-deck...")
    download_url = f"https://ankiweb.net/svc/shared/download-deck/{shared_id}?t={download_key}"
    req = urllib.request.Request(download_url, headers=info_headers)
    
    try:
        with opener.open(req) as response:
            data = response.read()
            print(f"Downloaded {len(data)} bytes")
            print(f"Headers:\n{response.info()}")
            
            # Save it
            apkg_path = "scratch/deck.apkg"
            with open(apkg_path, "wb") as f:
                f.write(data)
            print(f"Saved to {apkg_path}")
            
            # Unzip it
            out_dir = "scratch/extracted_deck"
            if not os.path.exists(out_dir):
                os.makedirs(out_dir)
            with zipfile.ZipFile(apkg_path, "r") as z:
                z.extractall(out_dir)
            print(f"Successfully extracted to {out_dir}")
            print("Files in extracted dir:", os.listdir(out_dir))
    except Exception as e:
        print(f"Step 3 Error: {e}")

if __name__ == "__main__":
    main()
