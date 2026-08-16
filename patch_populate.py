import sys

filepath = '/Users/danhh/Desktop/Flashcard Heroes/scripts/GachaBallView.gd'
with open(filepath, 'r') as f:
    content = f.read()

old_populate = """func populate(visual_data: Dictionary, is_inspectable: bool = false, is_merging: bool = false) -> void:
	if visual_data.is_empty():
		return"""

new_populate = """func populate(visual_data: Dictionary, is_inspectable: bool = false, is_merging: bool = false) -> void:
	if visual_data.is_empty():
		return
	_has_started_vcr_stats = false"""

content = content.replace(old_populate, new_populate)

with open(filepath, 'w') as f:
    f.write(content)

print("Patch applied to GachaBallView.gd populate")
