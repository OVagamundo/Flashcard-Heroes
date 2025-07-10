<!-- Original: scripts/BattleManager.gd -->

```gdscript
# res://scripts/BattleManager.gd
extends Node
class_name BattleManager



# --- TDD: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

# --- TDD: Data-Driven State ---
# Master registry for all temporary battle instances (player and enemy)
var _battle_instances: Dictionary = {} # Key: ball_uuid (String), Value: GachaBallInstance
# Registry for all temporary battle containers
var _data_containers: Dictionary = {} # Key: container_name (StringName), Value: DataContainer

var _gacha_tokens: int = 0
var _draw_pools: Dictionary = { 1: [], 2: [], 3: [] } # Stores UUIDs for drawing

# --- UI Node References ---
@onready var end_turn_button: Button = get_owner().get_node("%EndTurnButton")
@onready var gacha_token_label: Label = get_owner().get_node("%GachaTokenLabel")
@onready var discard_pile_button: Button = get_owner().get_node("%DiscardPileButton")

func _ready():
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

func _connect_signals():
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	discard_pile_button.pressed.connect(EventBus.display_discard_pile_requested.emit)

# --- Public API for Managers ---
func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_all_instances() -> Dictionary:
	return _battle_instances

func get_container(container_name: StringName) -> DataContainer:
	return _data_containers.get(container_name)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# Case 1: The location refers to an item equipped on another unit.
	if loc.container == &"equipped_item":
		var owner_unit = get_instance(loc.unit_uuid)
		if is_instance_valid(owner_unit):
			# This requires GachaBallInstance to have a helper function.
			var item_uuid = owner_unit.get_equipped_item_uuid_at_index(loc.index)
			return get_instance(item_uuid)
		return null

	# Case 2: The location refers to a standard data container.
	if _data_containers.has(loc.container):
		var container = _data_containers[loc.container]
		var uuid = container.get_uuid(loc.index)
		return get_instance(uuid)

	return null

# --- Battle Setup ---
func _setup_battle():
	# 1. Initialize all temporary DataContainers as per TDD
	_data_containers[&"PlayerLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"PlayerBench"] = FixedArrayContainer.new(3)
	_data_containers[&"ItemInventory"] = FixedArrayContainer.new(3)
	_data_containers[&"EnemyLineup"] = FixedArrayContainer.new(6)
	_data_containers[&"BattleInventoryT1"] = GrowableGridContainer.new(16)
	_data_containers[&"BattleInventoryT2"] = GrowableGridContainer.new(16)
	_data_containers[&"BattleInventoryT3"] = GrowableGridContainer.new(16)
	_data_containers[&"DiscardPile"] = GrowableGridContainer.new(16)

	# 2. Create battle copies of player's persistent hero and inventory
	var player_hero_copy = GameManager.run_state.hero_instance.create_battle_copy()
	_battle_instances[player_hero_copy.ball_uuid] = player_hero_copy
	_data_containers[&"PlayerLineup"].set_uuid(0, player_hero_copy.ball_uuid)

	for instance_uuid in GameManager.run_state.run_instances:
		var permanent_instance = GameManager.run_state.run_instances[instance_uuid]
		if is_instance_valid(permanent_instance):
			var battle_copy = permanent_instance.create_battle_copy()
			_battle_instances[battle_copy.ball_uuid] = battle_copy
			
			print("BattleManager: Processing battle_copy ", battle_copy.ball_uuid, ", origin ", battle_copy.origin_uuid)
			var def = battle_copy.get_definition()
			if not is_instance_valid(def):
				printerr("BattleManager: Definition is null for battle_copy ", battle_copy.ball_uuid, ", origin ", battle_copy.origin_uuid, ", definition_id ", battle_copy.definition_id)
				return # Exit early if definition is null to prevent further errors
			var container_name = &"BattleInventoryT%d" % def.tier
			var container = _data_containers[container_name]
			var empty_idx = container.find_first_empty_slot()
			container.set_uuid(empty_idx, battle_copy.ball_uuid)
			
			# Populate draw pools
			_draw_pools[def.tier].append(battle_copy.ball_uuid)

	# 3. Setup the enemy lineup
	_setup_enemy_lineup()
	
	# 4. Recalculate stats for all units now that they are all created
	for instance in _battle_instances.values():
		if instance.get_definition().category == &"UNIT":
			instance.recalculate_stats(_battle_instances)

func _setup_enemy_lineup():
	var enemy_unit_ids = [&"enemy_hero", &"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d"]
	var all_item_defs = Database.items.values()
	var enemy_lineup = _data_containers[&"EnemyLineup"]

	for i in range(min(enemy_unit_ids.size(), 6)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if unit_def:
			var enemy_instance = GachaBallInstance.new()
			enemy_instance.initialize(unit_def)
			_battle_instances[enemy_instance.ball_uuid] = enemy_instance
			
			# Equip items
			for j in range(enemy_instance.equipped_item_uuids.size()):
				if not all_item_defs.is_empty():
					var item_def = all_item_defs.pick_random()
					var item_instance = GachaBallInstance.new()
					item_instance.initialize(item_def)
					_battle_instances[item_instance.ball_uuid] = item_instance
					enemy_instance.equipped_item_uuids[j] = item_instance.ball_uuid
			
			enemy_lineup.set_uuid(i, enemy_instance.ball_uuid)

# --- State Machine Logic ---
func _change_phase(new_phase: Phases):
	if _current_battle_phase == Phases.BATTLE_OVER: return

	_current_battle_phase = new_phase
	var phase_name = StringName(Phases.keys()[new_phase])
	EventBus.emit_signal("battle_phase_changed", phase_name)
	print("BattleManager: Entering phase -> ", phase_name)
	
	match _current_battle_phase:
		Phases.START_OF_TURN: _enter_start_of_turn_phase()
		Phases.MANAGEMENT: _enter_management_phase()
		Phases.COMBAT: _enter_combat_phase()
		Phases.END_OF_TURN: _enter_end_of_turn_phase()

func _enter_start_of_turn_phase():
	_gacha_tokens += 5
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	_change_phase(Phases.MANAGEMENT)

func _enter_management_phase():
	end_turn_button.disabled = false

func _enter_combat_phase():
	end_turn_button.disabled = true
	_execute_combat_resolution()
	_change_phase(Phases.END_OF_TURN)

func _enter_end_of_turn_phase():
	var all_enemies_defeated = _data_containers[&"EnemyLineup"].get_all_uuids().all(func(uuid): return not is_instance_valid(_battle_instances[uuid]))
	var player_hero_defeated = not is_instance_valid(_battle_instances[_data_containers[&"PlayerLineup"].get_uuid(0)]) or _battle_instances[_data_containers[&"PlayerLineup"].get_uuid(0)].current_hp <= 0

	if all_enemies_defeated:
		WindowManager.open_end_battle_popup(true)
	elif player_hero_defeated:
		WindowManager.open_end_battle_popup(false)
	else:
		_change_phase(Phases.START_OF_TURN)

func _execute_combat_resolution():
	print("--- COMBAT PHASE START ---")
	var basic_attack_def = Database.abilities.get(&"basic_attack")
	if not basic_attack_def:
		printerr("BasicAttack ability not found in Database.")
		return

	var player_lineup_uuids = _data_containers[&"PlayerLineup"].get_all_uuids()
	var enemy_lineup_uuids = _data_containers[&"EnemyLineup"].get_all_uuids()

	# --- PLAYER TEAM'S TURN (Front-to-Back: Index 0 -> 5) ---
	print("Player team acts...")
	for i in range(player_lineup_uuids.size()):
		var attacker_uuid = player_lineup_uuids[i]
		var attacker = _battle_instances.get(attacker_uuid)
		if not is_instance_valid(attacker) or attacker.current_hp <= 0:
			continue

		var target = _get_target_by_rule(true, &"Frontmost")
		if is_instance_valid(target):
			AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], _battle_instances)
			_check_for_deaths()
			await get_tree().create_timer(0.5).timeout
		else:
			break # All enemies are defeated

	# --- ENEMY TEAM'S TURN (Back-to-Front: Index 5 -> 0) ---
	print("Enemy team acts...")
	for i in range(enemy_lineup_uuids.size() - 1, -1, -1):
		var attacker_uuid = enemy_lineup_uuids[i]
		var attacker = _battle_instances.get(attacker_uuid)
		if not is_instance_valid(attacker) or attacker.current_hp <= 0:
			continue

		var target = _get_target_by_rule(false, &"Frontmost")
		if is_instance_valid(target):
			AbilityResolver.execute_effect(basic_attack_def.effect, attacker, [target], _battle_instances)
			_check_for_deaths()
			await get_tree().create_timer(0.5).timeout
		else:
			break # All player units are defeated
		
	print("--- COMBAT PHASE END ---")

func _check_for_deaths():
	var all_uuids = []
	all_uuids.append_array(_data_containers[&"PlayerLineup"].get_all_uuids())
	all_uuids.append_array(_data_containers[&"PlayerBench"].get_all_uuids())
	all_uuids.append_array(_data_containers[&"EnemyLineup"].get_all_uuids())

	for uuid in all_uuids:
		var instance = _battle_instances.get(uuid)
		if is_instance_valid(instance) and instance.current_hp <= 0:
			print("Unit defeated: ", instance.get_definition().id)
			# Remove from current container
			for container_name in _data_containers:
				var container = _data_containers[container_name]
				if container.has_uuid(uuid):
					container.remove_uuid(uuid)
					break
			# Add to discard pile
			_add_to_discard_pile(uuid)

func _on_unit_inventory_changed(unit_uuid: String):
	if not _battle_instances.has(unit_uuid):
		return

	var unit_instance = _battle_instances[unit_uuid]
	if is_instance_valid(unit_instance):
		# Recalculate stats using the battle's master instance registry
		unit_instance.recalculate_stats(_battle_instances)
		# Emit the state change signal for the UI to react to
		EventBus.emit_signal("unit_stats_changed", unit_uuid)
		# Update the UI to reflect any changes
		_redraw_board()

func _redraw_board():
	EventBus.emit_signal("battle_inventory_changed")
	_update_discard_pile_ui()

func _update_discard_pile_ui():
	var discard_count = _data_containers[&"DiscardPile"].get_all_uuids().filter(func(uuid): return uuid != null).size()
	discard_pile_button.text = "Discard Pile (%d)" % discard_count

func _on_end_turn_button_pressed():
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.COMBAT)

func _update_gacha_token_label(new_amount: int):
	gacha_token_label.text = "Tokens: %d" % new_amount

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost:
		print("Not enough tokens to draw tier %d." % tier)
		return
	
	if not _draw_pools.has(tier) or _draw_pools[tier].is_empty():
		_reshuffle_discard_pile(tier)
		if _draw_pools[tier].is_empty():
			print("No items of tier %d in discard to reshuffle." % tier)
			return

	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	var pool = _draw_pools[tier]
	var drawn_uuid = pool.pick_random()
	pool.erase(drawn_uuid)
	
	var drawn_instance = _battle_instances[drawn_uuid]
	var definition = drawn_instance.get_definition()

	if definition.category == "UNIT":
		var bench_idx = _data_containers[&"PlayerBench"].find_first_empty_slot()
		if bench_idx != -1:
			_data_containers[&"PlayerBench"].set_uuid(bench_idx, drawn_uuid)
		else:
			_add_to_discard_pile(drawn_uuid)
	else: # ITEM
		var item_idx = _data_containers[&"ItemInventory"].find_first_empty_slot()
		if item_idx != -1:
			_data_containers[&"ItemInventory"].set_uuid(item_idx, drawn_uuid)
		else:
			_add_to_discard_pile(drawn_uuid)

	EventBus.emit_signal("battle_inventory_changed")

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var items_to_move = []
	for uuid in _data_containers[&"DiscardPile"].get_all_uuids():
		var instance = _battle_instances[uuid]
		if is_instance_valid(instance):
			var def = instance.get_definition()
			if def and def.tier == tier_to_reshuffle:
				items_to_move.append(uuid)
	
	if items_to_move.is_empty(): return

	for uuid in items_to_move:
		_draw_pools[tier_to_reshuffle].append(uuid)
		_data_containers[&"DiscardPile"].set_uuid(_data_containers[&"DiscardPile"].get_all_uuids().find(uuid), null)
	
	_update_discard_pile_ui()

func _add_to_discard_pile(uuid: String):
	var discard_idx = _data_containers[&"DiscardPile"].find_first_empty_slot()
	if discard_idx != -1:
		_data_containers[&"DiscardPile"].set_uuid(discard_idx, uuid)
	else:
		var old_size = _data_containers[&"DiscardPile"].get_size()
		_data_containers[&"DiscardPile"].resize(old_size + 4)
		_data_containers[&"DiscardPile"].set_uuid(old_size, uuid)
		
	_update_discard_pile_ui()
	return null # No valid target found

func get_data_array_and_instance(container_name: StringName, index: int) -> Dictionary:
	var data_array: Array
	match container_name:
		"PlayerLineup": data_array = _data_containers[&"PlayerLineup"].get_all_uuids()
		"PlayerBench": data_array = _data_containers[&"PlayerBench"].get_all_uuids()
		"ItemInventory": data_array = _data_containers[&"ItemInventory"].get_all_uuids()
		"EnemyLineup": data_array = _data_containers[&"EnemyLineup"].get_all_uuids()
	
	if not data_array.is_empty() and index >= 0 and index < data_array.size():
		return { "array": data_array, "instance": _battle_instances[data_array[index]] }
	return { "array": null, "instance": null }

func set_slot_data(container_name: StringName, index: int, uuid: String):
	var data_array = get_data_array_and_instance(container_name, index).array
	if data_array != null:
		data_array[index] = uuid
		EventBus.emit_signal("battle_inventory_changed")

func get_battle_inventory() -> Dictionary:
	var inventory = {}
	for container_name in [&"BattleInventoryT1", &"BattleInventoryT2", &"BattleInventoryT3"]:
		inventory[container_name] = _data_containers[container_name].get_all_uuids()
	return inventory

func get_discard_pile() -> Array[String]:
	return _data_containers[&"DiscardPile"].get_all_uuids()

func get_full_inventory_context() -> Dictionary:
	return {
		"is_battle": true,
		"battle_inventory": get_battle_inventory(),
		"lineup_data": _data_containers[&"PlayerLineup"].get_all_uuids(),
		"bench_data": _data_containers[&"PlayerBench"].get_all_uuids(),
		"item_data": _data_containers[&"ItemInventory"].get_all_uuids(),
	}

# --- NEW: Abstract Targeting Helpers ---

func _get_opposing_lineup(is_player_unit: bool) -> Array[String]:
	return _data_containers[&"EnemyLineup"].get_all_uuids() if is_player_unit else _data_containers[&"PlayerLineup"].get_all_uuids()

func _get_target_by_rule(is_player_unit: bool, rule: StringName) -> GachaBallInstance:
	var opposing_lineup = _get_opposing_lineup(is_player_unit)
	
	match rule:
		&"Frontmost":
			# For the player attacking, the enemy's front is at index 0.
			# For the enemy attacking, the player's front is at index 5.
			if is_player_unit: # Player is attacking
				for uuid in opposing_lineup: # Iterate 0 -> 5
					if is_instance_valid(_battle_instances[uuid]) and _battle_instances[uuid].current_hp > 0:
						return _battle_instances[uuid]
				for unit in opposing_lineup: # Iterate 0 -> 5
					if is_instance_valid(unit) and unit.current_hp > 0:
						return unit
			else: # Enemy is attacking
				for i in range(opposing_lineup.size() - 1, -1, -1): # Iterate 5 -> 0
					var unit = opposing_lineup[i]
					if is_instance_valid(unit) and unit.current_hp > 0:
						return unit
						
		# We can add more rules here later, like "Backmost", "LowestHP", etc.
		
	return null # No valid target found

```