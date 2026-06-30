import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

old_func = """func play_locked_management_chain(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	for event in events:
		var target_uuids = _get_all_targets_for_chain([event], snapshot)
		target_uuids.sort()
		
		for target in target_uuids:
			await acquire_unit_lock(target)
			
		await _animate_events([event])
		
		for target in target_uuids:
			release_unit_lock(target)"""

new_func = """func play_locked_management_chain(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
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
		var target_uuids = _get_all_targets_for_chain(batch, snapshot)
		target_uuids.sort()
		
		for target in target_uuids:
			await acquire_unit_lock(target)
			
		await _animate_events(batch)
		
		for target in target_uuids:
			release_unit_lock(target)"""

content = content.replace(old_func, new_func)

with open('scripts/BattleAnimator.gd', 'w') as f:
    f.write(content)
