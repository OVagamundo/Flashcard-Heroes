extends Node
class_name BattleManager

const RS = preload("res://scripts/RunState.gd")

# --- TDD: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

# --- TDD: Effect Resolution Queue ---
var _effect_queue: Array[EffectRequest] = []
var _is_processing_effect: bool = false

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
	_effect_queue.clear()
	_gacha_tokens = 5

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
		# This is a simple way to ensure only one manager is active.
		# The first one to _ready() wins.
		var is_first = true
		for node in existing:
			if node != self:
				is_first = false
				break
		if not is_first:
			queue_free()
			return
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
	if container_name.begins_with("BattleInventoryT") or container_name == BATTLE_CONTAINER_TAGS.PLAYER_BENCH or container_name == BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
		default_size = 3
	
	var new_container = ArrayContainer.new(default_size)
	_containers[container_name] = new_container
	return new_container

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	for instance in _battle_instances.values():
		if instance.location_container_tag == container_tag:
			result.append(instance)
	# Sort by slot index for predictable order
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
		var item_owner = get_instance(loc.unit_uuid)
		if is_instance_valid(item_owner):
			var item_uuid = item_owner.get_equipped_item_uuid(loc.index)
			return get_instance(item_uuid)
		return null

	var container = get_container(loc.container)
	if not is_instance_valid(container):
		return null
	
	var uuid = container.get_uuid(loc.index)
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
	var inventory := {
		1: [],
		2: [],
		3: []
	}
	for i in range(1, 4):
		inventory[i].resize(16)
		inventory[i].fill(null)

	for instance in _battle_instances.values():
		var container_tag = instance.location_container_tag
		if container_tag.begins_with("BattleInventoryT"):
			var tier = instance.get_definition().tier
			var slot = instance.location_slot_index
			if inventory.has(tier) and slot >= 0 and slot < inventory[tier].size():
				inventory[tier][slot] = instance
		
	return inventory

func _setup_enemy_lineup():
	# Order: front (0) -> back (4). Place hero at the rear.
	var enemy_unit_ids = [&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d", &"enemy_hero"]
	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if not is_instance_valid(unit_def):
			printerr("Failed to find enemy definition: ", enemy_unit_ids[i])
			continue
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		_battle_instances[enemy_inst.ball_uuid] = enemy_inst
		var lineup_c = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		lineup_c.set_uuid(i, enemy_inst.ball_uuid)
		enemy_inst.location_container_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		enemy_inst.location_slot_index = i

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

	# Execute logic for the new phase
	match _current_battle_phase:
		Phases.START_OF_TURN:
			_gacha_tokens += 5
			EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			_populate_effect_queue()
			_process_effect_queue()
		Phases.END_OF_TURN:
			# The turn is over. The game will now wait in the MANAGEMENT phase for the player
			# to press the 'End Turn' button.
			pass

func _check_for_battle_end():
	if _is_battle_over():
		_current_battle_phase = Phases.BATTLE_OVER
		var did_player_win = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).is_empty()
		WindowManager.open_end_battle_popup(did_player_win)
	else:
		# After checking for battle end, if the battle is not over, we should be in the MANAGEMENT phase.
		# The _process_effect_queue already handles this transition, so we don't need to do anything here.
		pass

func _populate_effect_queue():
	_effect_queue.clear()
	# --- Enemy attacks ---
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for attacker in enemy_lineup:
		var target = _get_frontmost_target(false)
		if is_instance_valid(target):
			var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", {"target_uuid": target.ball_uuid})
			_effect_queue.append(request)

	# --- Player attacks ---
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for attacker in player_lineup:
		var target = _get_frontmost_target(true)
		if is_instance_valid(target):
			var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", {"target_uuid": target.ball_uuid})
			_effect_queue.append(request)


func _process_effect_queue() -> void:
	if _is_processing_effect: return
	if _effect_queue.is_empty():
		_change_phase(Phases.MANAGEMENT)
		return

	_is_processing_effect = true

	while not _effect_queue.is_empty():
		var request: EffectRequest = _effect_queue.pop_back()
		var source = get_instance(request.source_uuid)
		var target = get_instance(request.trigger_context.get("target_uuid"))

		# If original target is missing or already dead, pick a new front-most living target.
		if not is_instance_valid(target) or target.current_hp <= 0:
			var attacker_is_player: bool = source.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
			target = _get_frontmost_target(attacker_is_player)
			# If no valid target remains, skip this request.
			if not is_instance_valid(target):
				continue

		if not is_instance_valid(source):
			continue

		var ability_def = Database.get_ability_definition(request.ability_id)
		if not is_instance_valid(ability_def):
			printerr("Could not find ability definition for: ", request.ability_id)
			continue

		var message = "[b]%s[/b] uses [b]%s[/b] on [b]%s[/b]" % [tr(source.get_definition().display_name_key), tr(ability_def.name_key), tr(target.get_definition().display_name_key)]
		EventBus.emit_signal("battle_log_event", message)

		ability_def.effect.execute(source, [target], self)

		_check_for_deaths()
		EventBus.emit_signal("battle_inventory_changed")

		if _is_battle_over():
			break

		await get_tree().create_timer(0.8).timeout

	_is_processing_effect = false
	_change_phase(Phases.END_OF_TURN)
	await get_tree().create_timer(0.1).timeout
	_change_phase(Phases.MANAGEMENT)

# Helper to remove a uuid from its current container array
func _remove_instance_from_container(instance: GachaBallInstance) -> void:
	var container = get_container(instance.location_container_tag)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx := uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")

func _check_for_deaths():
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in all_units:
		if unit.current_hp <= 0:
			_remove_instance_from_container(unit)
			unit.location_container_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			EventBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	return player_lineup.is_empty() or enemy_lineup.is_empty()


	# --- EventBus Signal Handlers ---
func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.START_OF_TURN)

func _on_unit_inventory_changed():
	for instance in _battle_instances.values():
		var def: GachaBallDefinition = instance.get_definition()
		if not is_instance_valid(def):
			continue
		if def.category == &"UNIT":
			instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost:
		return

	var container_tag: StringName = StringName("BattleInventoryT%d" % tier)
	var tier_pool = get_instances_in_container(container_tag)
	if tier_pool.is_empty():
		_reshuffle_discard_pile(tier)
		tier_pool = get_instances_in_container(container_tag)
		if tier_pool.is_empty():
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

	# Filter out dead units first
	var living_targets = target_lineup.filter(func(unit): return unit.current_hp > 0)

	if living_targets.is_empty():
		return null

	# TDD: Player attacks front-most enemy (lowest index).
	# TDD: Enemy attacks front-most player unit (which is the highest index in the player lineup array).
	if attacker_is_player:
		return living_targets[0]
	else:
		return living_targets[-1]
