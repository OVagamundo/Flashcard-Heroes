import urllib.request
import re
import os
import zipfile

def main():
    download_key = "eyJvcCI6InNkZCIsImlhdCI6MTc3OTM5MTg2MiwianYiOjF9.AIdk9q31JoPiMBGhh4I2hWju2Ogeu9_giKnqGMM1vQkb"
    shared_id = "2092196508"
    
    url = f"https://ankiweb.net/svc/shared/download-deck/{shared_id}?t={download_key}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
        'Referer': f'https://ankiweb.net/shared/info/{shared_id}'
    }
    
    print(f"Downloading from {url}...")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            data = response.read()
            print(f"Downloaded {len(data)} bytes")
            
            # Save it
            with open("scratch/deck.apkg", "wb") as f:
                f.write(data)
            print("Saved as scratch/deck.apkg")
            
            # Unzip it
            out_dir = "scratch/extracted_deck"
            if not os.path.exists(out_dir):
                os.makedirs(out_dir)
            with zipfile.ZipFile("scratch/deck.apkg", "r") as z:
                z.extractall(out_dir)
            print(f"Extracted to {out_dir}")
            print("Files in extracted dir:", os.listdir(out_dir))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
