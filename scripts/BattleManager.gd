extends Node
class_name BattleManager

const RS = preload("res://scripts/RunState.gd")



# --- TDD: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

# --- TDD: Single Source of Truth ---
const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",

	BATTLE_DRAW_POOL = &"BattleDrawPool",
	BATTLE_DISCARD_PILE = &"BattleDiscardPile",
}

var _battle_instances: Dictionary = {}
# Data containers keyed by StringName tags (created lazily by get_container)
var _containers: Dictionary = {}

# Local lightweight container implementation (Array-backed).
class ArrayContainer:
	extends "res://scripts/DataContainer.gd"
	var _data: Array[String] = []
	func _init(size: int = 6):
		_data.resize(size)
		_data.fill("")
	func get_uuid(index: int) -> String:
		if index >= 0 and index < _data.size():
			return _data[index]
		return ""
	func set_uuid(index: int, uuid: String) -> void:
		if index < 0:
			return
		if index >= _data.size():
			_data.resize(index + 1)
			for i in range(_data.size()):
				if _data[i] == null:
					_data[i] = ""
		_data[index] = uuid
	func find_first_empty_slot() -> int:
		return _data.find("")
	func get_all_uuids() -> Array[String]:
		return _data.duplicate()
var _gacha_tokens: int = 0

# --- Godot Lifecycle ---

# ------------------------------------------------------------------
# Battle Setup
# ------------------------------------------------------------------
# Creates battle-copies of the player's run inventory and places them
# into the tiered battle-inventory containers (BattleInventoryT1/2/3).
# Also spawns the enemy lineup.
func _setup_battle():
	# Clear any stale data in case this is a retry.
	_battle_instances.clear()
	_containers.clear()

	# 1. Copy the player's permanent run inventory into battle instances
	var run_instances: Array = GameManager.run_state.get_all_instances().values()
	for perm_inst in run_instances:
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy):
			printerr("BattleManager: Failed to create battle copy for", perm_inst.ball_uuid)
			continue

		_battle_instances[battle_copy.ball_uuid] = battle_copy

		# Determine the tiered battle-inventory container for this instance
		var tier: int = battle_copy.get_definition().tier
		var tier_container_tag: StringName = StringName("BattleInventoryT%d" % tier)
		var container := get_container(tier_container_tag)
		var slot := container.find_first_empty_slot()
		if slot == -1:
			slot = container.get_all_uuids().size()
		container.set_uuid(slot, battle_copy.ball_uuid)

		battle_copy.location_container_tag = tier_container_tag
		battle_copy.location_slot_index = slot

		# Detect hero instance (supports both new `is_hero` flag and legacy HERO tag)
		var def := battle_copy.get_definition()
		var is_hero_unit := false
		if def != null:
			is_hero_unit = def.is_hero
			if not is_hero_unit and def.tags.has("HERO"):
				is_hero_unit = true

		# If this instance is the hero, also place it into the PlayerLineup by default
		if is_hero_unit:
			var lineup_container := get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			lineup_container.set_uuid(0, battle_copy.ball_uuid)
			battle_copy.location_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			battle_copy.location_slot_index = 0

	# 1b. Ensure the player's hero is always present, even if not part of run_instances
	var hero_run_inst: GachaBallInstance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_run_inst) and not _battle_instances.has(hero_run_inst.ball_uuid):
		var hero_copy: GachaBallInstance = hero_run_inst.create_battle_copy()
		_battle_instances[hero_copy.ball_uuid] = hero_copy
		# Place hero in PlayerLineup slot 0
		var lineup_c := get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		lineup_c.set_uuid(0, hero_copy.ball_uuid)
		hero_copy.location_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		hero_copy.location_slot_index = 0

	# 2. Add the enemies defined for this encounter
	_setup_enemy_lineup()

	# Emit initial inventory populated signal so views can draw immediately
	EventBus.emit_signal("battle_inventory_changed") 
