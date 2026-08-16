import re

with open('scripts/vfx/TokenPopVFX.gd', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'tween_interval' in line:
        line = re.sub(r'tween_interval\(([^)]+)\)', r'tween_interval(AnimationConstants.scaled(\1))', line)
    if 'tween_property' in line:
        # Match tween_property(node, prop, value, duration)
        line = re.sub(r'tween_property\(([^,]+),([^,]+),([^,]+),([^)]+)\)', r'tween_property(\1,\2,\3, AnimationConstants.scaled(\4))', line)
    if 'set_delay' in line:
        line = re.sub(r'set_delay\(([^)]+)\)', r'set_delay(AnimationConstants.scaled(\1))', line)
    new_lines.append(line)

with open('scripts/vfx/TokenPopVFX.gd', 'w') as f:
    f.writelines(new_lines)
