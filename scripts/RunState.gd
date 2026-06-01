class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.


@export var gold: int = 0
@export var day: int = 1
@export var current_boss_level: int = 0 # 0 = not in boss fight, 1-5 = current boss
@export var current_elite_level: int = 0 # 0 = not in elite fight, 1+ = current elite
@export var bosses_defeated: int = 0
@export var elites_defeated: int = 0
@export var total_enemies_defeated: int = 0
@export var total_gold_earned: int = 0
@export var black_market_remove_cost: int = 5
@export var hero_instance: GachaBallInstance
@export var last_elite_id: StringName = &""

# Recipe unlock tracking (per-run) - key: recipe_id (StringName), value: bool (unlocked)
@export var unlocked_recipes: Dictionary = {}

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Flashcard learning progress - key = card_id (StringName), value = FlashcardProgress
@export var flashcard_progress: Dictionary = {} # key = StringName, value = FlashcardProgress
@export var active_deck_ids: Array[StringName] = [] # Cards available in the mini-game
@export var ordered_deck_pool: Array[StringName] = [] # The pool of cards ordered by user setting
@export var deck_def_id: StringName = &"" # The definition ID of the chosen deck
@export var cards_presented_count: int = 0 # Updates the progressive presentation of cards

# All containers indexed by name (e.g., "RunInventoryT1", "PlayerLineup", etc.)
var _containers: Dictionary[StringName, DataContainer] = {}

static var RUN_CONTAINER_TAGS: Dictionary = {
	HERO = &"Hero",
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_TRINKETS = &"PlayerTrinkets"
}

# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_deck_unlock_percentage() -> float:
	"""Returns the percentage of the full deck that has been unlocked (active_deck_ids size / total card_ids).
	Returns 0.0 if no deck is selected."""
	if deck_def_id == &"":
		return 0.0
	
	var full_deck = Database.get_cards_for_deck(deck_def_id)
	if full_deck.is_empty():
		return 0.0
		
	return float(active_deck_ids.size()) / float(full_deck.size())

## Records an elite encounter in the history
func record_elite_encounter(elite_id: StringName) -> void:
	if not elite_encounter_history.has(elite_id):
		elite_encounter_history[elite_id] = 0
	elite_encounter_history[elite_id] += 1
	last_elite_id = elite_id
	# Emit signal to ensure UI/Save is updated
	SignalBus.emit_signal("run_data_changed")

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return run_instances.get(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	var container = get_container(loc.container)
	if not is_instance_valid(container):
		return null
	var uuid = container.get_uuid(loc.index)
	if uuid.is_empty():
		return null
	return get_instance_by_uuid(uuid)

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"RunInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance_by_uuid(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func _normalize_container_tag(tag: StringName) -> StringName:
	var s := String(tag)
	if s.begins_with("RUN_INVENTORY_T"):
		var suffix := s.substr(len("RUN_INVENTORY_T"))
		return &"RunInventoryT%s" % suffix
	return tag

func get_all_instances() -> Dictionary:
	return run_instances

func get_run_inventory_containers() -> Dictionary:
	var inventory_data: Dictionary = {}
	for tier in [1, 2, 3]:
		var container_name = &"RunInventoryT%d" % tier
		var container = get_container(container_name)
		if is_instance_valid(container):
			inventory_data[container_name] = container
	return inventory_data

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	if uuid.is_empty():
		return null
	
	var instance = get_instance_by_uuid(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

# ------------------------------------------------------------------
# Stat Modification API (Mirror of BattleManager for decoupling)
# ------------------------------------------------------------------

func apply_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int) -> Variant:
	if not is_instance_valid(instance):
		return null
		
	match stat_type:
		"hp":
			var old_hp = instance.current_hp
			instance.current_hp = max(0, instance.current_hp + delta)
			if old_hp != instance.current_hp:
				SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"hp", old_hp, instance.current_hp)
			return instance.current_hp
		"pwr":
			var old_pwr = instance.current_pwr
			instance.current_pwr = max(0, instance.current_pwr + delta)
			if old_pwr != instance.current_pwr:
				SignalBus.emit_signal("unit_stat_changed", instance.ball_uuid, &"pwr", old_pwr, instance.current_pwr)
			return instance.current_pwr
		_:
			# Status effects pattern: "burn_stacks", "armor_stacks", etc.
			var effect_id = stat_type
			if stat_type.ends_with("_stacks"):
				effect_id = stat_type.trim_suffix("_stacks")
			
			var _old_val = instance.get_status_effect_amount(StringName(effect_id))
			instance.add_status_effect(StringName(effect_id), delta) # add_status_effect is already loud
			return instance.get_status_effect_amount(StringName(effect_id))

