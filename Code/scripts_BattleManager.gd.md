<!-- Original: scripts/BattleManager.gd -->

```gdscript
extends Node
class_name BattleManager

const RS = preload("res://scripts/RunState.gd")

enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

var _effect_queue: Array[EffectRequest] = []
var _is_processing_effect: bool = false

const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
}

var _battle_instances: Dictionary = {}
var _containers: Dictionary = {}

const FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
var _gacha_tokens: int = 0

func _ready():
	var existing := get_tree().get_nodes_in_group("battle_manager")
	if existing.size() > 0:
		var is_first = true
		for node in existing:
			if node != self: is_first = false; break
		if not is_first: queue_free(); return
	add_to_group("battle_manager")
	_setup_battle()
	_change_phase(Phases.MANAGEMENT)
	_connect_signals()
	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	EventBus.emit_signal("battle_inventory_changed")

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)
	if EventBus.is_connected("end_turn_requested", _on_end_turn_requested):
		EventBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if EventBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		EventBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if EventBus.is_connected("battle_inventory_changed", _check_and_trigger_reshuffles):
		EventBus.battle_inventory_changed.disconnect(_check_and_trigger_reshuffles)

func _connect_signals():
	EventBus.end_turn_requested.connect(_on_end_turn_requested)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	EventBus.battle_inventory_changed.connect(_check_and_trigger_reshuffles)

func _setup_battle():
	_battle_instances.clear()
	_containers.clear()
	_effect_queue.clear()
	_gacha_tokens = 5
	
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()
	var permanent_to_battle_uuid_map: Dictionary = {}

	# First pass: Create all battle copies and map their new UUIDs, except for the hero (use persistent instance for hero)
	var hero_instance = null
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		if is_hero:
			hero_instance = perm_inst
			# Add the hero instance to _battle_instances so UI can find it during battle
			_battle_instances[perm_inst.ball_uuid] = perm_inst
			continue # Don't create a battle copy for the hero
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy): continue
		_battle_instances[battle_copy.ball_uuid] = battle_copy
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

	# Second pass: Remap equipped item UUIDs on all battle copies (skip hero)
	for battle_uuid in _battle_instances:
		var battle_inst = _battle_instances[battle_uuid]
		if battle_inst.get_definition().category != &"UNIT": continue
		var original_equipped_uuids = battle_inst.equipped_item_uuids.duplicate()
		battle_inst.equipped_item_uuids.clear()
		battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())
		battle_inst.equipped_item_uuids.fill("")
		for i in range(original_equipped_uuids.size()):
			var permanent_item_uuid = original_equipped_uuids[i]
			if not permanent_item_uuid.is_empty() and permanent_to_battle_uuid_map.has(permanent_item_uuid):
				var battle_item_uuid = permanent_to_battle_uuid_map[permanent_item_uuid]
				battle_inst.equipped_item_uuids[i] = battle_item_uuid
				# Also update the item's own state
				var item_instance = _battle_instances.get(battle_item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i

	# Third pass: Place all instances in their correct, stable locations.
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc): continue
		if is_hero:
			# Place the persistent hero instance directly in the PlayerLineup
			var container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			container.set_uuid(perm_loc.index, perm_inst.ball_uuid)
			_update_instance_location(perm_inst.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, perm_loc.index)
			continue
		var battle_uuid = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid)
		if not battle_uuid: continue
		var battle_copy = _battle_instances[battle_uuid]
		# An item's location is determined by what it's equipped to. Skip direct placement.
		if not battle_copy.equipped_on_uuid.is_empty():
			continue
		var target_container_name: StringName
		if perm_loc.container.begins_with("RunInventoryT"):
			var tier = perm_inst.get_definition().tier
			target_container_name = &"BattleInventoryT%d" % tier
		else:
			match perm_loc.container:
				RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
				RS.RUN_CONTAINER_TAGS.PLAYER_BENCH:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_BENCH
				RS.RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
				_:
					# If it's not a recognized container, skip this instance
					continue

		var container = get_container(target_container_name)
		var index = perm_loc.index
		container.set_uuid(index, battle_copy.ball_uuid)
		_update_instance_location(battle_copy.ball_uuid, target_container_name, index)

	_setup_enemy_lineup()
	_setup_enemy_lineup()

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d", &"enemy_hero"]
	var lineup_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if not is_instance_valid(unit_def): continue
		
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		_battle_instances[enemy_inst.ball_uuid] = enemy_inst
		
		lineup_container.set_uuid(i, enemy_inst.ball_uuid)
		_update_instance_location(enemy_inst.ball_uuid, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, i)

func get_container(container_name: StringName) -> DataContainer:
	if _containers.has(container_name):
		return _containers[container_name]

	var new_container: DataContainer

	match container_name:
		BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			new_container = FixedArrayContainer.new(6)
		BATTLE_CONTAINER_TAGS.PLAYER_BENCH, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
			new_container = FixedArrayContainer.new(3)
		BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
			new_container = GrowableGridContainer.new(16, 8)
		_: # Default case for BattleInventoryT*
			if container_name.begins_with("BattleInventoryT"):
				new_container = GrowableGridContainer.new(16, 4)
			else:
				# Failsafe for unknown container types
				printerr("BattleManager: Unknown container type requested: ", container_name)
				new_container = FixedArrayContainer.new(1)

	_containers[container_name] = new_container
	return new_container

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(container_tag)
	if not is_instance_valid(container): return result
	var uuids = container.get_all_non_empty_uuids()
	for uuid in uuids:
		var instance = get_instance(uuid)
		if is_instance_valid(instance): result.append(instance)
	
	# Sort by location index using the _instance_locations dictionary
	result.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	return result

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"BattleInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	var instance = get_instance(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func _update_instance_location(uuid: String, container_name: StringName, index: int):
	var instance = get_instance(uuid)
	if not is_instance_valid(instance): return
	
	# Directly update the instance's properties, making it the source of truth.
	instance.location_container_tag = container_name
	instance.location_slot_index = index
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	
	# This function now ONLY handles direct container lookups.
	# The logic for resolving an equipped item's location is now handled by
	# the caller by checking the LocationIdentifier first. This change is
	# mandated by the new architecture to avoid ambiguity.
	var container = get_container(loc.container)
	if not is_instance_valid(container): return null
	
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid) if not uuid.is_empty() else null

func get_all_instances() -> Dictionary:
	return _battle_instances

func get_gacha_tokens() -> int:
	return _gacha_tokens

func get_current_phase_name() -> StringName:
	var phase_name: StringName
	match _current_battle_phase:
		Phases.START_OF_TURN: phase_name = &"START_OF_TURN"
		Phases.MANAGEMENT: phase_name = &"MANAGEMENT"
		Phases.COMBAT: phase_name = &"COMBAT"
		Phases.END_OF_TURN: phase_name = &"END_OF_TURN"
		Phases.BATTLE_OVER: phase_name = &"BATTLE_OVER"
	return phase_name

func get_battle_inventory() -> Dictionary:
	return _containers

func get_discard_pile_inventory() -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(container): return result
	var all_uuids = container.get_all_uuids()
	for uuid in all_uuids:
		if uuid.is_empty(): result.append(null)
		else: result.append(get_instance(uuid))
	if result.size() < 16: result.resize(16)
	return result

func _change_phase(new_phase: Phases):
	_current_battle_phase = new_phase
	EventBus.emit_signal("battle_phase_changed", get_current_phase_name())
	match _current_battle_phase:
		Phases.START_OF_TURN:
			_gacha_tokens += 5
			EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			_populate_effect_queue()
			_process_effect_queue()
		Phases.END_OF_TURN:
			pass

func _populate_effect_queue():
	_effect_queue.clear()
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for attacker in enemy_lineup:
		var target = _get_frontmost_target(false)
		if is_instance_valid(target):
			var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", {"target_uuid": target.ball_uuid})
			_effect_queue.append(request)
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for attacker in player_lineup:
		var target = _get_frontmost_target(true)
		if is_instance_valid(target):
			var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", {"target_uuid": target.ball_uuid})
			_effect_queue.append(request)

func _process_effect_queue() -> void:
	if _is_processing_effect: return
	if _effect_queue.is_empty(): _change_phase(Phases.MANAGEMENT); return
	_is_processing_effect = true
	while not _effect_queue.is_empty():
		var request: EffectRequest = _effect_queue.pop_back()
		var source = get_instance(request.source_uuid)
		if not is_instance_valid(source) or source.current_hp <= 0: continue
		var target = get_instance(request.trigger_context.get("target_uuid"))
		if not is_instance_valid(target) or target.current_hp <= 0:
			var attacker_is_player: bool = source.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			target = _get_frontmost_target(attacker_is_player)
			if not is_instance_valid(target): continue
		var ability_def = Database.get_ability_definition(request.ability_id)
		if not is_instance_valid(ability_def): continue
		var message = "[b]%s[/b] uses [b]%s[/b] on [b]%s[/b]" % [tr(source.get_definition().display_name_key), tr(ability_def.name_key), tr(target.get_definition().display_name_key)]
		EventBus.emit_signal("battle_log_event", message)
		ability_def.effect.execute(source, [target], self)
		_check_for_deaths()
		if _is_battle_over(): break
		await get_tree().create_timer(0.8).timeout
	_is_processing_effect = false
	_change_phase(Phases.END_OF_TURN)
	await get_tree().create_timer(0.1).timeout
	_change_phase(Phases.MANAGEMENT)

func _move_instance_to_discard(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var index = discard_container.find_first_empty_slot()
	if index == -1: index = discard_container.get_all_uuids().size()
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)

func _remove_instance_from_container(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var loc = get_location_for_uuid(instance.ball_uuid)
	if not is_instance_valid(loc): return
	var container = get_container(loc.container)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx := uuids.find(instance.ball_uuid)
		if idx != -1: container.set_uuid(idx, "")

func _check_for_deaths():
	var something_changed = false
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			_remove_instance_from_container(unit)
			for item_uuid in unit.equipped_item_uuids:
				if not item_uuid.is_empty():
					var item_instance = get_instance(item_uuid)
					if is_instance_valid(item_instance):
						item_instance.equipped_on_uuid = ""
						item_instance.equipped_slot_index = -1
						_move_instance_to_discard(item_instance)
			unit.equipped_item_uuids.fill("")
			_move_instance_to_discard(unit)
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			something_changed = true
			_remove_instance_from_container(unit)
			if _battle_instances.has(unit.ball_uuid):
				_battle_instances.erase(unit.ball_uuid)
	if something_changed:
		EventBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if player_lineup.is_empty() or enemy_lineup.is_empty():
		_current_battle_phase = Phases.BATTLE_OVER
		var did_player_win = enemy_lineup.is_empty()
		WindowManager.open_end_battle_popup(did_player_win)
		return true
	return false

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container): return
	var instances_to_move = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).filter(
		func(inst): return inst.get_definition().tier == tier_to_reshuffle
	)
	if instances_to_move.is_empty(): return
	EventBus.emit_signal("battle_log_event", "Reshuffling Tier %d discard pile..." % tier_to_reshuffle)
	for instance in instances_to_move:
		# Restore stats to base values before moving back to draw pool
		instance.reset_battle_stats()
		
		_remove_instance_from_container(instance)
		var new_index = dest_container.find_first_empty_slot()
		if new_index == -1: new_index = dest_container.get_all_uuids().size()
		dest_container.set_uuid(new_index, instance.ball_uuid)
		_update_instance_location(instance.ball_uuid, dest_container_tag, new_index)

func _check_and_trigger_reshuffles():
	for tier in [1, 2, 3]:
		var tier_pool = get_instances_in_container("BattleInventoryT%d" % tier)
		if tier_pool.is_empty():
			_reshuffle_discard_pile(tier)

func _get_frontmost_target(attacker_is_player: bool) -> GachaBallInstance:
	var target_lineup_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var living_targets = get_instances_in_container(target_lineup_tag).filter(func(unit): return unit.current_hp > 0)
	if living_targets.is_empty(): return null
	
	# Sort by location index to ensure consistent targeting
	living_targets.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	
	# Player attacks from left to right (0 to n), enemies from right to left (n to 0)
	return living_targets[0] if attacker_is_player else living_targets[-1]

func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.START_OF_TURN)

func _on_unit_inventory_changed(unit_uuid: String):
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost: return
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool = get_instances_in_container(container_tag)
	if tier_pool.is_empty(): return
	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	var drawn_instance = tier_pool.pick_random()
	var target_container_tag: StringName
	var target_container_capacity: int
	match drawn_instance.get_definition().category:
		&"UNIT":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_BENCH
			target_container_capacity = 3
		&"ITEM":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
			target_container_capacity = 3
		_:
			_move_instance_to_discard(drawn_instance)
			EventBus.emit_signal("battle_inventory_changed")
			return
	_remove_instance_from_container(drawn_instance)
	var target_container := get_container(target_container_tag)
	var empty_slot := target_container.find_first_empty_slot()
	if empty_slot != -1 and empty_slot < target_container_capacity:
			target_container.set_uuid(empty_slot, drawn_instance.ball_uuid)
			_update_instance_location(drawn_instance.ball_uuid, target_container_tag, empty_slot)
	else:
		_move_instance_to_discard(drawn_instance)
	EventBus.emit_signal("battle_inventory_changed")

```