import json
import sys

# Ensure UTF-8 printing on Windows
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

with open("decks/korean_hangul.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"Deck display name: {data.get('display_name')}")
cards = data.get("cards", [])
print(f"Total cards: {len(cards)}")
for i, card in enumerate(cards):
    q = card.get('question', '')
    a = card.get('answer', '')
    cid = card.get('id', '')
    # Safely print representation
    print(f"{i+1:03d}: ID={cid} Q={repr(q)} A={repr(a)}")
