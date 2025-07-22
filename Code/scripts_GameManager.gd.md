<!-- Original: scripts/GameManager.gd -->

```gdscript
# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false # The global authority on whether a battle is active.
var _temporary_reward_master_dict: Dictionary = {}
var _temporary_reward_container: DataContainer = null # Will hold a FixedArrayContainer
var _temporary_gold_reward: int = 0
var _is_processing_victory: bool = false # Prevents multiple reward processing

# This is the function that gets the reward instance.
func get_temporary_reward_instance(uuid: String) -> GachaBallInstance:
	return _temporary_reward_master_dict.get(uuid)

# Returns the current gold reward amount
func get_temporary_gold_reward() -> int:
	return _temporary_gold_reward

# Returns the current temporary reward container
func get_temporary_reward_container() -> DataContainer:
	return _temporary_reward_container

func _ready() -> void:
	# Connect to signals to manage the run and battle state.
	EventBus.start_run_requested.connect(_on_start_run_requested)
	EventBus.battle_state_changed.connect(func(in_battle): is_in_battle = in_battle)
	EventBus.title_scene_requested.connect(_on_return_to_title)
	EventBus.new_game_requested.connect(_on_new_game_requested)
	EventBus.battle_victory_acknowledged.connect(_on_battle_victory_acknowledged)
	EventBus.reward_chosen.connect(_on_reward_chosen)

func _on_start_run_requested() -> void:
	run_state = RunState.new()
	run_state.start_new_run()
	EventBus.emit_signal("run_data_changed") # Use the new signal
	EventBus.emit_signal("loadout_scene_requested")

func _on_new_game_requested() -> void:
	_on_start_run_requested()

func _on_return_to_title() -> void:
	# Clear the run state when returning to the title screen
	run_state = null

func _on_battle_victory_acknowledged():
	if _is_processing_victory: 
		return # Debounce guard
	_is_processing_victory = true

	run_state.day += 1
	
	_temporary_reward_master_dict.clear()
	_temporary_reward_container = preload("res://scripts/FixedArrayContainer.gd").new(3)
	
	var reward_pool = load("res://resources/reward_pool.tres")
	var all_defs = reward_pool.definitions.duplicate()
	all_defs.shuffle()
	
	for i in range(3):
		var inst = GachaBallInstance.new()
		inst.initialize(all_defs[i])
		_temporary_reward_master_dict[inst.ball_uuid] = inst
		_temporary_reward_container.set_uuid(i, inst.ball_uuid)
	
	# Debug logging for reward creation
	print("--- GameManager: Rewards CREATED ---")
	print("Master Dict Keys: ", _temporary_reward_master_dict.keys())
	print("Container UUIDs: ", _temporary_reward_container.get_all_uuids())
	print("------------------------------------")

	var sum_tiers = 0
	for uuid in _temporary_reward_container.get_all_uuids():
		if not uuid.is_empty():
			sum_tiers += _temporary_reward_master_dict[uuid].get_definition().tier
	_temporary_gold_reward = max(1, int(floor(sum_tiers / 3.0)))
	
	EventBus.emit_signal("reward_scene_requested")

func _on_reward_chosen(payload):
	if payload.type == "gachaball":
		var chosen_uuid = payload.get("instance_uuid")
		if chosen_uuid and _temporary_reward_master_dict.has(chosen_uuid):
			var selected_instance = _temporary_reward_master_dict[chosen_uuid]
			var def = selected_instance.get_definition()
			var container_name = &"RunInventoryT%d" % def.tier
			run_state.add_instance(selected_instance, container_name)
	elif payload.type == "gold":
		run_state.gold += payload.get("amount", 0)

	_temporary_reward_master_dict.clear()
	_temporary_reward_container = null
	EventBus.emit_signal("run_data_changed")
	EventBus.emit_signal("path_choice_scene_requested")
	_is_processing_victory = false

## Temporary debug function to inspect the master dictionary
func get_temporary_reward_master_dict_for_debug() -> Dictionary:
	return _temporary_reward_master_dict.duplicate()

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## This is the central, authoritative function for resolving a LocationIdentifier to an instance.
## Returns null if the location is invalid or the instance cannot be found.
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# Step 1: Determine the current context (battle or run) to get the right data source.
	var data_owner: Object
	if is_in_battle:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	else:
		data_owner = run_state

	if not is_instance_valid(data_owner):
		printerr("GameManager: Could not determine a valid data owner.")
		return null

	# Step 2: Apply contextual understanding based on the location type.
	# This is the core fix that adheres to the TDD.
	
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

```