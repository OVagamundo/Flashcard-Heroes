import re

path = "/Users/danhh/Desktop/Flashcard Heroes/scripts/BattleAnimator.gd"
with open(path, "r") as f:
    content = f.read()

# I want to see the exact code for merging
print(content[content.find("func _consolidate_consecutive_events"):content.find("func _merge_event_payloads")])
