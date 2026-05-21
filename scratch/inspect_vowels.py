import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

vowels = [n for n in notes if n['model'] == 'soi.ko.a.Vowels']
for idx, v in enumerate(vowels):
    f = v['fields']
    print(f"Index {idx}: Letter={f.get('krLetter')}, Name={f.get('name')}, Rom={f.get('rom')}, Example={f.get('example')}, EnDefn={f.get('enDefn')}")