func unlock_recipe_for_result(result_definition_id: StringName) -> void:
	"""Unlocks all recipes that produce the given result definition.
	Called when a player acquires a new gachaball (shop, reward, etc.)."""
	if result_definition_id.is_empty():
		return
	
	for recipe_key in Database.recipes:
		var recipe: MergeRecipe = Database.recipes[recipe_key]
		if is_instance_valid(recipe) and recipe.result_id == result_definition_id:
			if not unlocked_recipes.get(recipe.id, false):
				unlocked_recipes[recipe.id] = true
				SignalBus.emit_signal("run_data_changed")

func unlock_all_recipes_for_testing() -> void:
	"""Test mode utility: unlock all recipes so spawned content can be merged."""
	var has_changes: bool = false
	for recipe_key in Database.recipes:
		var recipe: MergeRecipe = Database.recipes[recipe_key]
		if not is_instance_valid(recipe):
			continue
		if unlocked_recipes.get(recipe.id, false):
			continue
		unlocked_recipes[recipe.id] = true
		has_changes = true
	if has_changes:
		SignalBus.emit_signal("run_data_changed")

func is_recipe_unlocked(recipe_id: StringName) -> bool:
	"""Returns true if the given recipe is unlocked for the current run."""
	return unlocked_recipes.get(recipe_id, false)

func get_container(container_name: StringName) -> DataContainer:
	# Check if container exists
	if _containers.has(container_name):
		return _containers[container_name]
	
	# Handle standard containers with default sizes if they don't exist yet
	if container_name == RUN_CONTAINER_TAGS.PLAYER_LINEUP or container_name == RUN_CONTAINER_TAGS.PLAYER_BENCH:
		_containers[container_name] = FixedArrayContainer.new(5)
		return _containers[container_name]
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
		_containers[container_name] = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
		return _containers[container_name]
	
	return null

# ------------------------------------------------------------------
# Mutation helpers
# ------------------------------------------------------------------

func remove_instance_by_uuid(uuid: String) -> void:
	run_instances.erase(uuid)

# ------------------------------------------------------------------
# Atomic mutation API
# ------------------------------------------------------------------