func _ready():
	# Detect and prevent duplicate BattleManager instances which can cause
	# duplicate signal handling (e.g. double draws per click).
	var existing := get_tree().get_nodes_in_group("battle_manager")
	if existing.size() > 0:
		printerr("BattleManager: Duplicate instance detected – self-terminating.")
		queue_free()
		return
	add_to_group("battle_manager")
	_setup_battle()
	_connect_signals()

	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	EventBus.emit_signal("battle_inventory_changed")

	_change_phase(Phases.START_OF_TURN)

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)

	if EventBus.is_connected("end_turn_requested", _on_end_turn_requested):
		EventBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if EventBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		EventBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)

func _connect_signals():
	EventBus.end_turn_requested.connect(_on_end_turn_requested)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)


# --- Public API ---
# Container helpers restored after accidental deletion
func get_container(container_name: StringName) -> DataContainer:
	# Returns a cached container object or lazily creates one.
	if _containers.has(container_name):
		return _containers[container_name]
	var default_size := 6
	var name_str: String = String(container_name)
	if name_str in ["ItemInventory", "PlayerItemInventory"]:
		default_size = 3
	elif name_str.begins_with("BattleInventoryT"):
		default_size = 16
	var c := ArrayContainer.new(default_size)
	_containers[container_name] = c
	return c

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	for instance in _battle_instances.values():
		if instance.location_container_tag == container_tag:
			result.append(instance)
	# Keep deterministic ordering by slot index
	result.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
	return result
 
func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

# Returns the instance located at the given LocationIdentifier (tier/index/container)
func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# Special handling for equipped item slots which are not linked to a normal container
	if loc.container == &"equipped_item":
		var parent_uuid: String = loc.unit_uuid
		if parent_uuid.is_empty():
			return null
		var parent_instance: GachaBallInstance = get_instance(parent_uuid)
		if not is_instance_valid(parent_instance):
			return null
		if loc.index >= 0 and loc.index < parent_instance.equipped_item_uuids.size():
			var item_uuid: String = parent_instance.equipped_item_uuids[loc.index]
			if item_uuid.is_empty():
				return null
			return get_instance(item_uuid)
		return null

	var container := get_container(loc.container)
	if container == null:
		return null
	var uuid := container.get_uuid(loc.index)
	if uuid.is_empty():
		return null
	return get_instance(uuid)

func get_all_instances() -> Dictionary:
	# Returns the live dictionary of all battle instances keyed by UUID.
	# Useful for UI windows that need quick look-ups.
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

# ------------------------------------------------------------------
# Public helper to expose the tiered battle inventory in a view-friendly
# dictionary structure. The result mirrors the run-inventory structure
# expected by InventoryWindow, i.e. { 1: Array[16], 2: Array[16], 3: Array[16] }.
# Empty slots are `null` so callers can rely on array indices matching slot
# positions in the UI grids.
func get_battle_inventory() -> Dictionary:
	var inventory := {}
	var GRID_CAPACITY := 16 # Matches default container size for BattleInventoryT* per TDD table 2.2
	for tier in [1, 2, 3]:
		var container_tag: StringName = StringName("BattleInventoryT%d" % tier)
		var tier_instances: Array[GachaBallInstance] = get_instances_in_container(container_tag)

		var tier_array: Array = []
		tier_array.resize(GRID_CAPACITY)
		for i in range(GRID_CAPACITY):
			tier_array[i] = null

		for inst in tier_instances:
			if inst.location_slot_index >= 0 and inst.location_slot_index < GRID_CAPACITY:
				tier_array[inst.location_slot_index] = inst

		inventory[tier] = tier_array

	return inventory

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"enemy_hero", &"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d"]
	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if not unit_def: continue

		var enemy_instance := GachaBallInstance.new()
		enemy_instance.initialize(unit_def)
		_battle_instances[enemy_instance.ball_uuid] = enemy_instance
		enemy_instance.location_container_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		enemy_instance.location_slot_index = i

		# Record UUID in the EnemyLineup container so UI can discover it
		var enemy_container := get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		if is_instance_valid(enemy_container):
			enemy_container.set_uuid(i, enemy_instance.ball_uuid)

