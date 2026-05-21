import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

consonants = [n for n in notes if n['model'] == 'soi.ko.b.ConsonantInitialsNames']
for idx, c in enumerate(consonants):
    f = c['fields']
    print(f"Index {idx}: Letter={f.get('krLetter')}, Name={f.get('name')}, InitRom={f.get('initRom')}, FinRom={f.get('finRom')}")
