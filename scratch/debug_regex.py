import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# Let's see what is inside _animate_single_event currently:
import re
match = re.search(r'func _animate_single_event\(event: CombatEvent\) -> void:(.*?)func apply_hp_delta', content, re.DOTALL)
if match:
    print(match.group(1))