# --- State Machine Logic ---
func _get_player_hero() -> GachaBallInstance:
	for instance in get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP):
		if instance.get_definition().is_hero:
			return instance
	return null

func _change_phase(new_phase: Phases):
	_current_battle_phase = new_phase
	var phase_name: StringName
	match _current_battle_phase:
		Phases.START_OF_TURN: phase_name = &"START_OF_TURN"
		Phases.MANAGEMENT: phase_name = &"MANAGEMENT"
		Phases.COMBAT: phase_name = &"COMBAT"
		Phases.END_OF_TURN: phase_name = &"END_OF_TURN"
		Phases.BATTLE_OVER: phase_name = &"BATTLE_OVER"
	EventBus.emit_signal("battle_phase_changed", phase_name)

	match _current_battle_phase:
		Phases.START_OF_TURN: _enter_start_of_turn_phase()
		Phases.MANAGEMENT: pass
		Phases.COMBAT: await _enter_combat_phase()
		Phases.END_OF_TURN: _enter_end_of_turn_phase()

func _enter_start_of_turn_phase():
	_gacha_tokens = 5
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	_change_phase(Phases.MANAGEMENT)
	return

func _enter_combat_phase():
	await _execute_combat_resolution()
	_change_phase(Phases.END_OF_TURN)

func _enter_end_of_turn_phase():
	if _is_battle_over():
		_current_battle_phase = Phases.BATTLE_OVER
		var did_player_win = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).is_empty()
		WindowManager.open_end_battle_popup(did_player_win)
	else:
		_change_phase(Phases.START_OF_TURN)

func _execute_combat_resolution():
	# --- Player attacks ---
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for attacker in player_lineup:
		var target = _get_frontmost_target(true)
		if is_instance_valid(attacker) and is_instance_valid(target):
			var ability_def = attacker.get_ability(0)
			if ability_def: AbilityResolver.execute_effect(ability_def.effect, attacker, [target], self)
			_check_for_deaths()
			if _is_battle_over(): return
			await get_tree().create_timer(0.5).timeout
		else:
			break # No more valid targets

	if _is_battle_over(): return

	# --- Enemy attacks ---
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for attacker in enemy_lineup:
		var target = _get_frontmost_target(false)
		if is_instance_valid(attacker) and is_instance_valid(target):
			var ability_def = attacker.get_ability(0)
			if ability_def: AbilityResolver.execute_effect(ability_def.effect, attacker, [target], self)
			_check_for_deaths()
			if _is_battle_over(): return
			await get_tree().create_timer(0.5).timeout
		else:
			break # No more valid targets

func _check_for_deaths():
	var dead_uuids = []
	for instance in _battle_instances.values():
		if instance.current_hp <= 0:
			dead_uuids.append(instance.ball_uuid)
	
	for uuid in dead_uuids:
		var instance = get_instance(uuid)
		if is_instance_valid(instance):
			instance.location_container_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			instance.location_slot_index = -1 # Slot index is irrelevant in discard
			
	EventBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	var player_hero = _get_player_hero()
	var player_hero_defeated = not is_instance_valid(player_hero) or player_hero.current_hp <= 0
	var all_enemies_defeated = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).is_empty()
	return all_enemies_defeated or player_hero_defeated

