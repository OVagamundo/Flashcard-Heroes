with open('scripts/BattleAnimator.gd', 'r') as f:
    content = f.read()

# 1. Variables
content = content.replace('var _visual_gacha_tokens: int = 0', 'var _visual_gacha_tokens: int = 0\nvar _unit_locks: Dictionary = {}\nvar _step_counter: int = 0')

# 2. Extract _build_visual_registry
puppet_block = """	# PUPPET MODE: Build visual registry by scanning scene tree
	_visual_registry.clear()
	_position_snapshot.clear() # DECOUPLING: Reset position snapshot each sequence
	
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	
	if is_instance_valid(battle_view):
		# CRITICAL FIX: Filter out equipped items from snapshot
		# Equipped items don't have views in lineups - they're displayed on their holder units
		# Including them in iteration can cause unpredictable behavior due to dictionary iteration order
		for uuid in start_snapshot:
			var snapshot_data = start_snapshot[uuid]
			
			# TRUE DECOUPLING: Use VALUES from snapshot, not object references
			if snapshot_data is Dictionary and snapshot_data.has("container_tag") and snapshot_data.has("slot_index"):
				var container_tag = snapshot_data.get("container_tag") # StringName VALUE
				var index = snapshot_data.get("slot_index") # int VALUE
				
				# Map container tag to battle view lineup nodes via scene tree
				var lineup_container: HBoxContainer = null
				if container_tag == &"PlayerLineup":
					lineup_container = battle_view.player_lineup
				elif container_tag == &"EnemyLineup":
					lineup_container = battle_view.enemy_lineup
				elif container_tag == &"PlayerBench":
					lineup_container = battle_view.player_bench
				
				if is_instance_valid(lineup_container) and index >= 0:
					var children = lineup_container.get_children()
					
					if index < children.size():
						var slot_view = children[index]
						
						if is_instance_valid(slot_view) and slot_view.get_child_count() > 0:
							# Find GachaBallView among children (indicator TextureRect may also be present).
							# Prefer a UUID match to avoid selecting stale views that are queued_free this frame.
							var gacha_view: GachaBallView = null
							var fallback_view: GachaBallView = null
							for child in slot_view.get_children():
								if child is GachaBallView:
									var candidate: GachaBallView = child
									if not is_instance_valid(fallback_view):
										fallback_view = candidate
									if candidate.has_method("get_instance_uuid") and candidate.get_instance_uuid() == uuid:
										gacha_view = candidate
										break
							if not is_instance_valid(gacha_view):
								gacha_view = fallback_view
							
							if is_instance_valid(gacha_view):
								# Register and initialize view from snapshot VALUES
								_visual_registry[uuid] = gacha_view
								
								# DECOUPLING: Capture position NOW - animations will use this snapshot
								# instead of querying views at animation time
								var rect = gacha_view.get_global_rect()
								_position_snapshot[uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								
								# Inject uuid into snapshot so set_visual_state can update _instance_uuid
								snapshot_data["uuid"] = uuid
								gacha_view.set_visual_state(snapshot_data)
							else:
								push_warning("[BattleAnimator] Failed to register %s: Child is not GachaBallView" % uuid)
						else:
							push_warning("[BattleAnimator] Failed to register %s: Slot %d in %s is empty" % [uuid, index, container_tag])
					else:
						pass
				else:
					pass
		
		# Also scan EffectsLayer for in-flight views (Gacha Draws)
		# This handles race conditions where a unit is targeted while still animating/flying
		var effects_layer = get_tree().get_first_node_in_group("effects_layer")
		if is_instance_valid(effects_layer):
			for child in effects_layer.get_children():
				if child is GachaBallView:
					var uuid = child.get_instance_uuid()
					if not uuid.is_empty():
						_visual_registry[uuid] = child
						
						# Capture snapshot for flying unit
						var rect = child.get_global_rect()
						_position_snapshot[uuid] = {
							"position": rect.position,
							"size": rect.size,
							"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
						}
	
	# DECOUPLED: No instance rewinding needed"""

build_func_str = """
func _build_visual_registry(start_snapshot: Dictionary, clear_existing: bool = true) -> void:
	if clear_existing:
		_visual_registry.clear()
		_position_snapshot.clear() # DECOUPLING: Reset position snapshot each sequence
	
	var battle_view = get_tree().get_first_node_in_group("battle_view")
	
	if is_instance_valid(battle_view):
		for uuid in start_snapshot:
			var snapshot_data = start_snapshot[uuid]
			
			if snapshot_data is Dictionary and snapshot_data.has("container_tag") and snapshot_data.has("slot_index"):
				var container_tag = snapshot_data.get("container_tag")
				var index = snapshot_data.get("slot_index")
				
				var lineup_container: HBoxContainer = null
				if container_tag == &"PlayerLineup":
					lineup_container = battle_view.player_lineup
				elif container_tag == &"EnemyLineup":
					lineup_container = battle_view.enemy_lineup
				elif container_tag == &"PlayerBench":
					lineup_container = battle_view.player_bench
				
				if is_instance_valid(lineup_container) and index >= 0:
					var children = lineup_container.get_children()
					if index < children.size():
						var slot_view = children[index]
						if is_instance_valid(slot_view) and slot_view.get_child_count() > 0:
							var gacha_view: GachaBallView = null
							var fallback_view: GachaBallView = null
							for child in slot_view.get_children():
								if child is GachaBallView:
									var candidate: GachaBallView = child
									if not is_instance_valid(fallback_view):
										fallback_view = candidate
									if candidate.has_method("get_instance_uuid") and candidate.get_instance_uuid() == uuid:
										gacha_view = candidate
										break
							if not is_instance_valid(gacha_view):
								gacha_view = fallback_view
							
							if is_instance_valid(gacha_view):
								_visual_registry[uuid] = gacha_view
								var rect = gacha_view.get_global_rect()
								_position_snapshot[uuid] = {
									"position": rect.position,
									"size": rect.size,
									"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
								}
								snapshot_data["uuid"] = uuid
								gacha_view.set_visual_state(snapshot_data)
		
		var effects_layer = get_tree().get_first_node_in_group("effects_layer")
		if is_instance_valid(effects_layer):
			for child in effects_layer.get_children():
				if child is GachaBallView:
					var uuid = child.get_instance_uuid()
					if not uuid.is_empty():
						_visual_registry[uuid] = child
						var rect = child.get_global_rect()
						_position_snapshot[uuid] = {
							"position": rect.position,
							"size": rect.size,
							"center": Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
						}
"""

content = content.replace(puppet_block, '\t_build_visual_registry(start_snapshot)\n')

content = content.replace('func play_turn_sequence(', build_func_str + '\nfunc play_turn_sequence(')


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
	_build_visual_registry(snapshot, false)
	play_locked_management_chain(snapshot, events)

"""
content = content.replace('func _animate_events(events: Array[CombatEvent]) -> void:', lock_methods + 'func _animate_events(events: Array[CombatEvent]) -> void:')

with open('scripts/BattleAnimator.gd', 'w') as f:
    f.write(content)
