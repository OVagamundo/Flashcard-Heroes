import sys
import os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

for r, d, fs in os.walk('.'):
    if any(x in r for x in ['.git', '.godot', '.agent']):
        continue
    for f in fs:
        if f.endswith('.json') or f.endswith('.gd') or f.endswith('.csv') or f.endswith('.md') or f.endswith('.tres') or f.endswith('.tscn'):
            path = os.path.join(r, f)
            try:
                content = open(path, 'r', encoding='utf-8', errors='ignore').read()
                if any(str(num) in content for num in range(48, 56)) and ('korean' in content.lower() or 'hangul' in content.lower()):
                    print(f'{path} contains matching pattern')
            except Exception:
                pass