func _on_inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	print("--- Inventory Action Requested ---")
	print("Source: ", source_loc.container, "[", source_loc.index, "]")
	print("Target: ", target_loc.container, "[", target_loc.index, "]")
	var source_container = get_container(source_loc.container)
	var target_container = get_container(target_loc.container)
	
	if not is_instance_valid(source_container) or not is_instance_valid(target_container):
		printerr("BattleManager: Invalid container in inventory action request.")
		return

	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)

	# Swap the UUIDs in the data containers
	source_container.set_uuid(source_loc.index, target_uuid)
	target_container.set_uuid(target_loc.index, source_uuid)

	# Update the instance locations
	var source_instance = get_instance(source_uuid)
	var target_instance = get_instance(target_uuid)

	if is_instance_valid(source_instance):
		source_instance.location_container_tag = target_loc.container
		source_instance.location_slot_index = target_loc.index

	if is_instance_valid(target_instance):
		target_instance.location_container_tag = source_loc.container
		target_instance.location_slot_index = source_loc.index

	# Tell the view to redraw everything
	EventBus.emit_signal("battle_inventory_changed")


	# --- EventBus Signal Handlers ---
func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.COMBAT)

func _on_unit_inventory_changed():
	for instance in _battle_instances.values():
		var def: GachaBallDefinition = instance.get_definition()
		if not is_instance_valid(def):
			continue
		if def.category == &"UNIT":
			instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int):
	print("--- Draw Gacha Requested ---")
	print("Tier: ", tier, " | Current Tokens: ", _gacha_tokens)
	var cost = tier
	if _gacha_tokens < cost:
		return

	var container_tag: StringName = StringName("BattleInventoryT%d" % tier)
	var tier_pool = get_instances_in_container(container_tag)
	if tier_pool.is_empty():
		_reshuffle_discard_pile(tier)
		tier_pool = get_instances_in_container(container_tag)
		if tier_pool.is_empty():
			print("Draw failed: No instances of tier %d available even after reshuffle" % tier)
			EventBus.emit_signal("battle_inventory_changed")
			return

	var drawn_instance = tier_pool.pick_random()

	# Deduct tokens now that we have confirmed a valid instance to draw
	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

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
			drawn_instance.location_container_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			EventBus.emit_signal("battle_inventory_changed")
			return

	# Remove the UUID from the inventory slot now that the instance is leaving it
	var prev_container := get_container(drawn_instance.location_container_tag)
	var prev_index: int = drawn_instance.location_slot_index
	if is_instance_valid(prev_container) and prev_index >= 0:
		prev_container.set_uuid(prev_index, "")

	# Place the instance into its new container and record the UUID there as well
	var target_container := get_container(target_container_tag)
	var empty_slot := target_container.find_first_empty_slot()
	if empty_slot != -1 and empty_slot < target_container_capacity:
		drawn_instance.location_container_tag = target_container_tag
		drawn_instance.location_slot_index = empty_slot
		target_container.set_uuid(empty_slot, drawn_instance.ball_uuid)
	else:
		drawn_instance.location_container_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
		var discard_c := get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
		if is_instance_valid(discard_c):
			var discard_slot := discard_c.find_first_empty_slot()
			if discard_slot == -1:
				discard_slot = discard_c.get_all_uuids().size()
			discard_c.set_uuid(discard_slot, drawn_instance.ball_uuid)

	EventBus.emit_signal("battle_inventory_changed")

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var discard_pile = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var tier_in_discard = discard_pile.filter(func(inst): return inst.get_definition().tier == tier_to_reshuffle)
		
	for instance in tier_in_discard:
		var tier_container_tag := StringName("BattleInventoryT%d" % tier_to_reshuffle)
		instance.location_container_tag = tier_container_tag
	
	if not tier_in_discard.is_empty():
		EventBus.emit_signal("battle_inventory_changed")

func _get_frontmost_target(attacker_is_player: bool) -> GachaBallInstance:
	var target_lineup_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var target_lineup = get_instances_in_container(target_lineup_tag)
	
	if attacker_is_player:
		# Player attacks enemy, scan 0 -> N
		for unit in target_lineup:
			if unit.current_hp > 0: return unit
	else:
		# Enemy attacks player, scan N -> 0
		var reversed_lineup = target_lineup.duplicate()
		reversed_lineup.reverse()
		for unit in reversed_lineup:
			if unit.current_hp > 0: return unit
	
	return null
