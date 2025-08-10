# res://scripts/GameManager.gd
extends Node

const SHOP_SCENE = preload("res://scenes/Shop.tscn")
const REST_SITE_SCENE = preload("res://scenes/RestSite.tscn")

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false # The global authority on whether a battle is active.
var _active_battle_manager: Node = null # ADD THIS LINE
var _temporary_reward_master_dict: Dictionary = {}
var _temporary_reward_container: DataContainer = null # Will hold a FixedArrayContainer for rewards
var _temporary_gold_reward: int = 0
var _is_processing_victory: bool = false # Prevents multiple reward processing

# Temporary shop state
var _temporary_shop_master_dict: Dictionary = {}
var _temporary_shop_container: DataContainer = null
var _reroll_cost: int = 1

# These functions are deprecated - use get_instance_from_location instead

func _ready() -> void:
	# Connect to signals to manage the run and battle state.
	SignalBus.start_run_requested.connect(_on_start_run_requested)
	SignalBus.battle_state_changed.connect(func(in_battle): is_in_battle = in_battle)
	SignalBus.title_scene_requested.connect(_on_return_to_title)
	SignalBus.battle_victory_acknowledged.connect(_on_battle_victory_acknowledged)
	SignalBus.battle_start_requested.connect(_on_battle_start_requested)
	SignalBus.battle_won_rewards_pending.connect(_on_battle_won_rewards_pending)
	SignalBus.battle_ended.connect(_on_battle_ended)

	SignalBus.reward_chosen.connect(_on_reward_chosen)
	SignalBus.node_selected.connect(_on_node_selected)
	SignalBus.shop_purchase_requested.connect(_on_shop_purchase_requested)
	SignalBus.shop_reroll_requested.connect(_on_shop_reroll_requested)

# ADD THESE TWO FUNCTIONS
func register_battle_manager(bm: Node):
	_active_battle_manager = bm

func unregister_battle_manager():
	_active_battle_manager = null

func get_pending_rewards() -> Dictionary:
	return {
		"reward_instances": _temporary_reward_master_dict.values(),
		"gold_amount": _temporary_gold_reward
	}

func _on_start_run_requested(hero_def_id: StringName, deck_id: StringName) -> void:
	run_state = RunState.new()
	run_state.initialize_run(hero_def_id, deck_id)
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("main_scene_requested")

func _on_new_game_requested() -> void:
	# Default to first hero and deck if called without parameters
	var hero_defs = Database.get_hero_definitions()
	var deck_meta = Database.get_all_deck_metadata()
	if hero_defs.size() > 0 and deck_meta.size() > 0:
		_on_start_run_requested(hero_defs[0].id, deck_meta[0].deck_id)
	else:
		printerr("GameManager: Could not start new game - no heroes or decks available")

func _on_battle_ended(results: Dictionary) -> void:
	# Centralize post-battle handling per GIR.
	# 1) Flip global battle state off and broadcast.
	is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	# 2) If victory, pre-generate rewards now so the modal can be instant.
	var is_victory: bool = bool(results.get("victory", false))
	if is_victory:
		SignalBus.emit_signal("battle_won_rewards_pending")
	# 3) Open the hermetic end-of-battle modal.
	WindowManager.open_modal_window(&"EndBattlePopup", {"is_victory": is_victory})

func _on_battle_start_requested(encounter_def: EncounterDefinition):
	pass

func _on_battle_won_rewards_pending():
	# Generate rewards for the victory and store them.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	var reward_pool = load("res://resources/reward_pool.tres")
	if not is_instance_valid(reward_pool):
		printerr("GameManager: Failed to load reward_pool.tres for pre-generation.")
		return

	var all_defs = reward_pool.definitions.duplicate()
	all_defs.shuffle()
	
	for i in range(3):
		var inst = GachaBallInstance.new()
		inst.initialize(all_defs[i])
		inst.location_container_tag = &"Rewards"
		inst.location_slot_index = i
		_temporary_reward_master_dict[inst.ball_uuid] = inst
		_temporary_reward_container.set_uuid(i, inst.ball_uuid)
	
	print("GameManager: Generated ", _temporary_reward_master_dict.size(), " reward instances")

func _on_return_to_title() -> void:
	# Clear the run state and any pending rewards when returning to the title screen
	run_state = null
	# Clear any temporary rewards if the player quits or loses.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null



