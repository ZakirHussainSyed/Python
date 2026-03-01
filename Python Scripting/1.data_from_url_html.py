import pandas as pd
import urllib.request


url = "https://en.wikipedia.org/wiki/The_Simpsons"
req = urllib.request.Request(
    url,
    headers={
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    },
)

with urllib.request.urlopen(req) as resp:
    html = resp.read()

tables = pd.read_html(html)
length = len(tables)
print(length)
print(tables[1])
print(tables[1].columns)