# Trinkets are automatically routed to PlayerTrinkets container in add_instance()
func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	# Adds an instance to the given container/index atomically.
	if not is_instance_valid(instance):
		return false
	# Trinket routing: if the instance's definition is a TRINKET, route to PlayerTrinkets container.
	var def_for_routing = instance.get_definition()
	if is_instance_valid(def_for_routing) and def_for_routing.category == &"TRINKET":
		var trinket_container := get_container(RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
		if not is_instance_valid(trinket_container):
			return false
		var trinket_slot := trinket_container.find_first_empty_slot()
		if trinket_slot == -1:
			return false
		trinket_container.set_uuid(trinket_slot, instance.ball_uuid)
		instance.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		instance.location_slot_index = trinket_slot
		run_instances[instance.ball_uuid] = instance
		if OS.is_debug_build():
			_validate_state_consistency()
		SignalBus.emit_signal("run_data_changed")
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true

	var container = get_container(container_name)
	if not is_instance_valid(container):
		return false
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			# NEW RULE: If a tiered inventory is full, permanently remove a random existing gachaball
			# ONLY applies to RunInventoryT* (not Battle containers that might be accessed via RunState)
			if String(container_name).begins_with("RunInventoryT"):
				var all_uuids = container.get_all_non_empty_uuids()
				if all_uuids.size() > 0:
					# Select a random gachaball
					randomize()
					var uuid_to_replace = all_uuids[randi() % all_uuids.size()]
					var loc_to_replace = get_location_for_uuid(uuid_to_replace)
					slot = loc_to_replace.index
					# Permanently remove the chosen instance from the run to make space
					remove_instance(uuid_to_replace)
			
			if slot == -1:
				return false
	# Update Index
	container.set_uuid(slot, instance.ball_uuid)
	# Update Truth
	instance.location_container_tag = container_name
	instance.location_slot_index = slot
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1
	# Register
	run_instances[instance.ball_uuid] = instance
	# Validate (debug only)
	if OS.is_debug_build():
		_validate_state_consistency()
	# Emit
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Progression and Unit Stats atomic API
# ------------------------------------------------------------------

func advance_day(delta: int = 1) -> bool:
	if delta == 0:
		return true
	day += delta
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	return true

func modify_unit_stats(unit_uuid: String, hp_delta: int = 0, pwr_delta: int = 0) -> bool:
	if unit_uuid.is_empty():
		push_error("modify_unit_stats: Empty unit_uuid")
		return false
	var inst := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(inst):
		push_error("modify_unit_stats: Invalid instance for UUID: %s" % unit_uuid)
		return false
	
	# Debug log before changes
	
	var old_hp = inst.current_hp
	var old_pwr = inst.current_pwr
	if hp_delta != 0:
		inst.current_hp += hp_delta
	if pwr_delta != 0:
		inst.current_pwr += pwr_delta
	
	# Debug log after changes
	
	if OS.is_debug_build():
		_validate_state_consistency()
	
	# Emit granular signals for each stat that changed
	if hp_delta != 0:
		SignalBus.emit_signal("unit_stat_changed", unit_uuid, &"hp", old_hp, inst.current_hp)
	if pwr_delta != 0:
		SignalBus.emit_signal("unit_stat_changed", unit_uuid, &"pwr", old_pwr, inst.current_pwr)
	SignalBus.emit_signal("run_data_changed")
	return true
func modify_unit_base_stats(unit_uuid: String, hp_delta: int = 0, pwr_delta: int = 0) -> bool:
	"""Permanently modifies a unit's base stats via a StatComponent and updates current stats."""
	if unit_uuid.is_empty():
		push_error("modify_unit_base_stats: Empty unit_uuid")
		return false
	var inst := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(inst):
		push_error("modify_unit_base_stats: Invalid instance for UUID: %s" % unit_uuid)
		return false

	var unit_def := inst.get_definition()
	if not is_instance_valid(unit_def):
		push_error("modify_unit_base_stats: No definition found for unit UUID: %s" % unit_uuid)
		return false

	# Store old values for granular signals
	var old_hp = inst.current_hp
	var old_pwr = inst.current_pwr

	# Add stat modification through the component system
	inst.add_or_update_stat_component(
		&"permanent_base_upgrade",
		&"PERMANENT_UPGRADE",
		"modify_unit_base_stats",
		hp_delta,
		pwr_delta,
		false
	)

	# Update current stats: apply the delta directly to preserve battle damage
	inst.current_hp += hp_delta
	inst.current_pwr += pwr_delta

	if OS.is_debug_build():
		_validate_state_consistency()

	# Emit granular signals for each stat that changed
	if old_hp != inst.current_hp:
		SignalBus.emit_signal("unit_stat_changed", unit_uuid, &"hp", old_hp, inst.current_hp)
	if old_pwr != inst.current_pwr:
		SignalBus.emit_signal("unit_stat_changed", unit_uuid, &"pwr", old_pwr, inst.current_pwr)
	SignalBus.emit_signal("run_data_changed")
	return true

func remove_instance(uuid: String) -> bool:
	# Removes an instance from its current location and registry.
	if uuid.is_empty():
		return false
	var instance := get_instance_by_uuid(uuid)
	if not is_instance_valid(instance):
		return false
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return false
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		# Clearing from equipped slot
		var parent_unit := get_instance_by_uuid(loc.unit_uuid)
		if not is_instance_valid(parent_unit):
			return false
		if loc.index < 0 or loc.index >= parent_unit.equipped_item_uuids.size():
			return false
		# Remove bonuses before clearing mapping; equipped slots are logical
		parent_unit.unequip_item_bonus(instance)
		parent_unit.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
		# NOTE: unequip_item_bonus() already emits granular unit_stat_changed signals
	else:
		# If removing a UNIT, first unequip and rehome all equipped items atomically
		var def := instance.get_definition()
		if is_instance_valid(def) and def.category == &"UNIT":
			var items_to_rehome: Array[GachaBallInstance] = []
			for i in range(instance.equipped_item_uuids.size()):
				var it_uuid := instance.equipped_item_uuids[i]
				if it_uuid.is_empty():
					continue
				var it := get_instance_by_uuid(it_uuid)
				if is_instance_valid(it):
					items_to_rehome.append(it)
			# Capacity precheck to guarantee atomicity
			var inv := get_container(RUN_CONTAINER_TAGS.PLAYER_BENCH)
			if not is_instance_valid(inv):
				return false
			var inv_uuids := inv.get_all_uuids()
			var free_count := 0
			for u in inv_uuids:
				if String(u).is_empty():
					free_count += 1
			if free_count < items_to_rehome.size():
				return false
			# Perform rehome now that capacity is guaranteed
			for i in range(instance.equipped_item_uuids.size()):
				var it_uuid2 := instance.equipped_item_uuids[i]
				if it_uuid2.is_empty():
					continue
				var it2 := get_instance_by_uuid(it_uuid2)
				if not is_instance_valid(it2):
					continue
				instance.equipped_item_uuids[i] = ""
				it2.equipped_on_uuid = ""
				it2.equipped_slot_index = -1
				var empty := inv.find_first_empty_slot()
				if empty == -1:
					return false
				inv.set_uuid(empty, it2.ball_uuid)
				it2.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_BENCH
				it2.location_slot_index = empty
		var container := get_container(loc.container)
		if not is_instance_valid(container):
			return false
		if container.get_uuid(loc.index) == instance.ball_uuid:
			container.set_uuid(loc.index, "")
	# Erase from registry
	run_instances.erase(uuid)
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	# Moves an instance from source to target. Handles equipping when target is equipped_item.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	var instance: GachaBallInstance = get_instance_by_location(source_loc)
	if not is_instance_valid(instance):
		return false
	# Equipping path
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit_instance: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
		if not is_instance_valid(unit_instance):
			return false
		return equip_item(instance.ball_uuid, unit_instance.ball_uuid, target_loc.index)
	# Default move between containers
	var from_container: DataContainer = get_container(source_loc.container)
	var to_container: DataContainer = get_container(target_loc.container)
	if not is_instance_valid(from_container) or not is_instance_valid(to_container):
		return false
	# Clear all status effects (burn, etc.)
	if source_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		if from_container.get_uuid(source_loc.index) == instance.ball_uuid:
			from_container.set_uuid(source_loc.index, "")
	# Place into target index (Index)
	to_container.set_uuid(target_loc.index, instance.ball_uuid)
	# Update Truth
	instance.location_container_tag = target_loc.container
	instance.location_slot_index = target_loc.index
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1
	# Validate and emit
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	# Swaps two instances across containers, supporting equipped slots.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	var a: GachaBallInstance = get_instance_by_location(source_loc)
	var b: GachaBallInstance = get_instance_by_location(target_loc)
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	# If swapping with an equipped slot
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		# Equip A onto target unit; move B to source slot
		var target_unit: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
		if not is_instance_valid(target_unit):
			return false
		var target_slot := target_loc.index
		# Remove A from its source index
		if source_loc.container != C.CONTAINER_EQUIPPED_ITEM:
			var src_container: DataContainer = get_container(source_loc.container)
			if not is_instance_valid(src_container):
				return false
			if src_container.get_uuid(source_loc.index) == a.ball_uuid:
				src_container.set_uuid(source_loc.index, "")
		# If slot occupied by B, move B to source
		var _moved_b_to_source := false
		if is_instance_valid(b) and b.ball_uuid != "":
			# If B is currently equipped, clear its equip slot
			if b.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				var parent: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
				if is_instance_valid(parent) and target_slot >= 0 and target_slot < parent.equipped_item_uuids.size():
					parent.equipped_item_uuids[target_slot] = ""
					b.equipped_on_uuid = ""
					b.equipped_slot_index = -1
			# Place B into source container slot
			var src_container2: DataContainer = get_container(source_loc.container)
			if is_instance_valid(src_container2):
				src_container2.set_uuid(source_loc.index, b.ball_uuid)
				b.location_container_tag = source_loc.container
				b.location_slot_index = source_loc.index
				b.equipped_on_uuid = ""
				b.equipped_slot_index = -1
				_moved_b_to_source = true
		# Equip A into target slot
		var ok := equip_item(a.ball_uuid, target_unit.ball_uuid, target_slot)
		if not ok:
			return false
		if OS.is_debug_build():
			_validate_state_consistency()
		return true
	# General container-to-container swap
	var a_container := get_container(source_loc.container)
	var b_container := get_container(target_loc.container)
	if not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return false
	# Swap index values
	if a_container.get_uuid(source_loc.index) != a.ball_uuid:
		return false
	var b_uuid := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid)
	# Update Truth
	a.location_container_tag = target_loc.container
	a.location_slot_index = target_loc.index
	a.equipped_on_uuid = ""
	a.equipped_slot_index = -1
	b.location_container_tag = source_loc.container
	b.location_slot_index = source_loc.index
	b.equipped_on_uuid = ""
	b.equipped_slot_index = -1
	# Validate and emit
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Economy (Gold) atomic API
# ------------------------------------------------------------------