func _on_battle_victory_acknowledged():
	if _is_processing_victory: 
		return # Debounce guard
	_is_processing_victory = true

	# Day should only increment when path choice scene loads, not here
	
	# Rewards are already generated. We just need to calculate the gold.
	var sum_tiers = 0
	for inst in _temporary_reward_master_dict.values():
		var def = inst.get_definition()
		if is_instance_valid(def):
			sum_tiers += def.tier
	_temporary_gold_reward = max(1, int(floor(sum_tiers / 3.0)))

	# Signal the UI to display the pre-generated rewards.
	SignalBus.emit_signal("reward_scene_requested")

func _on_reward_chosen(payload):
	# --- STALE SELECTION FIX ---
	# The action is complete. Clear the interaction state immediately.
	SignalBus.emit_signal("selection_clear_requested")

	if payload.type == "gachaball":
		var chosen_uuid = payload.get("instance_uuid")
		if chosen_uuid and _temporary_reward_master_dict.has(chosen_uuid):
			var selected_instance = _temporary_reward_master_dict[chosen_uuid]
			var def = selected_instance.get_definition()
			
			var container_name = &"RunInventoryT%d" % def.tier
			var container = run_state.get_container(container_name)
			if not is_instance_valid(container):
				printerr("GameManager: Could not find run container for tag: ", container_name)
				return

			var target_slot = container.find_first_empty_slot()
			
			container.set_uuid(target_slot, selected_instance.ball_uuid)
			
			selected_instance.location_container_tag = container_name
			selected_instance.location_slot_index = target_slot
			selected_instance.equipped_on_uuid = ""
			selected_instance.equipped_slot_index = -1
			
			run_state.run_instances[selected_instance.ball_uuid] = selected_instance
			
			# --- Debug Output ---
			print("--- REWARD CHOSEN ---")
			print("Instance UUID: ", selected_instance.ball_uuid)
			print("Set Location To: ", selected_instance.location_container_tag, " [", selected_instance.location_slot_index, "]")
			print("--------------------")
			
	elif payload.type == "gold":
		run_state.gold += payload.get("amount", 0)
		SignalBus.emit_signal("gold_changed", run_state.gold)

	# --- TRANSITION LOGIC REMOVED ---
	# The scene transition is now handled by the new button in Reward.gd.
	# We still need to clean up the temporary data and signal that the run data has changed.
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null
	SignalBus.emit_signal("run_data_changed")
	# DO NOT emit path_choice_scene_requested here anymore.
	
	_is_processing_victory = false

## Temporary debug function to inspect the pending reward master dictionary
# Removed redundant functions that were replaced by the new temporary instance system

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## This is the central, authoritative function for resolving a LocationIdentifier to an instance.
## Returns null if the location is invalid or the instance cannot be found.
## Central authoritative function to find any instance by its UUID.
## This should be used instead of direct lookups in BattleManager or RunState.
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	if uuid.is_empty():
		return null

	# 1. Check temporary context first (e.g., rewards, shop)
	if _temporary_reward_master_dict.has(uuid):
		return _temporary_reward_master_dict[uuid]

	# 2. Check battle or run context
	if is_in_battle and is_instance_valid(_active_battle_manager):
		return _active_battle_manager.get_instance(uuid)
	else:
		if is_instance_valid(run_state):
			return run_state.get_instance_by_uuid(uuid)
	
	# 3. Fallback if not found anywhere
	return null

## Gets an instance from a location identifier
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# NEW: Check for the temporary reward context FIRST.
	if loc.container == &"Rewards":
		if _temporary_reward_container and _temporary_reward_master_dict:
			var uuid = _temporary_reward_container.get_uuid(loc.index)
			if not uuid.is_empty():
				return _temporary_reward_master_dict.get(uuid)
		return null # Return null if the reward context is not active or slot is empty.

	# NEW: Check for the temporary shop context.
	if loc.container == &"Shop":
		if _temporary_shop_container and _temporary_shop_master_dict:
			var uuid = _temporary_shop_container.get_uuid(loc.index)
			if not uuid.is_empty():
				return _temporary_shop_master_dict.get(uuid)
		return null # Return null if the shop context is not active or slot is empty.

	# Step 1: Determine the current context (battle or run) to get the right data source.
	var data_owner: Object
	if is_in_battle:
		data_owner = _active_battle_manager
	else:
		data_owner = run_state

	if not is_instance_valid(data_owner):
		printerr("GameManager: Could not determine a valid data owner.")
		return null

	# Step 2: Apply contextual understanding based on the location type.
	
	# Case A: The location is for an equipped item (a conceptual location).
	if loc.container == &"equipped_item":
		if loc.unit_uuid.is_empty():
			printerr("GameManager: LocationIdentifier for equipped_item is missing a unit_uuid.")
			return null
		
		var all_instances_db = data_owner.get_all_instances()
		var parent_unit: GachaBallInstance = all_instances_db.get(loc.unit_uuid)
		
		if not is_instance_valid(parent_unit):
			printerr("GameManager: Could not find parent unit with UUID: ", loc.unit_uuid)
			return null
		
		var item_uuid = parent_unit.get_equipped_item_uuid(loc.index)
		if item_uuid.is_empty():
			return null # The slot is empty.
		
		return all_instances_db.get(item_uuid)

	# Case B: The location is a standard physical container.
	# Delegate the simple lookup to the appropriate data owner.
	else:
		if data_owner.has_method("get_instance_by_location"):
			return data_owner.get_instance_by_location(loc)

	# Fallback if no valid case is met.
	printerr("GameManager: Unhandled location type in get_instance_from_location for container: ", loc.container)
	return null

