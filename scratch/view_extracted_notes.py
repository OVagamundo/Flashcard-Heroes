import json
import sys

# Reconfigure stdout to use UTF-8 encoding
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

# Group notes by model type
model_notes = {}
for n in notes:
    model = n['model']
    if model not in model_notes:
        model_notes[model] = []
    model_notes[model].append(n)

for model, list_n in model_notes.items():
    print(f"=== Model: {model} (Count: {len(list_n)}) ===")
    first_note = list_n[0]
    # Print the fields that have non-empty values
    non_empty = {k: v for k, v in first_note['fields'].items() if v.strip()}
    print(json.dumps(non_empty, indent=2, ensure_ascii=False))
    print("-" * 50)
