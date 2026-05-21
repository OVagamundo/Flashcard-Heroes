import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

rules = [n for n in notes if n['model'] == 'soi.ko.e.PronunciationChanges']
for idx, r in enumerate(rules):
    f = r['fields']
    print(f"Index {idx}: RuleName={f.get('RuleName')}, Ex1={f.get('ex1')}, Pron1={f.get('pron1')}, En1={f.get('en1')}")
