import re

with open("scripts/GlobalInteractionRouter.gd", "r") as f:
    content = f.read()

# Replace the block in _handle_long_press
old_block = """	if context.interaction_mode == &"FULLY_INTERACTIVE":
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
		commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {"""

new_block = """	if context.interaction_mode == &"FULLY_INTERACTIVE":
		if is_vcr_playing() or _is_combat_phase:
			commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {
				"context": context,
				"anchor_view_id": context.source_view_instance_id,
				"lock": true
			}))
			_execute_command_queue(commands)
			return
			
		commands.append(Command.new(CommandType.SELECT, {"context": context}))
		commands.append(Command.new(CommandType.OPEN_INSPECTION_WINDOW, {"""

new_content = content.replace(old_block, new_block)

with open("scripts/GlobalInteractionRouter.gd", "w") as f:
    f.write(new_content)
