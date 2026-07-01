import re

with open("scripts/GlobalInteractionRouter.gd", "r") as f:
    content = f.read()

# Replace the block that blocks interactions during VCR/combat
old_block = """		# If no selection, check if the interaction is valid in the current phase
		if is_vcr_playing() or _is_combat_phase:
			return # Cannot start a new interaction sequence during combat/animation
		
		# No current selection -> select + lock inspection"""

new_block = """		# If no selection, check if the interaction is valid in the current phase
		if is_vcr_playing() or _is_combat_phase:
			# User can only inspect during combat/animations. Do not allow normal selection for merging/moving.
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
			return commands
			
		# No current selection -> select + lock inspection"""

new_content = content.replace(old_block, new_block)

with open("scripts/GlobalInteractionRouter.gd", "w") as f:
    f.write(new_content)
