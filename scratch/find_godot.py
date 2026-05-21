import os
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

search_paths = [
    os.environ.get('USERPROFILE'),
    'C:\\Program Files',
    'C:\\Program Files (x86)',
    'c:\\Users\\danhh\\Desktop'
]

found = []
for sp in search_paths:
    if not sp:
        continue
    print(f"Searching {sp}...")
    for r, d, fs in os.walk(sp):
        # Skip noisy dirs
        if any(x in r for x in ['.git', '.godot', 'node_modules', 'AppData\\Local\\Temp', 'AppData\\Local\\Microsoft']):
            continue
        for f in fs:
            if f.lower() in ['godot.exe', 'godot_engine.exe'] or (f.lower().startswith('godot') and f.lower().endswith('.exe')):
                p = os.path.join(r, f)
                print(f"Found: {p}")
                found.append(p)
                if len(found) >= 3:
                    break
        if len(found) >= 3:
            break