func add_gold(amount: int, silent: bool = false) -> bool:
	# Adds gold atomically; emits change signals
	if amount == 0:
		return true
	if amount < 0:
		return spend_gold(-amount, silent)
	gold += amount
	if OS.is_debug_build():
		_validate_state_consistency()
	if not silent:
		SignalBus.emit_signal("gold_changed", gold)
		SignalBus.emit_signal("run_data_changed")
	return true

func spend_gold(amount: int, silent: bool = false) -> bool:
	# Spends gold if available; emits change signals
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	if OS.is_debug_build():
		_validate_state_consistency()
	if not silent:
		SignalBus.emit_signal("gold_changed", gold)
		SignalBus.emit_signal("run_data_changed")
	return true

func get_black_market_remove_cost() -> int:
	return max(5, black_market_remove_cost)

func increase_black_market_remove_cost() -> void:
	black_market_remove_cost = get_black_market_remove_cost() + 1
	SignalBus.emit_signal("run_data_changed")


func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	# Equips an item onto a unit. Units now use a single slot, so default equips replace.
	if item_uuid.is_empty() or unit_uuid.is_empty():
		return false
	var item := get_instance_by_uuid(item_uuid)
	var unit := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return false
	# Determine slot
	var target_slot := slot_index
	if target_slot < 0:
		target_slot = 0
	if target_slot >= unit.equipped_item_uuids.size():
		return false
	# If the item is currently equipped (same or different unit), clear the previous mapping
	# and remove bonuses first to avoid ghost copies and double-apply during intra-unit moves.
	var prev_parent_uuid := item.equipped_on_uuid
	if not prev_parent_uuid.is_empty():
		var prev_parent := get_instance_by_uuid(prev_parent_uuid)
		if is_instance_valid(prev_parent):
			if item.equipped_slot_index >= 0 and item.equipped_slot_index < prev_parent.equipped_item_uuids.size():
				prev_parent.equipped_item_uuids[item.equipped_slot_index] = ""
				# Remove previous bonus (even if same unit; will re-apply after placing)
				prev_parent.unequip_item_bonus(item)
				# NOTE: unequip_item_bonus() already emits granular unit_stat_changed signals
	# If item currently in a container, remove it from index
	var item_loc := item.get_location()
	if is_instance_valid(item_loc) and item_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		var src_container := get_container(item_loc.container)
		if is_instance_valid(src_container) and src_container.get_uuid(item_loc.index) == item.ball_uuid:
			src_container.set_uuid(item_loc.index, "")
	# If target slot occupied, unequip existing item to PlayerBench (fallback: first empty)
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	if not existing_uuid.is_empty():
		var existing_item := get_instance_by_uuid(existing_uuid)
		if is_instance_valid(existing_item):
			unit.unequip_item_bonus(existing_item)
			existing_item.equipped_on_uuid = ""
			existing_item.equipped_slot_index = -1
			# Place into PlayerBench (or any available appropriate container)
			var inv := get_container(RUN_CONTAINER_TAGS.PLAYER_BENCH)
			if is_instance_valid(inv):
				var empty := inv.find_first_empty_slot()
				if empty != -1:
					inv.set_uuid(empty, existing_item.ball_uuid)
					existing_item.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_BENCH
					existing_item.location_slot_index = empty
				else:
					return false
	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot
	# Apply item bonuses (equip_item_bonus emits granular unit_stat_changed)
	unit.equip_item_bonus(item)
	# NOTE: equip_item_bonus() already emits granular unit_stat_changed signals
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	if OS.is_debug_build():
		_validate_state_consistency()
	return true

