import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    lines = f.read().split('\n')

# Find start
start_idx = -1
for i, line in enumerate(lines):
    if line.startswith('func _animate_events(events: Array[CombatEvent]) -> void:'):
        start_idx = i
        break

# Find end
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith('func apply_hp_delta('):
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    old_events_lines = lines[start_idx:end_idx]
    old_events = '\n'.join(old_events_lines)
    
    # We will rebuild the loop contents
    # First, let's extract the `match event.type:` block and everything around it from the OLD lines.
    # The loop body starts at line `_play_trinket_activations_for_event(event)`
    loop_start_match = re.search(r'\t\tSignalBus\.log_animation_event\.emit\(event\).*?await get_tree\(\)\.process_frame', old_events, re.DOTALL)
    
    if loop_start_match:
        old_loop = loop_start_match.group(0)
        old_loop_unindented = "\n".join([line[1:] if line.startswith("\t") else line for line in old_loop.split("\n")])
        old_loop_unindented = old_loop_unindented.replace('continue', 'return')
        # Remove pause logic:
        old_loop_unindented = re.sub(r'if _is_paused and not _step_advance_requested:.*?_step_advance_requested = false', '', old_loop_unindented, flags=re.DOTALL)
        # Fix empty space left by regex
        old_loop_unindented = old_loop_unindented.replace('\n\t\t\n\t\t\n\t\tmatch event.type', '\n\t\tmatch event.type')

        new_events = """func _animate_events(events: Array[CombatEvent]) -> void:
	var local_step_seen = _step_counter
	
	# Group events into batches
	var batches: Array[Array] = []
	var current_batch: Array[CombatEvent] = []
	var current_batch_id: int = -1
	
	for event in events:
		if event.batch_id == 0:
			if not current_batch.is_empty():
				batches.append(current_batch)
				current_batch = []
			batches.append([event])
		else:
			if event.batch_id != current_batch_id:
				if not current_batch.is_empty():
					batches.append(current_batch)
					current_batch = []
				current_batch_id = event.batch_id
			current_batch.append(event)
			
	if not current_batch.is_empty():
		batches.append(current_batch)
		
	for batch in batches:
		if _is_paused:
			if _step_counter <= local_step_seen:
				# Aggregate step text
				var combined_text = ""
				for evt in batch:
					var info = _build_step_info(evt)
					if info.has("text") and info.text != "":
						if combined_text != "":
							combined_text += "\\n"
						combined_text += info.text
				if combined_text != "":
					emit_signal("combat_step_reached", {"step_counter": _step_counter, "text": combined_text})
				
				while _is_paused and _step_counter <= local_step_seen:
					await get_tree().process_frame
					
			local_step_seen += 1
		else:
			local_step_seen = _step_counter
			
		var pending = [batch.size()]
		for event in batch:
			_run_event_async(event, pending)
			
		while pending[0] > 0:
			await get_tree().process_frame
			
	_is_paused = false
	_step_advance_requested = false
	
	emit_signal("turn_animation_finished")

func _run_event_async(event: CombatEvent, pending: Array) -> void:
	await _animate_single_event(event)
	pending[0] -= 1

func _animate_single_event(event: CombatEvent) -> void:
"""
        new_events += "\t" + "\n\t".join(old_loop_unindented.split('\n')) + "\n"
        
        # reconstruct lines
        new_lines = lines[:start_idx] + new_events.split('\n') + lines[end_idx:]
        with open('scripts/BattleAnimator.gd', 'w') as f:
            f.write('\n'.join(new_lines))
        print("Success final rewrite")
    else:
        print("Failed to find loop body in old events")
else:
    print("Could not find start or end")
