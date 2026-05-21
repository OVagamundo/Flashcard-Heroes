import urllib.request
import urllib.parse
import os

def download_deck():
    url = "https://ankiweb.net/shared/download/1158850985"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
        'Referer': 'https://ankiweb.net/shared/info/1158850985'
    }
    
    # Empty POST payload
    data = urllib.parse.urlencode({}).encode('utf-8')
    
    print(f"Downloading POST from {url}...")
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(req) as response:
            content_type = response.info().get_content_type()
            print(f"Content Type: {content_type}")
            print(f"Headers:\n{response.info()}")
            
            data_bytes = response.read()
            print(f"Downloaded {len(data_bytes)} bytes")
            
            if data_bytes.startswith(b"PK"):
                print("Successfully downloaded zip/apkg file!")
                with open("korean_deck.apkg", "wb") as f:
                    f.write(data_bytes)
                print("Saved as korean_deck.apkg")
            else:
                print("File doesn't start with PK. First 100 bytes:")
                print(data_bytes[:100])
    except Exception as e:
        print(f"Error during download: {e}")

if __name__ == "__main__":
    download_deck()
