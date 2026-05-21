import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


with open("decks/korean_hangul.json", "r", encoding="utf-8") as f:
    d = json.load(f)

print("Deck keys:")
for k, v in d.items():
    if k != "cards":
        print(f"  {k}: {v}")

print("Checking cards...")
for idx, c in enumerate(d["cards"]):
    card_str = json.dumps(c)
    if "52" in card_str or "50" in card_str:
        print(f"Index {idx} (ID {c.get('id')}): {c.get('question')} | Explanation: {c.get('explanation')}")