# ------------------------------------------------------------------
# Golden Rule Validation
# ------------------------------------------------------------------

func _validate_state_consistency() -> bool:
	# Ensures no duplicate UUIDs across containers and truth matches index.
	var seen: Dictionary = {}
	# Validate container slots
	for cname in _containers.keys():
		var c: DataContainer = _containers[cname]
		if not is_instance_valid(c):
			continue
		var uuids := c.get_all_uuids()
		for i in range(uuids.size()):
			var u := uuids[i]
			if u.is_empty():
				continue
			if seen.has(u):
				push_error("Duplicate UUID %s found in containers" % u)
				return false
			seen[u] = true
			var inst: GachaBallInstance = run_instances.get(u)
			if not is_instance_valid(inst):
				push_error("Container references missing instance %s" % u)
				return false
			# Equipped items should not appear in container slots
			if inst.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				push_error("Equipped item %s appears in a container slot" % u)
				return false
	# Validate instances' truth against index
	for u in run_instances.keys():
		var inst: GachaBallInstance = run_instances[u]
		if not is_instance_valid(inst):
			continue
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			continue
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent: GachaBallInstance = run_instances.get(loc.unit_uuid)
			if not is_instance_valid(parent):
				push_error("Equipped parent missing for %s" % u)
				return false
			if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
				push_error("Equipped index out of range for %s" % u)
				return false
			if parent.equipped_item_uuids[loc.index] != u:
				push_error("Equipped mapping mismatch for %s" % u)
				return false
		else:
			var c2 := get_container(loc.container)
			if not is_instance_valid(c2):
				push_error("Missing container %s for %s" % [String(loc.container), u])
				return false
			if c2.get_uuid(loc.index) != u:
				push_error("Index/truth mismatch for %s" % u)
				return false
	return true

# ------------------------------------------------------------------
# Run lifecycle
# ------------------------------------------------------------------

func start_new_run() -> void:
	gold = 5 # Set starting gold
	day = 0
	current_boss_level = 0
	current_elite_level = 0
	bosses_defeated = 0
	elites_defeated = 0
	total_enemies_defeated = 0
	total_gold_earned = 0
	black_market_remove_cost = 5
	run_instances.clear()
	_containers.clear()
	flashcard_progress.clear()
	active_deck_ids.clear()
	cards_presented_count = 0
	unlocked_recipes.clear() # All recipes start locked

## Track which elite bosses have been encountered this run (ID -> count)
## Used for weighted encounter generation (pity system)
@export var elite_encounter_history: Dictionary = {}

