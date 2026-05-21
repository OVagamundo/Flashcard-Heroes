import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

counts = {}
for n in notes:
    model = n['model']
    counts[model] = counts.get(model, 0) + 1

for model, count in counts.items():
    print(f"Model: {model} -> Count: {count}")
