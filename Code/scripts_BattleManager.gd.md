<!-- Original: scripts/BattleManager.gd -->

```gdscript
# res://scripts/BattleManager.gd
extends Node
class_name BattleManager

# --- Constants ---
const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")
const BATTLE_INVENTORY_TIER_SIZE = 16
const DISCARD_PILE_INITIAL_SIZE = 16
const GRID_GROWTH_AMOUNT = 4
const PLAYER_LINEUP_SIZE = 6
const PLAYER_BENCH_SIZE = 3
const PLAYER_ITEM_SIZE = 3
const ENEMY_LINEUP_SIZE = 6

# --- TDD Update: Battle State Machine ---
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN }
var _current_battle_phase: Phases

# --- UI Node References ---
@onready var lineup_container: HBoxContainer = get_owner().get_node("%PlayerLineup")
@onready var bench_container: HBoxContainer = get_owner().get_node("%PlayerBench")
@onready var item_container: HBoxContainer = get_owner().get_node("%ItemInventory")
@onready var enemy_lineup_container: HBoxContainer = get_owner().get_node("%EnemyLineupContainer")
@onready var discard_pile_button: Button = get_owner().get_node("%DiscardPileButton")
@onready var end_turn_button: Button = get_owner().get_node("%EndTurnButton")
@onready var gacha_token_label: Label = get_owner().get_node("%GachaTokenLabel")

var lineup_slots: Array[Node]
var bench_slots: Array[Node]
var item_slots: Array[Node]
var enemy_lineup_slots: Array[Node]

# --- Data-Driven State ---
var lineup_data: Array[GachaBallInstance]
var bench_data: Array[GachaBallInstance]
var item_data: Array[GachaBallInstance]
var _enemy_lineup_data: Array[GachaBallInstance]

var _battle_inventory: Dictionary = {0: [], 1: [], 2: [], 3: []}
var _draw_pools: Dictionary = {1: [], 2: [], 3: []}
var _discard_pile: Array[GachaBallInstance]
var _gacha_tokens: int = 0

func _ready():
	add_to_group("battle_manager")
	
	lineup_slots = lineup_container.get_children()
	bench_slots = bench_container.get_children()
	item_slots = item_container.get_children()
	enemy_lineup_slots = enemy_lineup_container.get_children()
	
	lineup_data.resize(PLAYER_LINEUP_SIZE)
	lineup_data.fill(null)
	bench_data.resize(PLAYER_BENCH_SIZE)
	bench_data.fill(null)
	item_data.resize(PLAYER_ITEM_SIZE)
	item_data.fill(null)
	_enemy_lineup_data.resize(ENEMY_LINEUP_SIZE)
	_enemy_lineup_data.fill(null)
	
	_connect_signals()
	_setup_battle()
	
	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	
	_change_phase(Phases.START_OF_TURN)

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)

func _connect_signals():
	discard_pile_button.pressed.connect(EventBus.display_discard_pile_requested.emit)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.battle_inventory_changed.connect(_redraw_board)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	EventBus.gacha_tokens_changed.connect(_update_gacha_token_label)

func _setup_battle():
	var all_instances_map: Dictionary = {}

	for i in range(1, 4):
		_battle_inventory[i].resize(BATTLE_INVENTORY_TIER_SIZE)
		_battle_inventory[i].fill(null)
	_discard_pile.resize(DISCARD_PILE_INITIAL_SIZE)
	_discard_pile.fill(null)

	var hero_run_instance: GachaBallInstance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_run_instance):
		var hero_battle_copy = hero_run_instance.create_battle_copy()
		lineup_data[0] = hero_battle_copy
		all_instances_map[hero_battle_copy.ball_uuid] = hero_battle_copy

	for tier in GameManager.run_state.run_inventory:
		for instance in GameManager.run_state.run_inventory[tier]:
			if is_instance_valid(instance):
				var battle_copy = instance.create_battle_copy()
				all_instances_map[battle_copy.ball_uuid] = battle_copy
				var empty_slot_idx = _battle_inventory[tier].find(null)
				if empty_slot_idx != -1:
					_battle_inventory[tier][empty_slot_idx] = battle_copy
				else:
					printerr("BattleManager: No space in battle inventory for initial items.")
				_draw_pools[tier].append(battle_copy)
	
	_setup_enemy_lineup(all_instances_map)
			
	EventBus.emit_signal("battle_inventory_changed")

func _setup_enemy_lineup(all_instances_map: Dictionary):
	var enemy_unit_ids = ["enemy_hero", "unit_t1_a", "unit_t1_b", "unit_t2_c", "unit_t3_d"]
	var all_item_defs = Database.items.values()

	for i in range(min(enemy_unit_ids.size(), ENEMY_LINEUP_SIZE)):
		var unit_id = enemy_unit_ids[i]
		var unit_def = Database.units.get(unit_id)
		if unit_def:
			var enemy_instance = GachaBallInstance.new()
			enemy_instance.initialize(unit_def)
			all_instances_map[enemy_instance.ball_uuid] = enemy_instance
			
			for j in range(unit_def.item_slot_count):
				if not all_item_defs.is_empty():
					var item_def = all_item_defs.pick_random()
					var item_instance = GachaBallInstance.new()
					item_instance.initialize(item_def)
					enemy_instance.equipped_item_uuids[j] = item_instance.ball_uuid
					all_instances_map[item_instance.ball_uuid] = item_instance
			
			# This now passes the complete, locally-built map
			enemy_instance.recalculate_stats(all_instances_map)
			_enemy_lineup_data[i] = enemy_instance

func _redraw_board():
	if not is_inside_tree(): return
	
	_populate_slots_from_data(lineup_slots, lineup_data, "PlayerLineup")
	_populate_slots_from_data(bench_slots, bench_data, "PlayerBench")
	_populate_slots_from_data(item_slots, item_data, "ItemInventory")
	_populate_slots_from_data(enemy_lineup_slots, _enemy_lineup_data, "EnemyLineup")
	
	_update_discard_pile_ui()

func _populate_slots_from_data(slots: Array, data: Array, container_name: StringName):
	for i in range(slots.size()):
		var slot_node = slots[i]
		var instance_data = data[i]
		
		for child in slot_node.get_children():
			child.queue_free()
			
		if is_instance_valid(instance_data):
			var view = GACHA_BALL_VIEW_SCENE.instantiate()
			slot_node.add_child(view)
			view.set_instance_data(instance_data)
			view.initialize(-1, i, container_name)
			instance_data.set_meta("view_node", view)
		elif container_name != "EnemyLineup":
			var slot_view = SLOT_VIEW_SCENE.instantiate()
			slot_node.add_child(slot_view)
			slot_view.initialize(-1, i, container_name)

func _change_phase(new_phase: Phases):
	_current_battle_phase = new_phase
	var phase_name = StringName(Phases.keys()[new_phase])
	EventBus.emit_signal("battle_phase_changed", phase_name)
	print("Entering phase: ", phase_name)
	
	match _current_battle_phase:
		Phases.START_OF_TURN:
			_enter_start_of_turn_phase()
		Phases.MANAGEMENT:
			_enter_management_phase()
		Phases.COMBAT:
			_enter_combat_phase()
		Phases.END_OF_TURN:
			_enter_end_of_turn_phase()

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

func _execute_combat_resolution():
	print("Executing combat...")
	var basic_attack_def = Database.abilities.get("basic_attack")
	if not basic_attack_def:
		printerr("BasicAttack ability not found in Database.")
		return
	var basic_attack_effect = basic_attack_def.effect

	var all_actors = lineup_data + _enemy_lineup_data
	for i in range(all_actors.size() - 1, -1, -1):
		var attacker = all_actors[i]
		if is_instance_valid(attacker) and attacker.current_hp > 0:
			var is_player_unit = lineup_data.has(attacker)
			var opposing_lineup = _enemy_lineup_data if is_player_unit else lineup_data
			var target = null
			for unit in opposing_lineup:
				if is_instance_valid(unit) and unit.current_hp > 0:
					target = unit
					break
			if is_instance_valid(target):
				AbilityResolver.execute_effect(basic_attack_effect, attacker, [target], self)
	
	_check_for_deaths()

func _check_for_deaths():
	var unit_defeated = false
	for i in range(lineup_data.size()):
		var unit = lineup_data[i]
		if is_instance_valid(unit) and unit.current_hp <= 0:
			_add_to_discard_pile(unit)
			lineup_data[i] = null
			unit_defeated = true
	
	for i in range(_enemy_lineup_data.size()):
		var unit = _enemy_lineup_data[i]
		if is_instance_valid(unit) and unit.current_hp <= 0:
			_enemy_lineup_data[i] = null
			unit_defeated = true
	
	if unit_defeated:
		EventBus.emit_signal("battle_inventory_changed")

func _enter_end_of_turn_phase():
	var all_enemies_defeated = _enemy_lineup_data.all(func(unit): return not is_instance_valid(unit))
	var player_hero_defeated = not is_instance_valid(lineup_data[0]) or lineup_data[0].current_hp <= 0

	if all_enemies_defeated:
		print("VICTORY!")
		get_tree().quit()
	elif player_hero_defeated:
		print("DEFEAT!")
		get_tree().quit()
	else:
		_change_phase(Phases.START_OF_TURN)

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
	var drawn_instance = pool.pick_random()
	pool.erase(drawn_instance)
	
	var definition = Database.get_definition(drawn_instance.definition_id)

	if _battle_inventory.has(definition.tier):
		var master_grid = _battle_inventory[definition.tier]
		var idx = master_grid.find(drawn_instance)
		if idx != -1:
			master_grid[idx] = null

	var empty_slot_found = false
	if definition.category == "UNIT":
		var bench_idx = bench_data.find(null)
		if bench_idx != -1:
			bench_data[bench_idx] = drawn_instance
			empty_slot_found = true
	else: # ITEM
		var item_idx = item_data.find(null)
		if item_idx != -1:
			item_data[item_idx] = drawn_instance
			empty_slot_found = true
			
	if not empty_slot_found:
		_add_to_discard_pile(drawn_instance)

	EventBus.emit_signal("battle_inventory_changed")

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var items_to_move = []
	for instance in _discard_pile:
		if is_instance_valid(instance):
			var def = Database.get_definition(instance.definition_id)
			if def and def.tier == tier_to_reshuffle:
				items_to_move.append(instance)
	
	if items_to_move.is_empty(): return

	for instance in items_to_move:
		_draw_pools[tier_to_reshuffle].append(instance)
		var idx = _discard_pile.find(instance)
		if idx != -1:
			_discard_pile[idx] = null
	
	_update_discard_pile_ui()

func _add_to_discard_pile(instance: GachaBallInstance):
	var discard_idx = _discard_pile.find(null)
	if discard_idx != -1:
		_discard_pile[discard_idx] = instance
	else:
		var old_size = _discard_pile.size()
		_discard_pile.resize(old_size + GRID_GROWTH_AMOUNT)
		_discard_pile[old_size] = instance
	_update_discard_pile_ui()

func _update_discard_pile_ui():
	var discard_count = _discard_pile.filter(func(x): return x != null).size()
	discard_pile_button.text = "Discard Pile (%d)" % discard_count

func get_data_array_and_instance(container_name: StringName, index: int) -> Dictionary:
	var data_array: Array
	match container_name:
		"PlayerLineup": data_array = lineup_data
		"PlayerBench": data_array = bench_data
		"ItemInventory": data_array = item_data
		"EnemyLineup": data_array = _enemy_lineup_data
	
	if not data_array.is_empty() and index >= 0 and index < data_array.size():
		return { "array": data_array, "instance": data_array[index] }
	return { "array": null, "instance": null }

func set_slot_data(container_name: StringName, index: int, instance: GachaBallInstance):
	var data_array = get_data_array_and_instance(container_name, index).array
	if data_array != null:
		data_array[index] = instance
		EventBus.emit_signal("battle_inventory_changed")

func get_battle_inventory() -> Dictionary:
	return _battle_inventory

func get_discard_pile() -> Array[GachaBallInstance]:
	return _discard_pile.filter(func(x): return x != null)

func get_full_inventory_context() -> Dictionary:
	return {
		"is_battle": true,
		"battle_inventory": _battle_inventory,
		"lineup_data": lineup_data,
		"bench_data": bench_data,
		"item_data": item_data,
	}

```