func _on_node_selected(node_def: PathNodeDefinition):
	match node_def.node_type:
		"BATTLE":
			var budget = run_state.day * 5
			if node_def.subtype == "ELITE":
				budget = int(floor(budget * 1.5))
			
			print("GameManager: Day: ", run_state.day, ", Budget: ", budget, ", Node subtype: ", node_def.subtype)
			var encounter_def = EncounterGenerator.generate_encounter(budget)
			# Use Main.gd to handle scene loading
			var main_node = get_tree().get_root().find_child("Main", true, false)
			if is_instance_valid(main_node):
				main_node._on_battle_start_requested(encounter_def)
		"SHOP":
			_enter_shop()
		"REST":
			# Use Main.gd to handle scene loading
			var main_node = get_tree().get_root().find_child("Main", true, false)
			if is_instance_valid(main_node):
				main_node._clear_content_area()
				var instance = REST_SITE_SCENE.instantiate()
				main_node._current_content_node = instance
				main_node.content_area.get_node("SubViewport/MarginContainer").add_child(instance)

func _enter_shop():
	_reroll_cost = 1
	_generate_shop_stock()
	var context = { "shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost }
	# Use Main.gd to handle scene loading
	var main_node = get_tree().get_root().find_child("Main", true, false)
	if is_instance_valid(main_node):
		main_node._on_shop_scene_requested(context)

func _generate_shop_stock():
	_temporary_shop_master_dict.clear()
	_temporary_shop_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	var reward_pool = load("res://resources/reward_pool.tres")
	if not is_instance_valid(reward_pool): return

	var all_defs = reward_pool.definitions.duplicate()
	all_defs.shuffle()
	
	for i in range(3):
		var def = all_defs[i]
		var inst = GachaBallInstance.new()
		inst.initialize(def)
		
		inst.location_container_tag = &"Shop"
		inst.location_slot_index = i
		
		_temporary_shop_master_dict[inst.ball_uuid] = inst
		_temporary_shop_container.set_uuid(i, inst.ball_uuid)

func _on_shop_purchase_requested(instance_uuid: String, cost: int):
	if not _temporary_shop_master_dict.has(instance_uuid): return
	if run_state.gold < cost: return

	run_state.gold -= cost
	SignalBus.emit_signal("gold_changed", run_state.gold)

	var purchased_instance = _temporary_shop_master_dict[instance_uuid]
	var def = purchased_instance.get_definition()
	var container_name = &"RunInventoryT%d" % def.tier
	var container = run_state.get_container(container_name)
	var target_slot = container.find_first_empty_slot()

	container.set_uuid(target_slot, purchased_instance.ball_uuid)
	purchased_instance.location_container_tag = container_name
	purchased_instance.location_slot_index = target_slot
	run_state.run_instances[purchased_instance.ball_uuid] = purchased_instance

	_temporary_shop_master_dict.erase(instance_uuid)
	var temp_slot = _temporary_shop_container.get_all_uuids().find(instance_uuid)
	if temp_slot != -1:
		_temporary_shop_container.set_uuid(temp_slot, "")

	SignalBus.emit_signal("run_data_changed")
	var context = { "shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost }
	SignalBus.emit_signal("shop_stock_refreshed", context)

func _on_shop_reroll_requested():
	if run_state.gold < _reroll_cost: return

	run_state.gold -= _reroll_cost
	SignalBus.emit_signal("gold_changed", run_state.gold)
	_reroll_cost += 1

	_generate_shop_stock()
	
	SignalBus.emit_signal("run_data_changed")
	var context = { "shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost }
	SignalBus.emit_signal("shop_stock_refreshed", context)
