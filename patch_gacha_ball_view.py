import sys

filepath = '/Users/danhh/Desktop/Flashcard Heroes/scripts/GachaBallView.gd'
with open(filepath, 'r') as f:
    content = f.read()

# Add _has_started_vcr_stats variable
if "var _has_started_vcr_stats: bool = false" not in content:
    content = content.replace(
        "var _visual_hp: int = 0",
        "var _visual_hp: int = 0\nvar _has_started_vcr_stats: bool = false"
    )

# Modify update_visuals
old_hp_pwr = """	_visual_hp = visual_data.get("hp", 0)
	_visual_pwr = visual_data.get("pwr", 0)"""

new_hp_pwr = """	var initial_hp = visual_data.get("initial_spawn_hp", -1)
	if initial_hp != -1 and not _has_started_vcr_stats:
		pass # Do not overwrite _visual_hp yet, wait for VCR to animate from the base
	else:
		_visual_hp = visual_data.get("hp", _visual_hp)
		
	var initial_pwr = visual_data.get("initial_spawn_pwr", -1)
	if initial_pwr != -1 and not _has_started_vcr_stats:
		pass
	else:
		_visual_pwr = visual_data.get("pwr", _visual_pwr)"""

content = content.replace(old_hp_pwr, new_hp_pwr)

# Modify animate_stat_change
old_animate = """func animate_stat_change(target_val: int, _delta: int, type: String) -> void:"""
new_animate = """func animate_stat_change(target_val: int, _delta: int, type: String) -> void:
	_has_started_vcr_stats = true"""

content = content.replace(old_animate, new_animate)

with open(filepath, 'w') as f:
    f.write(content)

print("Patch applied to GachaBallView.gd")
