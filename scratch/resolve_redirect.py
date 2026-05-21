import urllib.request

url = "https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFR9ZaJwaoK70qtPpfPVsgzHGZC3CEC0zltKlLiH4UfvjtaPqjNRWt386ydsZJtoCqeIll3l1hSwFFRH4MHcnxpgcwhvVbGaRcE3vHQwCVD-9qGZNVfTScjN2u3aZu0XXdI5FFMPA=="
req = urllib.request.Request(
    url,
    headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
)

try:
    with urllib.request.urlopen(req) as response:
        print("Status Code:", response.getcode())
        print("Final URL:", response.geturl())
except Exception as e:
    print("Error:", e)