func initialize_run(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR") -> void:
	start_new_run()
	self.deck_def_id = deck_id
	
	# Create hero instance from the selected hero definition
	var hero_def = Database.get_definition(hero_def_id)
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
		# Register hero via atomic API in the first lineup slot
		add_instance(self.hero_instance, RUN_CONTAINER_TAGS.PLAYER_LINEUP, 0)
		
	# Test-mode: Timekeeper starts with 1000 gold
	if hero_def_id == &"hero_timekeeper":
		gold = 1000
		SignalBus.emit_signal("gold_changed", gold)
	
	# Initialize flashcard progress for the selected deck
	var deck_card_ids = Database.get_cards_for_deck(deck_id)
	# Fallback if deck not found or empty (shouldn't happen with valid UI)
	if deck_card_ids.is_empty():
		# Try to fallback to all cards if deck lookup fails
		deck_card_ids = Database.flashcard_definitions.keys()
		
	ordered_deck_pool.clear()
	for id in deck_card_ids:
		ordered_deck_pool.append(StringName(id))
		
	if deck_order == "INVERTED":
		ordered_deck_pool.reverse()
	elif deck_order == "RANDOM":
		ordered_deck_pool.shuffle()
		
	for card_id in ordered_deck_pool:
		if not flashcard_progress.has(card_id):
			var progress = FlashcardProgress.new()
			progress.mastery_level = FlashcardProgress.MASTERY_MIN # Start at level 1 (Very Hard)
			flashcard_progress[card_id] = progress
	
	# Populate the initial active deck with the first 5 cards
	# We start with 5 and the first minigame will immediately add the 6th card
	for i in range(min(5, ordered_deck_pool.size())):
		active_deck_ids.append(ordered_deck_pool[i])
	
	# Initial 5 cards are considered "introduced" to start expansion immediately
	cards_presented_count = 5
	
	# Create fresh empty inventory containers for tiers 1-3
	for t in [1, 2, 3]:
		var container_name: StringName = &"RunInventoryT%d" % t
		_containers[container_name] = FixedArrayContainer.new(39)

	# Create player trinket container
	_containers[RUN_CONTAINER_TAGS.PLAYER_TRINKETS] = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)

	# POC TEST: Give the Timekeeper a special Prismatic Apprentice
	# Moved here so containers are guaranteed to exist.

	if hero_def_id == &"hero_timekeeper":
		var apprentice_def = Database.get_definition(&"unit_t1_a")
		if apprentice_def:
			var prismatic_inst = GachaBallInstance.new()
			prismatic_inst.initialize(apprentice_def)
			prismatize_unit(prismatic_inst)
			# Add to Tier 1 Run Inventory so it ends up in the Battle Inventory draw pool
			add_instance(prismatic_inst, &"RunInventoryT1", -1)

	# NOTE: Player trinkets are now obtained exclusively through boss victories.
	# No starter trinkets are given - the player earns them by progressing.

	# --- Add starter units/items to inventory ---
	var starters: Array[StringName] = _get_starters_for_hero(hero_def_id)

	for id in starters:
		var def: GachaBallDefinition = Database.get_definition(id)
		if not def:
			continue
			
		var inst := GachaBallInstance.new()
		inst.initialize(def)
		
		var container_name: StringName
		if def.category == &"TRINKET":
			container_name = RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		else:
			var tier_val: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
			container_name = &"RunInventoryT%d" % tier_val
		# Use atomic add to register and place instance
		add_instance(inst, container_name, -1)
		
		# Unlock recipes for this acquired gachaball
		unlock_recipe_for_result(def.id)
	
	# Test mode can spawn arbitrary units/items; unlock all recipes for parity testing.
	if GameManager.is_test_mode:
		unlock_all_recipes_for_testing()

