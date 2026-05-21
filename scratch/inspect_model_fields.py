import json
import sys

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
    print(f"==================================================")
    print(f"Model: {model} (Count: {len(list_n)})")
    print(f"==================================================")
    for i in range(min(2, len(list_n))):
        n = list_n[i]
        print(f"Note {i+1}:")
        for k, v in n['fields'].items():
            if v.strip():
                # print first 100 characters of field value
                val_snippet = v.replace('\n', ' ')[:120]
                print(f"  {k}: {val_snippet}")
        print("-" * 30)
