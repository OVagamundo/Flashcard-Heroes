with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# 1. Add locks and counters
content = content.replace('var _visual_gacha_tokens: int = 0', 'var _visual_gacha_tokens: int = 0\nvar _unit_locks: Dictionary = {}\nvar _step_counter: int = 0')

# 2. Add clear_existing
content = content.replace('func _build_visual_registry(snapshot: Dictionary) -> void:', 'func _build_visual_registry(snapshot: Dictionary, clear_existing: bool = true) -> void:')
content = content.replace('_visual_registry.clear()\n\t_position_snapshot.clear()', 'if clear_existing:\n\t\t_visual_registry.clear()\n\t\t_position_snapshot.clear()')

# 3. Add management chain functions right before _animate_events
lock_methods = """
func acquire_unit_lock(uuid: String) -> void:
	while _unit_locks.has(uuid):
		await get_tree().create_timer(0.05).timeout
	_unit_locks[uuid] = true

func release_unit_lock(uuid: String) -> void:
	_unit_locks.erase(uuid)

func _get_all_targets_for_chain(events: Array[CombatEvent]) -> Array[String]:
	var targets: Dictionary = {}
	for event in events:
		if not event.source_uuid.is_empty():
			targets[event.source_uuid] = true
		for t in event.target_uuids:
			targets[t] = true
	var arr: Array[String] = []
	for k in targets.keys():
		arr.append(k)
	return arr

func play_locked_management_chain(snapshot: Dictionary, events: Array[CombatEvent]) -> void:
	var target_uuids = _get_all_targets_for_chain(events)
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