func _get_starters_for_hero(hero_id: StringName) -> Array[StringName]:
	match hero_id:
		&"hero_timekeeper":
			# Timekeeper is the developer/testing hero.
			# Requirement: 2 copies of all mergeable entities, 1 of non-mergeable.
			var starters: Array[StringName] = []
			
			# 1. Identify all mergeable component IDs from the recipes database
			var mergeable_ids: Dictionary = {}
			for recipe in Database.recipes.values():
				if recipe is MergeRecipe:
					mergeable_ids[recipe.ingredient_a_id] = true
					mergeable_ids[recipe.ingredient_b_id] = true
			
			# 2. Add Units
			for unit_id in Database.units.keys():
				var def = Database.units[unit_id]
				if not def: continue
				# Filter out enemy-only units (Bosses, Elites, and Dust)
				if def.tags.has(&"BOSS") or def.tags.has(&"ELITE") or "Dust" in String(unit_id):
					continue
					
				starters.append(unit_id)
				if mergeable_ids.has(unit_id):
					starters.append(unit_id)
					
			# 3. Add Items
			for item_id in Database.items.keys():
				var def = Database.items[item_id]
				if not def: continue
				if def.tags.has(&"BOSS") or def.tags.has(&"ELITE"):
					continue
					
				starters.append(item_id)
				if mergeable_ids.has(item_id):
					starters.append(item_id)
					
			return starters
		&"hero_bounty_hunter":
			# Bounty Hunter: 4 of each Tier 1 gachaball (32 total)
			return [
				&"unit_t1_a", &"unit_t1_a", &"unit_t1_a", &"unit_t1_a",
				&"unit_t1_b", &"unit_t1_b", &"unit_t1_b", &"unit_t1_b",
				&"unit_t1_c", &"unit_t1_c", &"unit_t1_c", &"unit_t1_c",
				&"unit_t1_d", &"unit_t1_d", &"unit_t1_d", &"unit_t1_d",
				&"item_t1_a", &"item_t1_a", &"item_t1_a", &"item_t1_a",
				&"item_t1_b", &"item_t1_b", &"item_t1_b", &"item_t1_b"
			]
		&"hero_avenger":
			return [
				&"unit_t1_a", &"unit_t1_a", &"unit_t1_a", &"unit_t1_a",
				&"unit_t1_b", &"unit_t1_b", &"unit_t1_b", &"unit_t1_b",
				&"unit_t1_c", &"unit_t1_c", &"unit_t1_c", &"unit_t1_c",
				&"unit_t1_d", &"unit_t1_d", &"unit_t1_d", &"unit_t1_d",
				&"item_t1_a", &"item_t1_a", &"item_t1_a", &"item_t1_a",
				&"item_t1_b", &"item_t1_b", &"item_t1_b", &"item_t1_b"
			]
		&"hero_bastion":
			return [
				&"unit_t1_a", &"unit_t1_a", &"unit_t1_a", &"unit_t1_a",
				&"unit_t1_b", &"unit_t1_b", &"unit_t1_b", &"unit_t1_b",
				&"unit_t1_c", &"unit_t1_c", &"unit_t1_c", &"unit_t1_c",
				&"unit_t1_d", &"unit_t1_d", &"unit_t1_d", &"unit_t1_d",
				&"item_t1_a", &"item_t1_a", &"item_t1_a", &"item_t1_a",
				&"item_t1_b", &"item_t1_b", &"item_t1_b", &"item_t1_b"
			]
		&"hero_pyro", &"hero_starter":
			return [
				&"unit_t1_a", &"unit_t1_a", &"unit_t1_a", &"unit_t1_a",
				&"unit_t1_b", &"unit_t1_b", &"unit_t1_b", &"unit_t1_b",
				&"unit_t1_c", &"unit_t1_c", &"unit_t1_c", &"unit_t1_c",
				&"unit_t1_d", &"unit_t1_d", &"unit_t1_d", &"unit_t1_d",
				&"item_t1_a", &"item_t1_a", &"item_t1_a", &"item_t1_a",
				&"item_t1_b", &"item_t1_b", &"item_t1_b", &"item_t1_b"
			]
		&"hero":
			# Generic hero: 2 copies of selected units/items per tier
			return [
				# Tier 1: 2 copies each
				&"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
				&"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
				# Tier 2: 2x Knight + 2x Phoenix Elixir
				&"unit_t2_c", &"unit_t2_c",
				&"item_t2_c", &"item_t2_c",
				# Tier 3: 2x Sakura Spirit + 2x Vengeful Thorn
				&"unit_t3_d", &"unit_t3_d",
				&"item_t3_d", &"item_t3_d"
			]
		_:
			# Default: minimal starter loadout for other heroes
			return [
				&"unit_t1_a", &"unit_t1_b",
				&"item_t1_a", &"item_t1_b"
			]

func check_deck_expansion() -> bool:
	"""Every time this is called, add EXACTLY ONE new card if available.
	The mastery check has been removed as per user request for linear progression."""
	if deck_def_id == &"":
		return false
	
	var full_deck = ordered_deck_pool
	if full_deck.is_empty() or active_deck_ids.size() >= full_deck.size():
		return false
	
	for i in range(full_deck.size()):
		var card_id = full_deck[i]
		if not active_deck_ids.has(card_id):
			active_deck_ids.append(card_id)
			SignalBus.emit_signal("run_data_changed")
			return true
	
	return false

func prismatize_unit(instance: GachaBallInstance) -> void:
	"""POC Helper: Transforms a unit instance into a Prismatic variant with boosted stats and abilities."""
	if not is_instance_valid(instance):
		return
	instance.apply_prismatic_variant()

# ------------------------------------------------------------------
# Serialization (Save/Load)
# ------------------------------------------------------------------

## Converts the entire run state to a Dictionary for saving.
func to_save_dict() -> Dictionary:
	var data: Dictionary = {
		"gold": gold,
		"day": day,
		"current_boss_level": current_boss_level,
		"current_elite_level": current_elite_level,
		"bosses_defeated": bosses_defeated,
		"elites_defeated": elites_defeated,
		"total_enemies_defeated": total_enemies_defeated,
		"total_gold_earned": total_gold_earned,
		"black_market_remove_cost": black_market_remove_cost,
		"deck_def_id": String(deck_def_id),
		"cards_presented_count": cards_presented_count,
		# Serialize all instances
		"instances": {},
		# Serialize container UUIDs
		"containers": {},
		# Flashcard progress and active deck
		"flashcard_progress": _serialize_flashcard_progress(),
		"active_deck_ids": _serialize_active_deck_ids(),
		"ordered_deck_pool": _serialize_ordered_deck_pool(),
		# Recipe unlocks
		"unlocked_recipes": _serialize_unlocked_recipes(),
	}
	# Serialize instances
	for uuid in run_instances.keys():
		var inst: GachaBallInstance = run_instances[uuid]
		if is_instance_valid(inst):
			data["instances"][uuid] = inst.to_save_dict()
	# Serialize containers (store their UUID arrays)
	for cname in _containers.keys():
		var c: DataContainer = _containers[cname]
		if is_instance_valid(c):
			data["containers"][String(cname)] = c.get_all_uuids()
	return data

