with open('scripts/BattleAnimator.gd', 'r') as f:
    lines = f.readlines()

for i in range(374, 390):
    if lines[i].startswith('\t\t\t\t\t\t\t\t'):
        lines[i] = lines[i][1:]

with open('scripts/BattleAnimator.gd', 'w') as f:
    f.writelines(lines)
