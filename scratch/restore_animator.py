import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# Add _unit_locks and _step_counter
content = content.replace('var _visual_gacha_tokens: int = 0', 'var _visual_gacha_tokens: int = 0\nvar _unit_locks: Dictionary = {}\nvar _is_paused: bool = false\nvar _step_counter: int = 0')

# Replace _animate_events completely with the new batched logic
match = re.search(r'func _animate_events\(events: Array\[CombatEvent\]\) -> void:(.*?)func _find_dynamic_view', content, re.DOTALL)
if match:
    events_body = match.group(1)
    
    # We will also add the lock methods before _animate_events
    lock_methods = """
func acquire_unit_lock(uuid: String) -> void:
	while _unit_locks.has(uuid):
		await get_tree().create_timer(0.05).timeout
	_unit_locks[uuid] = true

func release_unit_lock(uuid: String) -> void:
	_unit_locks.erase(uuid)

func _get_all_targets_for_chain(events: Array[CombatEvent], snapshot: Dictionary) -> Array[String]:
	var targets: Dictionary = {}
	for event in events:
		for t in event.target_uuids:
			targets[t] = true
		var activations = event.trinket_activations
		if activations.is_empty() and event.visual_payload.has("trinket_activations"):
			activations = event.visual_payload["trinket_activations"]
		for act in activations:
			var trinket_uuid = act.get("visual_uuid", "")
			if not trinket_uuid.is_empty():
				targets[trinket_uuid] = true
	var arr: Array[String] = []
	for k in targets.keys():
		arr.append(k)
	return arr

func play_locked_management_chain(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	for event in events:
		var target_uuids = _get_all_targets_for_chain([event], snapshot)
		target_uuids.sort()
		
		for target in target_uuids:
			await acquire_unit_lock(target)
			
		await _animate_events([event])
		
		for target in target_uuids:
			release_unit_lock(target)

func play_parallel_management_events(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	_build_visual_registry(snapshot, false)
	await play_locked_management_chain(snapshot, events)

"""
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
    # Grab the old loop body
    # We will search for _play_trinket_activations_for_event in the OLD body
    loop_match = re.search(r'\t\t_play_trinket_activations_for_event\(event\).*?await get_tree\(\)\.process_frame', events_body, re.DOTALL)
    if loop_match:
        old_loop = loop_match.group(0)
        old_loop_unindented = "\n".join([line[1:] if line.startswith("\t") else line for line in old_loop.split("\n")])
        old_loop_unindented = old_loop_unindented.replace('continue\n\t\t\n\t\tif _is_paused', 'return\n\t\t\n\t\tif _is_paused')
        # Actually the old code in the restored version looks different!
        # Let's just use regex to replace `continue` with `return` correctly.
        old_loop_unindented = old_loop_unindented.replace('continue', 'return')
        
        # Remove the old pause block since we handle it now per batch
        old_loop_unindented = re.sub(r'if _is_paused.*?\n\t\t\n\t\tmatch event.type:', 'match event.type:', old_loop_unindented, flags=re.DOTALL)
        
        new_events_body += "\t" + "\n\t".join(old_loop_unindented.split('\n'))
        
        new_content = content[:match.start(0)] + lock_methods + "func _animate_events(events: Array[CombatEvent]) -> void:\n" + new_events_body + "\n\nfunc _find_dynamic_view" + content[match.end(1):]
        
        # Finally fix _build_visual_registry signature
        new_content = new_content.replace('func _build_visual_registry(snapshot: Dictionary) -> void:', 'func _build_visual_registry(snapshot: Dictionary, clear_existing: bool = true) -> void:')
        new_content = new_content.replace('_visual_registry.clear()\n\t_position_snapshot.clear()', 'if clear_existing:\n\t\t_visual_registry.clear()\n\t\t_position_snapshot.clear()')
        
        # Fix play_turn end cleanup
        new_content = new_content.replace('await _animate_events(events)', 'await _animate_events(events)\n\t\n\t_is_paused = false\n\t_step_counter += 1\n\temit_signal("turn_animation_finished")')

        with open('scripts/BattleAnimator.gd', 'w') as f:
            f.write(new_content)
        print("Success")
    else:
        print("Failed to find loop body")
