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
	var run_instances: Array = GameManager.run_state.get_all_instances().values()
	for perm_inst in run_instances:
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy): continue
		_battle_instances[battle_copy.ball_uuid] = battle_copy
		var tier: int = battle_copy.get_definition().tier
		var tier_container_tag: StringName = "BattleInventoryT%d" % tier
		var container := get_container(tier_container_tag)
		var slot := container.find_first_empty_slot()
		if slot == -1: slot = container.get_all_uuids().size()
		container.set_uuid(slot, battle_copy.ball_uuid)
		battle_copy.location_container_tag = tier_container_tag
		battle_copy.location_slot_index = slot
		var def := battle_copy.get_definition()
		var is_hero_unit := false
		if def != null:
			is_hero_unit = def.is_hero
			if not is_hero_unit and def.tags.has("HERO"): is_hero_unit = true
		if is_hero_unit:
			var lineup_container := get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			lineup_container.set_uuid(0, battle_copy.ball_uuid)
			battle_copy.location_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			battle_copy.location_slot_index = 0
	var hero_run_inst: GachaBallInstance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_run_inst) and not _battle_instances.has(hero_run_inst.ball_uuid):
		var hero_copy: GachaBallInstance = hero_run_inst.create_battle_copy()
		_battle_instances[hero_copy.ball_uuid] = hero_copy
		var lineup_c := get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		lineup_c.set_uuid(0, hero_copy.ball_uuid)
		hero_copy.location_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		hero_copy.location_slot_index = 0
	_setup_enemy_lineup()

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d", &"enemy_hero"]
	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if not is_instance_valid(unit_def): continue
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		_battle_instances[enemy_inst.ball_uuid] = enemy_inst
		var lineup_c = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		lineup_c.set_uuid(i, enemy_inst.ball_uuid)
		enemy_inst.location_container_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		enemy_inst.location_slot_index = i

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
				new_container = GrowableGridContainer.new(8, 4)
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
	result.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
	return result

func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	if loc.container == &"equipped_item":
		var item_owner = get_instance(loc.unit_uuid)
		if is_instance_valid(item_owner):
			var item_uuid = item_owner.get_equipped_item_uuid(loc.index)
			return get_instance(item_uuid)
		return null
	var container = get_container(loc.container)
	if not is_instance_valid(container): return null
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid)

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
	instance.location_container_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
	instance.location_slot_index = index
	discard_container.set_uuid(index, instance.ball_uuid)

func _remove_instance_from_container(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var container = get_container(instance.location_container_tag)
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
		instance.location_container_tag = dest_container_tag
		instance.location_slot_index = new_index

func _check_and_trigger_reshuffles():
	for tier in [1, 2, 3]:
		var tier_pool = get_instances_in_container("BattleInventoryT%d" % tier)
		if tier_pool.is_empty():
			_reshuffle_discard_pile(tier)

func _get_frontmost_target(attacker_is_player: bool) -> GachaBallInstance:
	var target_lineup_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var living_targets = get_instances_in_container(target_lineup_tag).filter(func(unit): return unit.current_hp > 0)
	if living_targets.is_empty(): return null
	return living_targets[0] if attacker_is_player else living_targets[-1]

func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.START_OF_TURN)

func _on_unit_inventory_changed(unit_uuid: String):
	for instance in _battle_instances.values():
		var def: GachaBallDefinition = instance.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT": continue
		instance.recalculate_stats(_battle_instances)

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
		drawn_instance.location_container_tag = target_container_tag
		drawn_instance.location_slot_index = empty_slot
		target_container.set_uuid(empty_slot, drawn_instance.ball_uuid)
	else:
		_move_instance_to_discard(drawn_instance)
	EventBus.emit_signal("battle_inventory_changed")

```