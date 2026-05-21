import urllib.request
import urllib.parse
import os

url = "https://ankiweb.net/svc/shared/download-deck/1158850985"
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Referer': 'https://ankiweb.net/shared/info/1158850985'
}

print("1. Trying GET on /svc/shared/download-deck/1158850985...")
try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        content = response.read()
        print(f"GET Status: {response.getcode()}")
        print(f"GET Content Length: {len(content)}")
        print(f"GET Content type: {response.info().get_content_type()}")
        if content.startswith(b"PK"):
            print("Successfully downloaded zip/apkg via GET!")
            with open("korean_deck_svc_get.apkg", "wb") as f:
                f.write(content)
        else:
            print(f"GET Snippet: {content[:200]}")
except Exception as e:
    print(f"GET Error: {e}")

print("\n2. Trying POST on /svc/shared/download-deck/1158850985...")
try:
    data = urllib.parse.urlencode({}).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req) as response:
        content = response.read()
        print(f"POST Status: {response.getcode()}")
        print(f"POST Content Length: {len(content)}")
        print(f"POST Content type: {response.info().get_content_type()}")
        if content.startswith(b"PK"):
            print("Successfully downloaded zip/apkg via POST!")
            with open("korean_deck_svc_post.apkg", "wb") as f:
                f.write(content)
        else:
            print(f"POST Snippet: {content[:200]}")
except Exception as e:
    print(f"POST Error: {e}")
