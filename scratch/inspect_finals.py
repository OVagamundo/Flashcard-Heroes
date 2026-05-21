import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

finals = [n for n in notes if n['model'] == 'soi.ko.c.ConsonantFinals']
for idx, c in enumerate(finals):
    f = c['fields']
    print(f"Index {idx}: Letter={f.get('krLetter')}, Name={f.get('name')}, FinRom={f.get('finRom')}, Example={f.get('example')}, EnDefn={f.get('enDefn')}")
