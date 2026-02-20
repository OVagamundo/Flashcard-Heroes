# res://scripts/SlotIndicatorController.gd
extends Node

## Controller for showing visual indicators on valid drop target slots
## when a gachaball is selected or being dragged.

# Cached reference to the source instance for target computation
var _source_instance: GachaBallInstance = null
var _source_location: LocationIdentifier = null

func _ready() -> void:
	# Connect to selection signals
	SignalBus.selection_changed.connect(_on_selection_changed)
	SignalBus.selection_clear_requested.connect(_on_selection_clear_requested)
	
	# Connect to drag signals
	SignalBus.drag_started.connect(_on_drag_started)
	SignalBus.drag_ended.connect(_on_drag_ended)

func _exit_tree() -> void:
	if SignalBus.selection_changed.is_connected(_on_selection_changed):
		SignalBus.selection_changed.disconnect(_on_selection_changed)
	if SignalBus.selection_clear_requested.is_connected(_on_selection_clear_requested):
		SignalBus.selection_clear_requested.disconnect(_on_selection_clear_requested)
	if SignalBus.drag_started.is_connected(_on_drag_started):
		SignalBus.drag_started.disconnect(_on_drag_started)
	if SignalBus.drag_ended.is_connected(_on_drag_ended):
		SignalBus.drag_ended.disconnect(_on_drag_ended)

# --- Signal Handlers ---

func _on_selection_changed(new_location: LocationIdentifier) -> void:
	if not is_instance_valid(new_location):
		_hide_indicators()
		return
	
	# Get the instance at this location
	_source_location = new_location
	_source_instance = GameManager.get_instance_from_location(new_location)
	
	if not is_instance_valid(_source_instance):
		_hide_indicators()
		return
	
	# Compute and show valid targets
	var valid_targets = _compute_valid_targets(_source_instance, _source_location)
	if valid_targets.size() > 0:
		SignalBus.emit_signal("show_slot_indicators", valid_targets)
	else:
		_hide_indicators()

func _on_selection_clear_requested() -> void:
	_hide_indicators()

func _on_drag_started(origin_context: InteractionContext) -> void:
	if not is_instance_valid(origin_context) or not is_instance_valid(origin_context.location):
		return
	
	_source_location = origin_context.location
	_source_instance = GameManager.get_instance_from_location(_source_location)
	
	if not is_instance_valid(_source_instance):
		return
	
	# Compute and show valid targets
	var valid_targets = _compute_valid_targets(_source_instance, _source_location)
	if valid_targets.size() > 0:
		SignalBus.emit_signal("show_slot_indicators", valid_targets)

func _on_drag_ended(_was_handled: bool) -> void:
	_hide_indicators()

func _hide_indicators() -> void:
	_source_instance = null
	_source_location = null
	SignalBus.emit_signal("hide_slot_indicators")

# --- Valid Target Computation ---

func _compute_valid_targets(source_instance: GachaBallInstance, source_loc: LocationIdentifier) -> Array:
	var valid_locations: Array = []
	
	if not is_instance_valid(source_instance) or not is_instance_valid(source_loc):
		return valid_locations
	
	var source_def = source_instance.get_definition()
	if not is_instance_valid(source_def):
		return valid_locations
	
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner):
		return valid_locations
	
	var all_instances = data_owner.get_all_instances()
	
	# Determine category of source
	var is_unit = source_def.category == &"UNIT"
	var is_item = source_def.category == &"ITEM"
	var is_consumable = source_def.category == &"CONSUMABLE"
	
	# Determine if source is from inventory context
	var is_inventory_context = _is_inventory_container(source_loc.container)
	
	# Get all visible containers based on current context
	var containers_to_check: Array[StringName] = _get_checkable_containers(is_unit, is_item, is_consumable, source_loc.container)
	
	for container_name in containers_to_check:
		var container = data_owner.get_container(container_name)
		if not is_instance_valid(container):
			continue
		
		var slot_count = container.get_size()
		for i in range(slot_count):
			var target_loc = LocationIdentifier.new()
			target_loc.container = container_name
			target_loc.index = i
			
			# Note: Original slot is now included as valid target (for cancel-drop bounce)
			
			# Check if this is a valid target
			if _is_valid_target(source_instance, source_loc, target_loc, all_instances):
				valid_locations.append(target_loc)
	
	# For ITEMS in battle context (not inventory): also check equip targets
	if is_item and not is_inventory_context:
		var equip_targets = _get_equip_targets(source_instance, source_loc, data_owner)
		valid_locations.append_array(equip_targets)
		
	# For CONSUMABLES in battle context (not inventory): also check unit targets
	if is_consumable and not is_inventory_context:
		var unit_targets = _get_consumable_targets(data_owner)
		valid_locations.append_array(unit_targets)
	
	return valid_locations

## Check if a container is an inventory container (run or battle inventory)
func _is_inventory_container(container_name: StringName) -> bool:
	return container_name.begins_with("RunInventory") or container_name.begins_with("BattleInventory")

## Extract tier from inventory container name (e.g., "RunInventoryT1" -> 1)
func _get_inventory_tier(container_name: StringName) -> int:
	if container_name.ends_with("T1"):
		return 1
	elif container_name.ends_with("T2"):
		return 2
	elif container_name.ends_with("T3"):
		return 3
	return 0