## Restores the run state from a saved Dictionary.
func from_save_dict(data: Dictionary) -> void:
	gold = data.get("gold", 0)
	day = data.get("day", 1)
	current_boss_level = data.get("current_boss_level", 0)
	current_elite_level = data.get("current_elite_level", 0)
	bosses_defeated = data.get("bosses_defeated", 0)
	elites_defeated = data.get("elites_defeated", 0)
	total_enemies_defeated = data.get("total_enemies_defeated", 0)
	total_gold_earned = data.get("total_gold_earned", 0)
	black_market_remove_cost = data.get("black_market_remove_cost", 5)
	deck_def_id = StringName(data.get("deck_def_id", ""))
	cards_presented_count = data.get("cards_presented_count", 0)
	
	# Clear and restore instances
	run_instances.clear()
	hero_instance = null
	var inst_data: Dictionary = data.get("instances", {})
	for uuid in inst_data.keys():
		var inst := GachaBallInstance.new()
		inst.from_save_dict(inst_data[uuid])
		run_instances[uuid] = inst
		# Identify hero instance
		var def_id := String(inst.definition_id)
		if def_id == "hero" or def_id.begins_with("hero_"):
			hero_instance = inst
	
	# Clear and restore containers
	_containers.clear()
	var cont_data: Dictionary = data.get("containers", {})
	for cname_str in cont_data.keys():
		var cname := StringName(cname_str)
		var uuids: Array = cont_data[cname_str]
		var container: DataContainer
		# Create appropriate container type based on name
		if cname_str.begins_with("RunInventoryT"):
			container = FixedArrayContainer.new(39)
		elif cname == RUN_CONTAINER_TAGS.PLAYER_LINEUP or cname == RUN_CONTAINER_TAGS.PLAYER_BENCH:
			container = FixedArrayContainer.new(5)
		elif cname == RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
			container = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
		else:
			container = FixedArrayContainer.new(max(5, uuids.size()))
		# Populate container with saved UUIDs
		for i in range(uuids.size()):
			if i < container.get_size():
				container.set_uuid(i, uuids[i])
		_containers[cname] = container
	
	# Restore flashcard progress
	_deserialize_flashcard_progress(data.get("flashcard_progress", {}))
	_deserialize_active_deck_ids(data.get("active_deck_ids", []))
	_deserialize_ordered_deck_pool(data.get("ordered_deck_pool", []))
	
	# Restore unlocked recipes
	_deserialize_unlocked_recipes(data.get("unlocked_recipes", {}))

func _serialize_flashcard_progress() -> Dictionary:
	var result: Dictionary = {}
	for key in flashcard_progress.keys():
		var prog: FlashcardProgress = flashcard_progress[key]
		if is_instance_valid(prog):
			result[String(key)] = {
				"mastery_level": prog.mastery_level,
				"times_reviewed": prog.times_reviewed,
				"last_review_day": prog.last_review_day
			}
	return result

func _deserialize_flashcard_progress(data: Dictionary) -> void:
	flashcard_progress.clear()
	for key_str in data.keys():
		var prog := FlashcardProgress.new()
		var d: Dictionary = data[key_str]
		prog.mastery_level = d.get("mastery_level", 1)
		prog.times_reviewed = d.get("times_reviewed", 0)
		prog.last_review_day = d.get("last_review_day", 0)
		flashcard_progress[StringName(key_str)] = prog

func _serialize_active_deck_ids() -> Array:
	var result: Array = []
	for id in active_deck_ids:
		result.append(String(id))
	return result

func _deserialize_active_deck_ids(data: Array) -> void:
	active_deck_ids.clear()
	for id_str in data:
		active_deck_ids.append(StringName(str(id_str)))

func _serialize_unlocked_recipes() -> Dictionary:
	var result: Dictionary = {}
	for recipe_id in unlocked_recipes.keys():
		result[String(recipe_id)] = unlocked_recipes[recipe_id]
	return result

func _deserialize_unlocked_recipes(data: Dictionary) -> void:
	unlocked_recipes.clear()
	for key_str in data.keys():
		unlocked_recipes[StringName(key_str)] = data[key_str]

func _serialize_ordered_deck_pool() -> Array:
	var result: Array = []
	for id in ordered_deck_pool:
		result.append(String(id))
	return result

func _deserialize_ordered_deck_pool(data: Array) -> void:
	ordered_deck_pool.clear()
	for id_str in data:
		ordered_deck_pool.append(StringName(str(id_str)))

