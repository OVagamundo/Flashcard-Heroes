import re

main_path = 'C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/SignalBus.gd'
with open(main_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the duplicate block
bad_block = '''# Black Market signals
signal black_market_remove_zone_activated
signal black_market_transform_zone_activated

# Reward Scene signals
signal reward_collect_zone_activated
signal reward_sell_zone_activated

signal black_market_transform_zone_activated
'''

# The previous replace duplicated things, let's just use regex to clean it
# Find all occurrences of signal black_market_transform_zone_activated
occurrences = [m.start() for m in re.finditer(r'signal black_market_transform_zone_activated', content)]
if len(occurrences) > 1:
    # Remove the second occurrence
    last_idx = occurrences[-1]
    end_of_line = content.find('\n', last_idx)
    content = content[:last_idx] + content[end_of_line+1:]

with open(main_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed SignalBus')
