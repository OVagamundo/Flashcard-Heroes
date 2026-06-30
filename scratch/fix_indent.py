with open('scripts/BattleAnimator.gd', 'r') as f:
    lines = f.read().split('\n')

in_func = False
for i, line in enumerate(lines):
    if line.startswith('func _build_visual_registry('):
        in_func = True
        continue
    if in_func:
        if line.startswith('func '):
            in_func = False
            continue
        if len(line) > 0 and not line.startswith('\t'):
            lines[i] = '\t' + line

with open('scripts/BattleAnimator.gd', 'w') as f:
    f.write('\n'.join(lines))