func _get_checkable_containers(is_unit: bool, is_item: bool, is_consumable: bool, source_container: StringName) -> Array[StringName]:
	var containers: Array[StringName] = []
	
	# Check if source is from inventory
	var is_inventory_source = _is_inventory_container(source_container)
	
	if is_inventory_source:
		# Inventory context: can only move within same tier container + check merge targets in next tier
		var source_tier = _get_inventory_tier(source_container)
		var prefix = "RunInventory" if source_container.begins_with("RunInventory") else "BattleInventory"
		
		# Same tier for move/swap
		containers.append(StringName(prefix + "T%d" % source_tier))
		
		# Next tier for merge targets (T1+T1->T2, T2+T2->T3)
		if source_tier < 3:
			containers.append(StringName(prefix + "T%d" % (source_tier + 1)))
	else:
		# Battle context
		if is_unit:
			# Units can move to PlayerLineup, PlayerBench
			containers.append(&"PlayerLineup")
			containers.append(&"PlayerBench")
			if GameManager.is_test_mode:
				containers.append(&"EnemyLineup")
		elif is_item or is_consumable:
			# Items and consumables can move to PlayerBench
			containers.append(&"PlayerBench")
	
	return containers

func _get_consumable_targets(data_owner: Object) -> Array:
	var targets: Array = []
	var allowed_containers: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	
	if GameManager.is_test_mode:
		allowed_containers.append(&"EnemyLineup")
	
	for container_name in allowed_containers:
		var container = data_owner.get_container(container_name)
		if not is_instance_valid(container):
			continue
		
		var slot_count = container.get_size()
		for i in range(slot_count):
			var uuid = container.get_uuid(i)
			if uuid.is_empty():
				continue
			var unit_instance = data_owner.get_all_instances().get(uuid)
			if not is_instance_valid(unit_instance):
				continue
			var unit_def = unit_instance.get_definition()
			if is_instance_valid(unit_def) and unit_def.category == &"UNIT":
				var target_loc = LocationIdentifier.new()
				target_loc.container = container_name
				target_loc.index = i
				targets.append(target_loc)
				
	return targets

func _is_valid_target(source_instance: GachaBallInstance, source_loc: LocationIdentifier, target_loc: LocationIdentifier, all_instances: Dictionary) -> bool:
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner):
		return false
	
	var source_def = source_instance.get_definition()
	var source_tier = source_def.tier if is_instance_valid(source_def) else 0
	
	# Check for inventory tier restrictions
	var source_is_inventory = _is_inventory_container(source_loc.container)
	var target_is_inventory = _is_inventory_container(target_loc.container)
	
	# Get target instance (shared across all checks)
	var target_instance = GameManager.get_instance_from_location(target_loc)
	
	if source_is_inventory and target_is_inventory:
		var source_container_tier = _get_inventory_tier(source_loc.container)
		var target_container_tier = _get_inventory_tier(target_loc.container)
		
		if not is_instance_valid(target_instance):
			# Empty slot - must be same tier for moves
			if source_container_tier != target_container_tier:
				return false
			# Continue to standard placement check below
		else:
			# Occupied slot - check for merge or swap
			var inv_target_def = target_instance.get_definition()
			var inv_target_tier = inv_target_def.tier if is_instance_valid(inv_target_def) else 0
			
			# Check for merge recipe (only same category can merge)
			if source_def.category == inv_target_def.category:
				var inv_recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances)
				if is_instance_valid(inv_recipe):
					return true
			
			# For swap in inventory: container tiers must match, item tiers must match
			# Cross-category swaps ARE allowed (item<->unit in same tier)
			if source_container_tier != target_container_tier:
				return false
			if source_tier != inv_target_tier:
				return false
			# Valid inventory swap (can be cross-category)
			return true
	
	# CASE 1: Empty slot - check if valid placement
	if not is_instance_valid(target_instance):
		return InventoryManager.is_valid_placement(source_instance, target_loc)
	
	# CASE 2: Occupied slot - check for merge or swap
	var target_def = target_instance.get_definition()
	
	# Categories must match for merge, but check swap validity for cross-category
	if source_def.category != target_def.category:
		if InventoryManager.is_valid_placement(source_instance, target_loc) and InventoryManager.is_valid_placement(target_instance, source_loc):
			return true
		return false
	
	# Check for merge recipe
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances)
	if is_instance_valid(recipe):
		return true
	
	# Check for swap (both placements must be valid)
	if InventoryManager.is_valid_placement(source_instance, target_loc) and InventoryManager.is_valid_placement(target_instance, source_loc):
		return true
	
	return false

func _get_equip_targets(item_instance: GachaBallInstance, _source_loc: LocationIdentifier, data_owner: Object) -> Array:
	var equip_targets: Array = []
	
	# Items can be equipped onto units in PlayerLineup or PlayerBench
	var allowed_containers: Array[StringName] = [&"PlayerLineup", &"PlayerBench"]
	
	# In test mode, also allow equipping on enemy units
	if GameManager.is_test_mode:
		allowed_containers.append(&"EnemyLineup")
	
	# Check if item is already equipped - if so, it can only move within the same unit
	if not item_instance.equipped_on_uuid.is_empty():
		# Already equipped - can only show equipped slots on the same unit
		return equip_targets
	
	for container_name in allowed_containers:
		var container = data_owner.get_container(container_name)
		if not is_instance_valid(container):
			continue
		
		var slot_count = container.get_size()
		for i in range(slot_count):
			var uuid = container.get_uuid(i)
			if uuid.is_empty():
				continue
			
			var unit_instance = data_owner.get_all_instances().get(uuid)
			if not is_instance_valid(unit_instance):
				continue
			
			var unit_def = unit_instance.get_definition()
			if not is_instance_valid(unit_def) or unit_def.category != &"UNIT":
				continue
			
			# Check if unit has empty equipment slots
			var has_empty_slot = false
			for slot_uuid in unit_instance.equipped_item_uuids:
				if slot_uuid.is_empty():
					has_empty_slot = true
					break
			
			if has_empty_slot:
				var target_loc = LocationIdentifier.new()
				target_loc.container = container_name
				target_loc.index = i
				equip_targets.append(target_loc)
	
	return equip_targets

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state
