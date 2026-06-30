with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# Add _unit_locks
content = content.replace('var _visual_gacha_tokens: int = 0', 'var _visual_gacha_tokens: int = 0\nvar _unit_locks: Dictionary = {}')

import re
# We extract the entire PUPPET MODE block from play_turn_sequence and put it in _build_visual_registry
match = re.search(r'\t# PUPPET MODE: Build visual registry by scanning scene tree\n\t_visual_registry\.clear\(\).*?# DECOUPLED: No instance rewinding needed', content, re.DOTALL)
if match:
    puppet_block = match.group(0)
    
    # We replace it in play_turn_sequence with a call to _build_visual_registry(start_snapshot)
    new_call = '\t_build_visual_registry(start_snapshot)\n\t\n\t# DECOUPLED: No instance rewinding needed'
    
    content = content[:match.start(0)] + new_call + content[match.end(0):]
    
    # Now define the function before play_turn_sequence
    # Unindent the puppet_block by one tab
    unindented_block = "\n".join([line[1:] if line.startswith('\t') else line for line in puppet_block.split('\n')])
    unindented_block = unindented_block.replace('_visual_registry.clear()\n\t_position_snapshot.clear()', 'if clear_existing:\n\t\t_visual_registry.clear()\n\t\t_position_snapshot.clear()')
    unindented_block = unindented_block.replace('# DECOUPLED: No instance rewinding needed', '')
    
    build_func = f"""
func _build_visual_registry(start_snapshot: Dictionary, clear_existing: bool = true) -> void:
{unindented_block}
"""
    
    # Insert it before play_turn_sequence
    content = content.replace('func play_turn_sequence(start_snapshot: Dictionary, turn_log: Array[CombatEvent]) -> void:', build_func + 'func play_turn_sequence(start_snapshot: Dictionary, turn_log: Array[CombatEvent]) -> void:')
    
    # Add parallel management chain functions
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
		if not event.source_uuid.is_empty():
			targets[event.source_uuid] = true
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
	var target_uuids = _get_all_targets_for_chain(events, snapshot)
	target_uuids.sort()
	
	for target in target_uuids:
		await acquire_unit_lock(target)
		
	await _animate_events(events)
	
	for target in target_uuids:
		release_unit_lock(target)

func play_parallel_management_events(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	_build_visual_registry(snapshot, false)
	play_locked_management_chain(snapshot, events)

"""
    content = content.replace('func _animate_events(events: Array[CombatEvent]) -> void:', lock_methods + 'func _animate_events(events: Array[CombatEvent]) -> void:')
    
    with open('scripts/BattleAnimator.gd', 'w') as f:
        f.write(content)
    print("Success extraction")
else:
    print("Failed to find PUPPET block")
