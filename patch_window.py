import re

with open("scripts/WindowManager.gd", "r") as f:
    content = f.read()

replacement = """	if has_tooltip:
		has_tooltip = GlobalInteractionRouter.is_inspection_locked()
	
	print("[DEBUG] _update_tree_pause_state called! has_tooltip=", has_tooltip, " _active_inspection_group.size=", _active_inspection_group.size())
	get_tree().paused = has_tooltip"""

new_content = content.replace("	if has_tooltip:\n\t\thas_tooltip = GlobalInteractionRouter.is_inspection_locked()\n\t\n\tget_tree().paused = has_tooltip", replacement)

with open("scripts/WindowManager.gd", "w") as f:
    f.write(new_content)
