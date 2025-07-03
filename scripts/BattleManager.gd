# res://scripts/BattleManager.gd
extends Node
class_name BattleManager

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const SLOT_VIEW_SCENE = preload("res://scenes/SlotView.tscn")
const BATTLE_INVENTORY_TIER_SIZE = 16 # TDD Compliance: 4x4 grid
const DISCARD_PILE_INITIAL_SIZE = 16 # TDD Compliance: 4x4 grid
const GRID_GROWTH_AMOUNT = 4 # TDD Compliance

# --- UI Node References ---
var lineup_container: HBoxContainer
var bench_container: HBoxContainer
var item_container: HBoxContainer
var discard_pile_button: Button
var reshuffle_button: Button

var lineup_slots: Array[Node]
var bench_slots: Array[Node]
var item_slots: Array[Node]

# --- Data-Driven State ---
# TDD Compliance: These are fixed-size arrays representing board slots.
var lineup_data: Array[GachaBallInstance]
var bench_data: Array[GachaBallInstance]
var item_data: Array[GachaBallInstance]

# TDD Compliance: These are proper data grids, not dynamic arrays.
var _battle_inventory: Dictionary = {0: [], 1: [], 2: [], 3: []}
var _draw_pools: Dictionary = {1: [], 2: [], 3: []}
var _discard_pile: Array[GachaBallInstance]

func _ready():
	# Initialize containers here to avoid @onready timing issues.
	var owner_node = get_owner()
	lineup_container = owner_node.find_child("PlayerLineup", true, false)
	bench_container = owner_node.find_child("PlayerBench", true, false)
	item_container = owner_node.find_child("ItemInventory", true, false)
	reshuffle_button = owner_node.get_node("UI/BattleArea/TeamAreas/EnemyArea/DrawBallArea/DiscardPileArea/ReshuffleButton")
	discard_pile_button = owner_node.find_child("DiscardPileButton", true, false)
	add_to_group("battle_manager")
	
	lineup_slots = lineup_container.get_children()
	bench_slots = bench_container.get_children()
	item_slots = item_container.get_children()
	
	# TDD Compliance: Initialize data arrays to match UI slot counts, filled with nulls.
	lineup_data.resize(lineup_slots.size())
	lineup_data.fill(null)
	bench_data.resize(bench_slots.size())
	bench_data.fill(null)
	item_data.resize(item_slots.size())
	item_data.fill(null)
	
	_connect_signals()
	_setup_battle()
	
	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)

func _exit_tree():
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)

func _connect_signals():
	discard_pile_button.pressed.connect(EventBus.display_discard_pile_requested.emit)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	reshuffle_button.pressed.connect(_on_reshuffle_requested)
	EventBus.battle_inventory_changed.connect(_redraw_board)

func _setup_battle():
	# TDD Compliance: Initialize data grids with nulls.
	for i in range(1, 4):
		_battle_inventory[i].resize(BATTLE_INVENTORY_TIER_SIZE)
		_battle_inventory[i].fill(null)
	_discard_pile.resize(DISCARD_PILE_INITIAL_SIZE)
	_discard_pile.fill(null)

	var hero_run_instance: GachaBallInstance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_run_instance):
		var hero_battle_copy = hero_run_instance.create_battle_copy()
		_battle_inventory[0].append(hero_battle_copy) # Hero is special, not in a grid.
		lineup_data[0] = hero_battle_copy
	
	for tier in GameManager.run_state.run_inventory:
		for instance in GameManager.run_state.run_inventory[tier]:
			if is_instance_valid(instance):
				var battle_copy = instance.create_battle_copy()
				# Place copy into the battle inventory grid
				var empty_slot_idx = _battle_inventory[tier].find(null)
				if empty_slot_idx != -1:
					_battle_inventory[tier][empty_slot_idx] = battle_copy
				else:
					printerr("BattleManager: No space in battle inventory for initial items.")
				
				_draw_pools[tier].append(battle_copy)
			
	EventBus.emit_signal("battle_inventory_changed")

func _redraw_board():
	if not is_inside_tree(): return
	
	# Pass container names for robust view identification.
	_populate_slots_from_data(lineup_slots, lineup_data, "PlayerLineup")
	_populate_slots_from_data(bench_slots, bench_data, "PlayerBench")
	_populate_slots_from_data(item_slots, item_data, "ItemInventory")
	
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
			# Give the view its precise location for the InventoryManager to use.
			view.initialize(-1, i, container_name)
			instance_data.set_meta("view_node", view)
		else:
			# TDD Compliance: Empty slots must be interactable drop targets.
			var slot_view = SLOT_VIEW_SCENE.instantiate()
			slot_node.add_child(slot_view)
			# Give the slot its precise location for the InventoryManager to use.
			slot_view.initialize(-1, i, container_name)

func _on_draw_gacha_requested(tier: int):
	if not _draw_pools.has(tier) or _draw_pools[tier].is_empty(): return
	
	var pool = _draw_pools[tier]
	var drawn_instance = pool.pick_random()
	var definition = Database.units.get(drawn_instance.definition_id, Database.items.get(drawn_instance.definition_id))
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
		var discard_idx = _discard_pile.find(null)
		if discard_idx != -1:
			_discard_pile[discard_idx] = drawn_instance
		else:
			# TDD Compliance: Grow the grid if it's full.
			var old_size = _discard_pile.size()
			_discard_pile.resize(old_size + GRID_GROWTH_AMOUNT)
			_discard_pile.fill(null) # Fill new slots with null
			_discard_pile[old_size] = drawn_instance # Place item in the first new slot.
			print("Discard pile grew to size: ", _discard_pile.size())

	EventBus.emit_signal("battle_inventory_changed")

func _on_reshuffle_requested():
	if reshuffle_button.disabled: return
	
	var items_in_discard = _discard_pile.filter(func(x): return x != null)
	if items_in_discard.is_empty(): return
	
	reshuffle_button.disabled = true
	
	for instance in items_in_discard:
		var definition = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
		if definition and _draw_pools.has(definition.tier):
			_draw_pools[definition.tier].append(instance)
			
	# TDD Compliance: A data grid must be cleared by nullifying its slots.
	_discard_pile.fill(null)
	
	EventBus.emit_signal("battle_inventory_changed")

func _update_discard_pile_ui():
	# TDD Compliance: Count non-null items, as .size() is now the total capacity.
	var discard_count = _discard_pile.filter(func(x): return x != null).size()
	discard_pile_button.text = "Discard Pile (%d)" % discard_count
	# TDD Safeguard: Re-enable reshuffle button after UI update.
	reshuffle_button.disabled = false

# --- Public Data Accessors for InventoryManager ---
func get_data_array_and_instance(container_name: StringName, index: int) -> Dictionary:
	var data_array: Array
	match container_name:
		"PlayerLineup": data_array = lineup_data
		"PlayerBench": data_array = bench_data
		"ItemInventory": data_array = item_data
	
	if not data_array.is_empty() and index >= 0 and index < data_array.size():
		return { "array": data_array, "instance": data_array[index] }
	return { "array": null, "instance": null }

func set_slot_data(container_name: StringName, index: int, instance: GachaBallInstance):
	var result = get_data_array_and_instance(container_name, index)
	var data_array = result.array
	if data_array:
		data_array[index] = instance

# --- Public Getters ---
func get_battle_inventory() -> Dictionary:
	return _battle_inventory

func get_discard_pile() -> Array[GachaBallInstance]:
	return _discard_pile
