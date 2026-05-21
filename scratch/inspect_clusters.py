import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/extracted_notes.json", "r", encoding="utf-8") as f:
    notes = json.load(f)

clusters = [n for n in notes if n['model'] == 'soi.ko.d.ConsonantClusters']
for idx, c in enumerate(clusters):
    f = c['fields']
    print(f"Index {idx}: Letter={f.get('krLetter')}, Pron={f.get('batchimPron')}, Ex1={f.get('ex1')}, Ex1Pron={f.get('ex1Pron')}, EnDefn1={f.get('enDefn1')}")
