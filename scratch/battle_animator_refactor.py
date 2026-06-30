import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# Replace clear_existing in _build_visual_registry
content = content.replace('func _build_visual_registry(snapshot: Dictionary) -> void:', 'func _build_visual_registry(snapshot: Dictionary, clear_existing: bool = true) -> void:')
content = content.replace('_visual_registry.clear()\n\t_position_snapshot.clear()', 'if clear_existing:\n\t\t_visual_registry.clear()\n\t\t_position_snapshot.clear()')
content = content.replace('_build_visual_registry(snapshot)\n\t\n\t# Await the locked management chain', '_build_visual_registry(snapshot, false)\n\t\n\t# Await the locked management chain')

# We need to extract the match event.type block and put it in _animate_single_event
match = re.search(r'func _animate_events\(events: Array\[CombatEvent\]\) -> void:(.*?)func _find_dynamic_view', content, re.DOTALL)
if match:
    events_body = match.group(1)
    # We will replace the body of _animate_events
    new_events_body = """
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

func _run_event_async(event: CombatEvent, pending: Array) -> void:
	await _animate_single_event(event)
	pending[0] -= 1

func _animate_single_event(event: CombatEvent) -> void:
"""
    # Now we need to append the old loop body starting from _play_trinket_activations_for_event
    loop_body_match = re.search(r'\t\t_play_trinket_activations_for_event\(event\).*?await get_tree\(\)\.process_frame', events_body, re.DOTALL)
    if loop_body_match:
        old_loop = loop_body_match.group(0)
        # unindent one level
        old_loop_unindented = "\n".join([line[1:] if line.startswith("\t") else line for line in old_loop.split("\n")])
        # Fix the continue to return
        old_loop_unindented = old_loop_unindented.replace('continue\n\t\t\n\t\tmatch event.type:', 'return\n\t\t\n\t\tmatch event.type:')
        # Note: there might be other continues in DEATH for example:
        old_loop_unindented = old_loop_unindented.replace('if _dead_units.has(dead_uuid):\n\t\t\t\t\t\tcontinue', 'if _dead_units.has(dead_uuid):\n\t\t\t\t\t\treturn')
        
        new_events_body += old_loop_unindented
        
        new_content = content[:match.start(1)] + "\n" + new_events_body + "\n\n" + content[match.end(1):]
        with open('scripts/BattleAnimator.gd', 'w') as f:
            f.write(new_content)
        print("Success")
    else:
        print("Failed to find loop body")
else:
    print("Failed to find _animate_events")
