import re

with open('scripts/BattleAnimator.gd', 'r') as f:
    lines = f.read().split('\n')

# Find start of PUPPET MODE block
start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if '# PUPPET MODE: Build visual registry by scanning scene tree' in line:
        start_idx = i
    if '# DECOUPLED: No instance rewinding needed' in line and start_idx != -1:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    puppet_lines = lines[start_idx:end_idx]
    
    # create _build_visual_registry
    build_func_lines = ["func _build_visual_registry(start_snapshot: Dictionary, clear_existing: bool = true) -> void:"]
    for line in puppet_lines:
        if line.startswith('\t'):
            line = line[1:]
        if line == '\t_visual_registry.clear()':
            build_func_lines.append('\tif clear_existing:')
            build_func_lines.append('\t\t_visual_registry.clear()')
            continue
        if line == '\t_position_snapshot.clear() # DECOUPLING: Reset position snapshot each sequence':
            build_func_lines.append('\t\t_position_snapshot.clear() # DECOUPLING: Reset position snapshot each sequence')
            continue
        build_func_lines.append('\t' + line)
        
    build_func_lines.append("")
    
    # Put it before play_turn_sequence
    play_turn_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('func play_turn_sequence('):
            play_turn_idx = i
            break
            
    # Remove puppet lines from play_turn_sequence
    lines = lines[:start_idx] + ['\t_build_visual_registry(start_snapshot)'] + lines[end_idx:]
    
    # recalculate play_turn_idx
    for i, line in enumerate(lines):
        if line.startswith('func play_turn_sequence('):
            play_turn_idx = i
            break
            
    lines = lines[:play_turn_idx] + build_func_lines + lines[play_turn_idx:]
    
    # Add _unit_locks and _step_counter to top
    for i, line in enumerate(lines):
        if line.startswith('var _visual_gacha_tokens: int = 0'):
            lines[i] = 'var _visual_gacha_tokens: int = 0\nvar _unit_locks: Dictionary = {}\nvar _step_counter: int = 0'
            break
            
    # Add parallel lock functions before _animate_events
    animate_events_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('func _animate_events('):
            animate_events_idx = i
            break
            
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
	for event in events:
		var target_uuids = _get_all_targets_for_chain([event], snapshot)
		target_uuids.sort()
		
		for target in target_uuids:
			await acquire_unit_lock(target)
			
		await _animate_events([event])
		
		for target in target_uuids:
			release_unit_lock(target)

func play_parallel_management_events(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	_position_snapshot.clear()
	_build_visual_registry(snapshot, false)
	play_locked_management_chain(snapshot, events)
"""
    lines = lines[:animate_events_idx] + lock_methods.strip('\n').split('\n') + [''] + lines[animate_events_idx:]
    
    with open('scripts/BattleAnimator.gd', 'w') as f:
        f.write('\n'.join(lines))
    print("Success clean rewrite stage 1")
