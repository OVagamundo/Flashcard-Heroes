import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    lines = f.read().split('\n')

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith('func _animate_events('):
        start_idx = i
    if line.startswith('func apply_hp_delta('):
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    old_events = '\n'.join(lines[start_idx:end_idx])
    
    # We will slice the lines exactly to get the loop body
    # The loop body starts after `for event in events:` (line starts with \t\tSignalBus.log_animation_event.emit(event))
    # It ends at `\t\tawait get_tree().process_frame` right before `_is_paused = false`
    
    loop_start_idx = -1
    loop_end_idx = -1
    for i in range(start_idx, end_idx):
        if lines[i] == '\t\tSignalBus.log_animation_event.emit(event)':
            loop_start_idx = i
        if lines[i] == '\t\tawait get_tree().process_frame' and loop_start_idx != -1:
            loop_end_idx = i
            
    if loop_start_idx != -1 and loop_end_idx != -1:
        loop_lines = lines[loop_start_idx:loop_end_idx+1]
        
        # Unindent one level
        unindented_lines = [line[1:] if line.startswith('\t') else line for line in loop_lines]
        old_loop_unindented = '\n'.join(unindented_lines)
        
        old_loop_unindented = old_loop_unindented.replace('continue', 'return')
        
        # Remove pause logic cleanly
        pause_block = """
		if _is_paused and not _step_advance_requested:
			var step_info = _build_step_info(event)
			emit_signal("combat_step_reached", step_info)
			
			while _is_paused and not _step_advance_requested:
				await get_tree().process_frame
				
		_step_advance_requested = false
"""
        pause_block_unindented = "\n".join([line[1:] if line.startswith("\t") else line for line in pause_block.split("\n")])
        old_loop_unindented = old_loop_unindented.replace(pause_block_unindented, '')
        
        new_events = """func _animate_events(events: Array[CombatEvent]) -> void:
	var local_step_seen = _step_counter
	
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
        
        new_lines = lines[:start_idx] + new_events.split('\n') + lines[end_idx:]
        with open('scripts/BattleAnimator.gd', 'w') as f:
            f.write('\n'.join(new_lines))
        print("Success event rewrite")
    else:
        print("Failed to find loop boundaries")
