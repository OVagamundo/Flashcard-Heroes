import sys

filepath = '/Users/danhh/Desktop/Flashcard Heroes/scripts/MergeAnimator.gd'
with open(filepath, 'r') as f:
    content = f.read()

old_block = """		if pending_count > 0:
			await bm.resolve_management_effects_and_animate(snapshot)
			
		if bm.has_method("unblock_ui_updates"):
			bm.unblock_ui_updates()"""

new_block = """		if pending_count > 0:
			await bm.resolve_management_effects_and_animate(snapshot)
			
		# VCR is done! Safe to clear the initial spawn stats so future UI interactions use the true hp
		if is_instance_valid(new_instance):
			new_instance.clear_initial_spawn_stats()
			
		if bm.has_method("unblock_ui_updates"):
			bm.unblock_ui_updates()"""

content = content.replace(old_block, new_block)

with open(filepath, 'w') as f:
    f.write(content)

print("Patch applied to MergeAnimator.gd")
