class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

class StartingLoadout:
	var hero_element: StringName
	var hero_traits: TagComponent
	var starter_ids: Array[StringName] = []
	var bonus_starter_ids: Array[StringName] = []
	var unit_tag_overrides: Dictionary = {}

@export var gold: int = 0
@export var day: int = 1
@export var current_boss_level: int = 0 # 0 = not in boss fight, 1-5 = current boss
@export var current_elite_level: int = 0 # 0 = not in elite fight, 1+ = current elite
@export var bosses_defeated: int = 0
@export var elites_defeated: int = 0
@export var elites_encountered_in_tier: int = 0
@export var elite_milestones_offered: Array[int] = []
@export var total_enemies_defeated: int = 0
@export var total_gold_earned: int = 0
@export var total_tokens_earned: int = 0
@export var current_room_tokens: int = 0
@export var next_battle_minigame_bonus_time: float = 0.0
@export var elapsed_simulation_time: float = 0.0
@export var shrine_remove_cost: int = 5
@export var elite_reward_reroll_cost: int = 5
@export var merge_encounter_cost: int = 5
@export var get_tokens_cost: int = 5
@export var hero_instance: GachaBallInstance
@export var hero_element: StringName = &""
var dynamic_tag_overrides: Dictionary = {} # Key: StringName (unit_def_id), Value: Array[StringName]
@export var active_hero_set: StringName = Database.SET_BASE
@export var last_regular_banner_id: StringName = &""
@export var regular_banner_history: Dictionary = {}
@export var last_elite_id: StringName = &""
@export var elite_encounter_history: Dictionary = {}
@export var last_boss_id: StringName = &""
@export var boss_encounter_history: Dictionary = {}
var revealed_boss_ids: Dictionary[int, StringName] = {}
var defeated_boss_marker_positions: Dictionary[int, float] = {}
@export var run_id: String = ""
@export var run_seed: int = 0

## Authoritative getter for the run's active Hero Set.
## If active_hero_set is unset or SET_BASE, infers the set from hero_instance.
func get_active_hero_set() -> StringName:
	if active_hero_set != &"" and active_hero_set != Database.SET_BASE:
		return active_hero_set
	if is_instance_valid(hero_instance):
		var inferred: StringName = Database.get_hero_set(hero_instance.definition_id)
		if inferred != Database.SET_BASE:
			active_hero_set = inferred
			return inferred
	return Database.SET_BASE

# Room state data (Data layer decoupled from UI scenes)
var available_path_nodes: Array[PathNodeDefinition] = []
var is_training_active: bool = false
var training_unit_uuid: String = ""
var training_stat: String = ""

# Unified token helper methods
func get_tokens() -> int:
	return current_room_tokens

func get_room_tokens() -> int:
	return get_tokens()

func add_tokens(amount: int, silent: bool = false) -> void:
	if amount <= 0: return
	current_room_tokens += amount
	total_tokens_earned += amount
	if not silent:
		SignalBus.emit_signal("gacha_tokens_changed", current_room_tokens)
	SignalBus.emit_signal("run_data_changed")

func add_room_tokens(amount: int) -> void:
	add_tokens(amount, false)

func spend_tokens(amount: int, silent: bool = false) -> bool:
	if current_room_tokens < amount:
		return false
	current_room_tokens -= amount
	if not silent:
		SignalBus.emit_signal("gacha_tokens_changed", current_room_tokens)
	SignalBus.emit_signal("run_data_changed")
	return true

func spend_room_tokens(amount: int) -> bool:
	return spend_tokens(amount, false)

func reset_tokens() -> void:
	current_room_tokens = 0
	SignalBus.emit_signal("gacha_tokens_changed", 0)

func reset_room_tokens() -> void:
	reset_tokens()


# Track when each encounter was last offered for pity system
@export var encounter_last_offered_day: Dictionary = {}

# Recipe unlock tracking (per-run) - key: recipe_id (StringName), value: bool (unlocked)
@export var unlocked_recipes: Dictionary = {}

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Flashcard learning progress - key = card_id (StringName), value = FlashcardProgress
@export var flashcard_progress: Dictionary = {} # key = StringName, value = FlashcardProgress
@export var active_deck_ids: Array[StringName] = [] # Cards available in the Challenge
@export var ordered_deck_pool: Array[StringName] = [] # The pool of cards ordered by user setting
@export var deck_def_id: StringName = &"" # The definition ID of the chosen deck
@export var is_half_deck: bool = false # Tracks if the run uses a quick/half deck
@export var cards_presented_count: int = 0 # Updates the progressive presentation of cards
var last_challenge_met_unlock_requirements: bool = false

# All containers indexed by name (e.g., "RunInventoryT1", "PlayerLineup", etc.)
var _containers: Dictionary[StringName, DataContainer] = {}

static var RUN_CONTAINER_TAGS: Dictionary = {
	HERO = &"Hero",
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_SHELF = &"PlayerShelf",
	PLAYER_TRINKETS = &"PlayerTrinkets"
}

# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_deck_unlock_percentage() -> float:
	"""Returns the percentage of the full deck that has been unlocked (active_deck_ids size / total card_ids).
	Returns 0.0 if no deck is selected."""
	if ordered_deck_pool.is_empty():
		return 0.0
		
	return float(active_deck_ids.size()) / float(ordered_deck_pool.size())

func get_boss_count() -> int:
	return 3 if is_half_deck else 5

func get_mastered_card_count() -> int:
	var count: int = 0
	for card_id: StringName in active_deck_ids:
		var progress: FlashcardProgress = flashcard_progress[card_id]
		if progress.mastery_level >= 3:
			count += 1
	return count

func get_boss_mastery_threshold(level: int) -> int:
	return ceili(float(ordered_deck_pool.size() * level * 4) / float(get_boss_count() * 5))

func get_boss_reveal_threshold(level: int) -> int:
	return ceili(float(ordered_deck_pool.size() * level) / float(get_boss_count()))

func get_encounter_boss_level() -> int:
	if current_boss_level > bosses_defeated:
		return current_boss_level
	for node: PathNodeDefinition in available_path_nodes:
		if node.node_type == &"BATTLE" and node.subtype == &"BOSS" and node.difficulty > bosses_defeated:
			return node.difficulty
	return 0

func get_boss_marker_position(level: int) -> float:
	if defeated_boss_marker_positions.has(level):
		return defeated_boss_marker_positions[level]
	var total: int = ordered_deck_pool.size()
	assert(total > 0, "Boss markers require a selected Deck")
	var locked: int = total - active_deck_ids.size()
	return clampf(float(locked + get_boss_mastery_threshold(level)) / float(total), 0.0, 1.0)

func reveal_boss(level: int) -> StringName:
	if not revealed_boss_ids.has(level):
		revealed_boss_ids[level] = EncounterGenerator.pick_boss_identity(self, level)
	return revealed_boss_ids[level]

func refresh_boss_reveals() -> void:
	if ordered_deck_pool.is_empty():
		return
	var next_boss_level: int = bosses_defeated + 1
	var encounter_level: int = get_encounter_boss_level()
	for level: int in range(next_boss_level, get_boss_count() + 1):
		if level == next_boss_level or level == encounter_level or active_deck_ids.size() >= get_boss_reveal_threshold(level):
			reveal_boss(level)

func get_tier_progress() -> float:
	"""Returns the progress (0.0 to 1.0) towards the upcoming mini boss in the current tier."""
	var boss_level: int = bosses_defeated + 1
	var threshold_per_boss: float = 0.3333 if is_half_deck else 0.2
	var tier_target_pct: float = float(boss_level) * threshold_per_boss
	var tier_start_pct: float = float(boss_level - 1) * threshold_per_boss
	
	var total_cards: int = ordered_deck_pool.size()
	if total_cards <= 0:
		return 0.0
		
	var tier_target_cards: int = int(ceil(float(total_cards) * tier_target_pct))
	var tier_start_cards: int = 0
	if boss_level == 1:
		tier_start_cards = 5
	else:
		tier_start_cards = int(ceil(float(total_cards) * tier_start_pct))
		
	var cards_in_tier: int = max(1, tier_target_cards - tier_start_cards)
	var current_cards: int = active_deck_ids.size()
	var unlocked_in_tier: int = max(0, current_cards - tier_start_cards)
	
	return clampf(float(unlocked_in_tier) / float(cards_in_tier), 0.0, 1.0)

## Records a regular banner encounter in the history
func record_regular_banner(banner_id: StringName) -> void:
	if not regular_banner_history.has(banner_id):
		regular_banner_history[banner_id] = 0
	regular_banner_history[banner_id] += 1
	last_regular_banner_id = banner_id
	SignalBus.emit_signal("run_data_changed")

## Records an elite encounter in the history
func record_elite_encounter(elite_id: StringName) -> void:
	if not elite_encounter_history.has(elite_id):
		elite_encounter_history[elite_id] = 0
	elite_encounter_history[elite_id] += 1
	last_elite_id = elite_id
	# Emit signal to ensure UI/Save is updated
	SignalBus.emit_signal("run_data_changed")

## Records a boss encounter in the history
func record_boss_encounter(boss_id: StringName) -> void:
	if not boss_encounter_history.has(boss_id):
		boss_encounter_history[boss_id] = 0
	boss_encounter_history[boss_id] += 1
	last_boss_id = boss_id
	SignalBus.emit_signal("run_data_changed")

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return run_instances.get(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance_by_uuid(loc.unit_uuid)
		if is_instance_valid(parent) and loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
			var eq_uuid := parent.equipped_item_uuids[loc.index]
			return get_instance_by_uuid(eq_uuid) if not eq_uuid.is_empty() else null
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
	"""Test utility: unlock all recipes so spawned content can be merged."""
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

func has_locked_recipe_for_result(result_definition_id: StringName) -> bool:
	"""Returns true if there is at least one recipe that produces this definition
	which has not yet been unlocked for the current run."""
	if result_definition_id.is_empty():
		return false
	for recipe in Database.recipes.values():
		if is_instance_valid(recipe) and recipe.result_id == result_definition_id:
			if not is_recipe_unlocked(recipe.id):
				return true
	return false

func get_container(container_name: StringName) -> DataContainer:
	# Check if container exists
	if _containers.has(container_name):
		return _containers[container_name]
	
	var new_container: DataContainer = null
	if container_name == RUN_CONTAINER_TAGS.PLAYER_LINEUP:
		new_container = FixedArrayContainer.new(C.LINEUP_CAP)
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_SHELF:
		new_container = FixedArrayContainer.new(C.SHELF_CAP)
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
		new_container = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
	elif String(container_name).begins_with("RunInventoryT"):
		new_container = FixedArrayContainer.new(C.RUN_INVENTORY_CAP)
	
	if is_instance_valid(new_container):
		new_container.container_tag = container_name
		_containers[container_name] = new_container
		return new_container
	
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
		assert(not container_name.is_empty() and container_name != C.CONTAINER_EQUIPPED_ITEM, "RunState.add_instance: invalid container_name '%s'" % String(container_name))
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
					var uuid_to_replace = RNGManager.gacha_rng.pick_random(all_uuids)
					var loc_to_replace = get_location_for_uuid(uuid_to_replace)
					slot = loc_to_replace.index
					# Permanently remove the chosen instance from the run to make space
					remove_instance(uuid_to_replace)

			if slot == -1:
				return false
	else:
		if slot >= container.get_size():
			push_error("RunState.add_instance rejected: slot %d out of bounds in %s (capacity=%d)" % [slot, String(container_name), container.get_size()])
			return false
		var existing_uuid := container.get_uuid(slot)
		if not existing_uuid.is_empty():
			push_error("RunState.add_instance rejected: slot %d in %s already occupied by %s" % [slot, String(container_name), existing_uuid])
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
			var inv := get_container(RUN_CONTAINER_TAGS.PLAYER_SHELF)
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
				it2.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_SHELF
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
	# Moves an instance from source to target atomically. Handles equipping when target is equipped_item.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	if source_loc.container.is_empty() or target_loc.container.is_empty():
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

	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		return true

	# Pre-validate target container and slot BEFORE mutating source
	var to_container: DataContainer = get_container(target_loc.container)
	if not is_instance_valid(to_container) or not to_container.is_valid_index(target_loc.index):
		return false
	if not to_container.get_uuid(target_loc.index).is_empty():
		push_error("RunState.move_instance rejected: target slot %s:%d is occupied" % [String(target_loc.container), target_loc.index])
		return false

	# Clear source location
	if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent_unit: GachaBallInstance = get_instance_by_uuid(source_loc.unit_uuid)
		if not is_instance_valid(parent_unit) or source_loc.index < 0 or source_loc.index >= parent_unit.equipped_item_uuids.size():
			return false
		if parent_unit.equipped_item_uuids[source_loc.index] != instance.ball_uuid:
			return false
		parent_unit.unequip_item_bonus(instance)
		parent_unit.equipped_item_uuids[source_loc.index] = ""
	else:
		var from_container: DataContainer = get_container(source_loc.container)
		if not is_instance_valid(from_container) or not from_container.is_valid_index(source_loc.index):
			return false
		if from_container.get_uuid(source_loc.index) != instance.ball_uuid:
			return false
		from_container.set_uuid(source_loc.index, "")

	# Place into target index and update truth atomically
	to_container.set_uuid(target_loc.index, instance.ball_uuid)
	instance.location_container_tag = target_loc.container
	instance.location_slot_index = target_loc.index
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1

	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	# Swaps two instances across containers, supporting equipped slots atomically.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	if source_loc.container.is_empty() or target_loc.container.is_empty():
		return false

	# Normalize so if only one side is an equipped slot, it is target_loc
	if source_loc.container == C.CONTAINER_EQUIPPED_ITEM and target_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		return swap_instances(target_loc, source_loc)

	var a: GachaBallInstance = get_instance_by_location(source_loc)
	var b: GachaBallInstance = get_instance_by_location(target_loc)
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false

	# Swapping with an equipped slot
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var target_unit: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
		if not is_instance_valid(target_unit):
			return false
		var target_slot := target_loc.index
		if target_slot < 0 or target_slot >= target_unit.equipped_item_uuids.size():
			return false
		var a_def = a.get_definition()
		var b_def = b.get_definition()
		if not is_instance_valid(a_def) or a_def.category != &"ITEM":
			return false
		if not is_instance_valid(b_def) or b_def.category != &"ITEM":
			return false

		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			if source_loc.unit_uuid == target_loc.unit_uuid and source_loc.index == target_loc.index:
				return true
			var src_unit: GachaBallInstance = run_instances.get(source_loc.unit_uuid)
			if not is_instance_valid(src_unit) or source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
				return false
			if src_unit.equipped_item_uuids[source_loc.index] != a.ball_uuid or target_unit.equipped_item_uuids[target_slot] != b.ball_uuid:
				return false

			src_unit.unequip_item_bonus(a)
			src_unit.equipped_item_uuids[source_loc.index] = ""
			target_unit.unequip_item_bonus(b)
			target_unit.equipped_item_uuids[target_slot] = ""

			src_unit.equipped_item_uuids[source_loc.index] = b.ball_uuid
			b.equipped_on_uuid = src_unit.ball_uuid
			b.equipped_slot_index = source_loc.index
			b.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
			b.location_slot_index = source_loc.index
			src_unit.equip_item_bonus(b)

			target_unit.equipped_item_uuids[target_slot] = a.ball_uuid
			a.equipped_on_uuid = target_unit.ball_uuid
			a.equipped_slot_index = target_slot
			a.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
			a.location_slot_index = target_slot
			target_unit.equip_item_bonus(a)
		else:
			var src_container: DataContainer = get_container(source_loc.container)
			if not is_instance_valid(src_container) or not src_container.is_valid_index(source_loc.index):
				return false
			if src_container.get_uuid(source_loc.index) != a.ball_uuid or target_unit.equipped_item_uuids[target_slot] != b.ball_uuid:
				return false

			src_container.set_uuid(source_loc.index, b.ball_uuid)
			target_unit.unequip_item_bonus(b)
			target_unit.equipped_item_uuids[target_slot] = ""
			b.location_container_tag = source_loc.container
			b.location_slot_index = source_loc.index
			b.equipped_on_uuid = ""
			b.equipped_slot_index = -1

			target_unit.equipped_item_uuids[target_slot] = a.ball_uuid
			a.equipped_on_uuid = target_unit.ball_uuid
			a.equipped_slot_index = target_slot
			a.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
			a.location_slot_index = target_slot
			target_unit.equip_item_bonus(a)

		if OS.is_debug_build():
			_validate_state_consistency()
		SignalBus.emit_signal("run_data_changed")
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true

	# General container-to-container swap
	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		return true
	var a_container := get_container(source_loc.container)
	var b_container := get_container(target_loc.container)
	if not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return false
	if not a_container.is_valid_index(source_loc.index) or not b_container.is_valid_index(target_loc.index):
		return false
	if a_container.get_uuid(source_loc.index) != a.ball_uuid or b_container.get_uuid(target_loc.index) != b.ball_uuid:
		return false

	var b_uuid := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid)
	a.location_container_tag = target_loc.container
	a.location_slot_index = target_loc.index
	a.equipped_on_uuid = ""
	a.equipped_slot_index = -1
	b.location_container_tag = source_loc.container
	b.location_slot_index = source_loc.index
	b.equipped_on_uuid = ""
	b.equipped_slot_index = -1

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
	total_gold_earned += amount
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

func get_shrine_remove_cost() -> int:
	return max(5, shrine_remove_cost)

func increase_shrine_remove_cost() -> void:
	shrine_remove_cost = get_shrine_remove_cost() + 1
	SignalBus.emit_signal("run_data_changed")

func get_elite_reward_reroll_cost() -> int:
	return max(5, elite_reward_reroll_cost)

func increase_elite_reward_reroll_cost() -> void:
	elite_reward_reroll_cost = get_elite_reward_reroll_cost() + 1
	SignalBus.emit_signal("run_data_changed")


func register_and_equip_item(item: GachaBallInstance, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> bool:
	assert(is_instance_valid(item), "RunState.register_and_equip_item: item is null")
	assert(not run_instances.has(item.ball_uuid), "RunState.register_and_equip_item: item %s already registered" % item.ball_uuid)
	if unit_uuid.is_empty():
		return false
	var unit := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(unit):
		return false
	var item_def = item.get_definition()
	if not is_instance_valid(item_def) or item_def.category != &"ITEM":
		return false

	var target_slot := slot_index
	if target_slot < 0:
		var empty_idx := unit.equipped_item_uuids.find("")
		target_slot = empty_idx if empty_idx != -1 else 0
	if target_slot >= unit.equipped_item_uuids.size():
		return false

	var existing_uuid := unit.equipped_item_uuids[target_slot]
	var existing_item: GachaBallInstance = get_instance_by_uuid(existing_uuid) if not existing_uuid.is_empty() else null
	var shelf_container: DataContainer = null
	var shelf_empty_slot: int = -1
	if is_instance_valid(existing_item):
		shelf_container = get_container(RUN_CONTAINER_TAGS.PLAYER_SHELF)
		if not is_instance_valid(shelf_container):
			return false
		shelf_empty_slot = shelf_container.find_first_empty_slot()
		if shelf_empty_slot == -1:
			return false

	if is_instance_valid(existing_item):
		shelf_container.set_uuid(shelf_empty_slot, existing_item.ball_uuid)
		existing_item.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_SHELF
		existing_item.location_slot_index = shelf_empty_slot
		existing_item.equipped_on_uuid = ""
		existing_item.equipped_slot_index = -1

	run_instances[item.ball_uuid] = item
	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot

	if is_instance_valid(existing_item):
		unit.replace_item_bonus(existing_item, item)
	else:
		unit.equip_item_bonus(item)

	if OS.is_debug_build():
		_validate_state_consistency()
	if not silent:
		SignalBus.emit_signal("run_data_changed")
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func replace_units_for_merge(
	source_uuid: String,
	target_uuid: String,
	new_instance: GachaBallInstance,
	dest_container_name: StringName,
	dest_index: int,
	items_to_equip: Array
) -> bool:
	var source := get_instance_by_uuid(source_uuid)
	var target := get_instance_by_uuid(target_uuid)
	if not is_instance_valid(source) or not is_instance_valid(target) or not is_instance_valid(new_instance):
		return false
	var dest_container := get_container(dest_container_name)
	if not is_instance_valid(dest_container):
		return false

	var src_loc := source.get_location()
	var tgt_loc := target.get_location()
	if not is_instance_valid(src_loc) or not is_instance_valid(tgt_loc):
		return false

	# Validate destination slot availability BEFORE mutating anything
	if dest_index >= 0:
		if dest_index >= dest_container.get_size():
			return false
		var cur := dest_container.get_uuid(dest_index)
		if not cur.is_empty() and cur != source_uuid and cur != target_uuid:
			return false

	var keep_uuids: Dictionary = {}
	var max_slots := new_instance.equipped_item_uuids.size()
	for i in range(min(items_to_equip.size(), max_slots)):
		var keep_it: GachaBallInstance = items_to_equip[i]
		if is_instance_valid(keep_it):
			keep_uuids[keep_it.ball_uuid] = true

	var extra_items: Array[GachaBallInstance] = []
	for parent_u in [source, target]:
		for eq_uuid in parent_u.equipped_item_uuids:
			if not eq_uuid.is_empty() and not keep_uuids.has(eq_uuid):
				var eq_inst := get_instance_by_uuid(eq_uuid)
				if is_instance_valid(eq_inst):
					extra_items.append(eq_inst)

	if not extra_items.is_empty():
		var shelf := get_container(RUN_CONTAINER_TAGS.PLAYER_SHELF)
		if not is_instance_valid(shelf):
			return false
		var free_count := 0
		for u in shelf.get_all_uuids():
			if String(u).is_empty():
				free_count += 1
		if src_loc.container == RUN_CONTAINER_TAGS.PLAYER_SHELF:
			free_count += 1
		if tgt_loc.container == RUN_CONTAINER_TAGS.PLAYER_SHELF:
			free_count += 1
		if dest_container_name == RUN_CONTAINER_TAGS.PLAYER_SHELF:
			free_count -= 1
		if free_count < extra_items.size():
			return false

	# Unlink kept items from parent units
	var parent_units: Array[GachaBallInstance] = [source, target]
	for parent_u in parent_units:
		for s_idx in range(parent_u.equipped_item_uuids.size()):
			var eq_uuid: String = parent_u.equipped_item_uuids[s_idx]
			if eq_uuid.is_empty():
				continue
			var eq_inst := get_instance_by_uuid(eq_uuid)
			parent_u.equipped_item_uuids[s_idx] = ""
			if is_instance_valid(eq_inst):
				parent_u.unequip_item_bonus(eq_inst)

	# Remove source and target from their containers/slots and registry
	for pair in [[source, src_loc], [target, tgt_loc]]:
		var inst_p: GachaBallInstance = pair[0]
		var loc_p: LocationIdentifier = pair[1]
		if loc_p.container == C.CONTAINER_EQUIPPED_ITEM:
			var p_unit := get_instance_by_uuid(loc_p.unit_uuid)
			if is_instance_valid(p_unit) and loc_p.index >= 0 and loc_p.index < p_unit.equipped_item_uuids.size():
				if p_unit.equipped_item_uuids[loc_p.index] == inst_p.ball_uuid:
					p_unit.unequip_item_bonus(inst_p)
					p_unit.equipped_item_uuids[loc_p.index] = ""
		else:
			var c_p := get_container(loc_p.container)
			if is_instance_valid(c_p) and loc_p.index >= 0 and c_p.get_uuid(loc_p.index) == inst_p.ball_uuid:
				c_p.set_uuid(loc_p.index, "")
		run_instances.erase(inst_p.ball_uuid)

	# Place new_instance into dest_container
	var final_slot := dest_index
	if final_slot < 0:
		final_slot = dest_container.find_first_empty_slot()
		if final_slot == -1 and String(dest_container_name).begins_with("RunInventoryT"):
			var all_uuids := dest_container.get_all_non_empty_uuids()
			if all_uuids.size() > 0:
				var uuid_to_replace = RNGManager.gacha_rng.pick_random(all_uuids)
				var loc_to_replace := get_location_for_uuid(uuid_to_replace)
				final_slot = loc_to_replace.index
				remove_instance(uuid_to_replace)
		assert(final_slot != -1, "RunState.replace_units_for_merge: failed to allocate destination slot in %s" % String(dest_container_name))

	dest_container.set_uuid(final_slot, new_instance.ball_uuid)
	new_instance.location_container_tag = dest_container_name
	new_instance.location_slot_index = final_slot
	new_instance.equipped_on_uuid = ""
	new_instance.equipped_slot_index = -1
	run_instances[new_instance.ball_uuid] = new_instance

	# Rehome any extra items to PlayerShelf
	if not extra_items.is_empty():
		var shelf2 := get_container(RUN_CONTAINER_TAGS.PLAYER_SHELF)
		for ex_it in extra_items:
			var b_slot := shelf2.find_first_empty_slot()
			assert(b_slot != -1, "RunState.replace_units_for_merge: shelf overflow on extra item")
			shelf2.set_uuid(b_slot, ex_it.ball_uuid)
			ex_it.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_SHELF
			ex_it.location_slot_index = b_slot
			ex_it.equipped_on_uuid = ""
			ex_it.equipped_slot_index = -1

	# Directly equip kept items onto new_instance
	for i in range(min(items_to_equip.size(), max_slots)):
		var keep_it: GachaBallInstance = items_to_equip[i]
		if is_instance_valid(keep_it):
			new_instance.equipped_item_uuids[i] = keep_it.ball_uuid
			keep_it.equipped_on_uuid = new_instance.ball_uuid
			keep_it.equipped_slot_index = i
			keep_it.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
			keep_it.location_slot_index = i
			new_instance.equip_item_bonus(keep_it)

	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> bool:
	# Equips an item onto a unit atomically. Pre-validates all preconditions before mutating state.
	if item_uuid.is_empty() or unit_uuid.is_empty():
		return false
	var item := get_instance_by_uuid(item_uuid)
	var unit := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return false
	var item_def = item.get_definition()
	if not is_instance_valid(item_def) or item_def.category != &"ITEM":
		return false

	# Determine slot
	var target_slot := slot_index
	if target_slot < 0:
		var empty_idx := unit.equipped_item_uuids.find("")
		target_slot = empty_idx if empty_idx != -1 else 0
	if target_slot >= unit.equipped_item_uuids.size():
		return false

	# Self-equip no-op
	if item.equipped_on_uuid == unit.ball_uuid and item.equipped_slot_index == target_slot:
		return true

	# Pre-validate item's current source location BEFORE mutating anything
	var item_loc := item.get_location()
	if not is_instance_valid(item_loc):
		return false

	var prev_parent: GachaBallInstance = null
	var prev_slot: int = -1
	var src_container: DataContainer = null
	var src_slot: int = -1

	if item_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		prev_parent = get_instance_by_uuid(item.equipped_on_uuid)
		if not is_instance_valid(prev_parent):
			return false
		prev_slot = item.equipped_slot_index
		if prev_slot < 0 or prev_slot >= prev_parent.equipped_item_uuids.size() or prev_parent.equipped_item_uuids[prev_slot] != item.ball_uuid:
			return false
	else:
		src_container = get_container(item_loc.container)
		if not is_instance_valid(src_container) or not src_container.is_valid_index(item_loc.index):
			return false
		if src_container.get_uuid(item_loc.index) != item.ball_uuid:
			return false
		src_slot = item_loc.index

	# Pre-validate shelf capacity if replacing an existing item
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	var existing_item: GachaBallInstance = null
	var shelf_container: DataContainer = null
	if not existing_uuid.is_empty() and existing_uuid != item.ball_uuid:
		existing_item = get_instance_by_uuid(existing_uuid)
		if is_instance_valid(existing_item):
			shelf_container = get_container(RUN_CONTAINER_TAGS.PLAYER_SHELF)
			if not is_instance_valid(shelf_container):
				return false
			# If item is coming from PlayerShelf, freeing src_slot guarantees at least 1 empty shelf slot
			var item_frees_shelf_slot: bool = (item_loc.container == RUN_CONTAINER_TAGS.PLAYER_SHELF)
			if not item_frees_shelf_slot and shelf_container.find_first_empty_slot() == -1:
				return false

	# All preconditions verified — execute transition atomically
	if is_instance_valid(prev_parent):
		prev_parent.unequip_item_bonus(item)
		prev_parent.equipped_item_uuids[prev_slot] = ""
	elif is_instance_valid(src_container):
		src_container.set_uuid(src_slot, "")

	if is_instance_valid(existing_item):
		var empty := shelf_container.find_first_empty_slot()
		assert(empty != -1, "RunState.equip_item: expected empty shelf slot after precondition check")
		shelf_container.set_uuid(empty, existing_item.ball_uuid)
		existing_item.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_SHELF
		existing_item.location_slot_index = empty
		existing_item.equipped_on_uuid = ""
		existing_item.equipped_slot_index = -1

	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot

	if is_instance_valid(existing_item):
		unit.replace_item_bonus(existing_item, item)
	else:
		unit.equip_item_bonus(item)

	if OS.is_debug_build():
		_validate_state_consistency()
	if not silent:
		SignalBus.emit_signal("run_data_changed")
		SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Golden Rule Validation
# ------------------------------------------------------------------

func _validate_state_consistency() -> bool:
	var valid := _check_state_consistency()
	assert(valid, "RunState consistency invariant violated")
	return valid

func _check_state_consistency() -> bool:
	# Ensures no duplicate UUIDs across containers and truth matches index.
	var seen: Dictionary = {}
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
			if inst.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				push_error("Equipped item %s appears in a container slot" % u)
				return false
	for u in run_instances.keys():
		var inst: GachaBallInstance = run_instances[u]
		if not is_instance_valid(inst):
			push_error("Invalid run instance registered for UUID %s" % u)
			return false
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			push_error("Run instance %s returned invalid LocationIdentifier" % u)
			return false
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
			if loc.container == &"" or loc.container.is_empty():
				push_error("Run instance %s has empty container" % u)
				return false
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
	elites_encountered_in_tier = 0
	elite_milestones_offered.clear()
	total_enemies_defeated = 0
	total_gold_earned = 0
	shrine_remove_cost = 5
	elite_reward_reroll_cost = 5
	run_instances.clear()
	_containers.clear()
	flashcard_progress.clear()
	active_deck_ids.clear()
	cards_presented_count = 0
	last_challenge_met_unlock_requirements = false
	unlocked_recipes.clear() # All recipes start locked
	encounter_last_offered_day.clear()
	available_path_nodes.clear()
	regular_banner_history.clear()
	last_regular_banner_id = &""
	elite_encounter_history.clear()
	last_elite_id = &""
	boss_encounter_history.clear()
	revealed_boss_ids.clear()
	defeated_boss_marker_positions.clear()
	last_boss_id = &""

func initialize_run(hero_def_id: StringName, deck_id: StringName, deck_order: String = "REGULAR", deck_size: String = "FULL") -> void:
	start_new_run()
	self.deck_def_id = deck_id
	self.is_half_deck = (deck_size == "HALF")
	self.active_hero_set = Database.get_hero_set(hero_def_id)
	if active_hero_set == Database.SET_MERCENARY or active_hero_set == Database.SET_NOVICE:
		gold = 30
	
	var hero_def: GachaBallDefinition = Database.get_definition(hero_def_id) as GachaBallDefinition
	assert(hero_def != null and hero_def.is_hero, "Cannot initialize run for unknown hero: %s" % hero_def_id)
	hero_instance = GachaBallInstance.new()
	hero_instance.initialize(hero_def)
	add_instance(hero_instance, RUN_CONTAINER_TAGS.PLAYER_LINEUP, 0)

	var loadout: StartingLoadout = _roll_starting_loadout(hero_def_id, RNGManager.map_rng, RNGManager.gacha_rng)
	hero_element = loadout.hero_element
	hero_instance.components.append(loadout.hero_traits)
	dynamic_tag_overrides = loadout.unit_tag_overrides

	# Initialize flashcard progress for the selected deck
	var deck_card_ids = Database.get_cards_for_deck(deck_id)
	# Fallback if deck not found or empty (shouldn't happen with valid UI)
	if deck_card_ids.is_empty():
		# Try to fallback to all cards if deck lookup fails
		deck_card_ids = Database.flashcard_definitions.keys()
		
	ordered_deck_pool.clear()
	for id in deck_card_ids:
		ordered_deck_pool.append(StringName(id))
		
	if deck_size == "HALF":
		var half_size = max(1, ordered_deck_pool.size() / 2)
		if deck_order == "INVERTED":
			ordered_deck_pool = ordered_deck_pool.slice(ordered_deck_pool.size() - half_size, ordered_deck_pool.size())
			ordered_deck_pool.reverse()
		elif deck_order == "RANDOM":
			RNGManager.map_rng.shuffle(ordered_deck_pool)
			ordered_deck_pool = ordered_deck_pool.slice(0, half_size)
		else:
			ordered_deck_pool = ordered_deck_pool.slice(0, half_size)
	else:
		if deck_order == "INVERTED":
			ordered_deck_pool.reverse()
		elif deck_order == "RANDOM":
			RNGManager.map_rng.shuffle(ordered_deck_pool)
		
	for card_id in ordered_deck_pool:
		if not flashcard_progress.has(card_id):
			var progress = FlashcardProgress.new()
			progress.mastery_level = FlashcardProgress.MASTERY_MIN # Start at level 1 (Very Hard)
			flashcard_progress[card_id] = progress
	
	# Populate the initial active deck with the first 5 cards
	# We start with 5 and the first minigame will immediately add the 6th card
	for i in range(min(5, ordered_deck_pool.size())):
		active_deck_ids.append(ordered_deck_pool[i])
	
	refresh_boss_reveals()

	# Initial 5 cards are considered "introduced" to start expansion immediately
	cards_presented_count = 5
	
	# Create fresh empty inventory containers for tiers 1-3
	for t in [1, 2, 3]:
		var container_name: StringName = &"RunInventoryT%d" % t
		var inv_c := FixedArrayContainer.new(C.RUN_INVENTORY_CAP)
		inv_c.container_tag = container_name
		_containers[container_name] = inv_c

	# Create player trinket container
	var trinket_c := FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
	trinket_c.container_tag = RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	_containers[RUN_CONTAINER_TAGS.PLAYER_TRINKETS] = trinket_c

	var starters: Array[StringName] = loadout.starter_ids
	starters.append_array(GameManager.test_starting_items)

	for id in starters:
		var def: Resource = Database.get_definition(id)
		if not def:
			continue
			
		var inst := GachaBallInstance.new()
		if def is TrinketDefinition:
			inst.initialize_from_trinket(def)
		else:
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

## Evaluate a prospective loadout without advancing a live run's RNG streams.
static func preview_starting_loadout(hero_def_id: StringName, seed: int) -> StartingLoadout:
	var map_rng: SeededRNG = RNGManager.create_stream(seed, "map")
	var gacha_rng: SeededRNG = RNGManager.create_stream(seed, "gacha")
	# Run initialization consumes one gacha value when assigning the hero's UUID.
	gacha_rng.randi()
	return _roll_starting_loadout(hero_def_id, map_rng, gacha_rng)

static func _roll_starting_loadout(hero_def_id: StringName, map_rng: SeededRNG, gacha_rng: SeededRNG) -> StartingLoadout:
	var elemental_souls: Array[StringName] = [&"SOUL_FIRE", &"SOUL_EARTH", &"SOUL_WATER", &"SOUL_AIR"]
	var thematic_traits: Array[StringName] = [&"Food", &"Mecha", &"Animal", &"Plant", &"Toy", &"Appliance", &"Costume"]
	var class_traits: Array[StringName] = [&"Tank", &"Fighter", &"Support", &"Specialist", &"Mercenary"]
	var chosen_element: StringName = elemental_souls[map_rng.randi() % elemental_souls.size()]
	var bonus_tags: Array[StringName] = []
	var archetype_tag: StringName = &""

	match hero_def_id:
		&"hero_avenger":
			archetype_tag = &"Fighter"
			bonus_tags = [chosen_element, chosen_element, chosen_element, thematic_traits[map_rng.randi() % thematic_traits.size()]]
		&"hero_bastion":
			archetype_tag = &"Tank"
			bonus_tags = [chosen_element, chosen_element, chosen_element, thematic_traits[map_rng.randi() % thematic_traits.size()]]
		&"hero_bounty_hunter", &"hero":
			archetype_tag = &"Mercenary"
			var bounty_trait_pool: Array[StringName] = class_traits + thematic_traits
			var shiken_bonus_trait: StringName = _choose_distinct_hero_bonus_trait(bounty_trait_pool, archetype_tag, elemental_souls, map_rng)
			bonus_tags = [chosen_element, chosen_element, chosen_element, shiken_bonus_trait]
		&"hero_pyro":
			archetype_tag = &"Fire Ritual"
			chosen_element = &"SOUL_FIRE"
			bonus_tags = [chosen_element, chosen_element, chosen_element, class_traits[map_rng.randi() % class_traits.size()], thematic_traits[map_rng.randi() % thematic_traits.size()]]
		&"hero_starter":
			archetype_tag = &"Novice"
			var dan_bonus_trait: StringName = _choose_distinct_hero_bonus_trait(thematic_traits, archetype_tag, elemental_souls, map_rng)
			bonus_tags = [chosen_element, chosen_element, chosen_element, dan_bonus_trait]
		&"hero_timekeeper":
			archetype_tag = &"Support"
			bonus_tags = [chosen_element, chosen_element, chosen_element, thematic_traits[map_rng.randi() % thematic_traits.size()]]
	assert(not archetype_tag.is_empty(), "RunState._roll_starting_loadout: no hero constitution defined for '%s'" % hero_def_id)

	var hero_tags := TagComponent.new()
	hero_tags.id = &"hero_run_traits"
	hero_tags.category = &"TAG"
	hero_tags.source_type = &"RUN_STATE"
	hero_tags.is_persistent = true
	hero_tags.tags_to_add = [archetype_tag]
	hero_tags.tags_to_add.append_array(bonus_tags)

	var hero_set: StringName = Database.get_hero_set(hero_def_id)
	var starters: Array[StringName] = _get_fixed_starters_for_hero(hero_def_id)
	var bonus_starters: Array[StringName] = []
	var starter_pool: Array[GachaBallDefinition] = Database.get_all_pool_definitions(hero_set)
	for tier: int in [2, 3]:
		var candidates: Array[StringName] = []
		for definition: GachaBallDefinition in starter_pool:
			if definition.tier == tier and Database.get_entity_set(definition) == hero_set \
					and definition.category in [C.CATEGORY_UNIT, C.CATEGORY_ITEM] and not starters.has(definition.id):
				candidates.append(definition.id)
		assert(not candidates.is_empty(), "No Tier %d starter candidates for %s" % [tier, hero_set])
		bonus_starters.append(gacha_rng.pick_random(candidates))
	starters.append_array(bonus_starters)

	var loadout := StartingLoadout.new()
	loadout.hero_element = chosen_element
	loadout.hero_traits = hero_tags
	loadout.starter_ids = starters
	loadout.bonus_starter_ids = bonus_starters
	loadout.unit_tag_overrides = _get_hero_pack_tags(hero_def_id, chosen_element)
	return loadout

static func _choose_distinct_hero_bonus_trait(candidate_traits: Array[StringName], fixed_trait: StringName, elemental_souls: Array[StringName], rng: SeededRNG) -> StringName:
	var eligible_traits: Array[StringName] = []
	for candidate_trait in candidate_traits:
		if candidate_trait == fixed_trait or elemental_souls.has(candidate_trait):
			continue
		if not eligible_traits.has(candidate_trait):
			eligible_traits.append(candidate_trait)
	assert(not eligible_traits.is_empty(), "RunState._choose_distinct_hero_bonus_trait: no eligible bonus traits")
	var chosen_trait: StringName = rng.pick_random(eligible_traits)
	assert(chosen_trait != fixed_trait, "Hero bonus trait must differ from the fixed trait")
	assert(not elemental_souls.has(chosen_trait), "Hero bonus trait must differ from all elemental souls")
	return chosen_trait

static func _get_fixed_starters_for_hero(hero_id: StringName) -> Array[StringName]:
	var starters: Array[StringName] = _get_hero_starter_pack(hero_id)
	var emblem_id: StringName
	match hero_id:
		&"hero_starter":
			emblem_id = &"item_novice_emblem"
		&"hero_bounty_hunter", &"hero":
			emblem_id = &"item_mercenary_emblem"
		&"hero_avenger":
			emblem_id = &"item_emblem_specialist"
		&"hero_bastion":
			emblem_id = &"item_emblem_tank"
		&"hero_pyro":
			emblem_id = &"item_emblem_fire"
		&"hero_timekeeper":
			emblem_id = &"item_emblem_support"
	assert(not emblem_id.is_empty(), "No starter Emblem configured for %s" % hero_id)
	starters.append_array([C.ITEM_INCUBATOR, C.ITEM_ENCOUNTER_TONIC, C.ITEM_DAMAGE_VIAL, emblem_id])
	return starters

static func _get_hero_starter_pack(hero_id: StringName) -> Array[StringName]:
	if hero_id == &"hero_starter":
		return [
			&"?NovPla", &"?NovPla", &"?NovPla",
			&"ETnkPla", &"ETnkPla",
			&"FFigMec", &"FFigMec",
			&"WSupAni", &"WSupAni",
			&"ASpeFod", &"ASpeFod",
			&"item_study_pouch", &"item_study_pouch",
			&"item_t1_a", &"item_t1_a",
			&"item_t1_b", &"item_t1_b",
			&"trinket_trait_novice"
		]
	if hero_id == &"hero_bounty_hunter" or hero_id == &"hero":
		return [
			&"?MerSpe", &"?MerSpe", &"?MerSpe",
			&"ETnkPla", &"ETnkPla",
			&"FFigMec", &"FFigMec",
			&"WSupAni", &"WSupAni",
			&"ASpeFod", &"ASpeFod",
			&"item_claim_ticket", &"item_claim_ticket",
			&"item_t1_a", &"item_t1_a",
			&"item_t1_b", &"item_t1_b",
			&"trinket_trait_mercenary"
		]
	var starters: Array[StringName] = [
		&"ETnkPla", &"ETnkPla", &"ETnkPla",
		&"FFigMec", &"FFigMec", &"FFigMec",
		&"WSupAni", &"WSupAni", &"WSupAni",
		&"ASpeFod", &"ASpeFod", &"ASpeFod",
		&"item_t1_a", &"item_t1_a",
		&"item_t1_b", &"item_t1_b"
	]
	match hero_id:
		&"hero_avenger":
			starters.append(&"trinket_trait_specialist")
		&"hero_bastion":
			starters.append(&"trinket_trait_tank")
		&"hero_pyro":
			starters.append(&"trinket_trait_fire")
		&"hero_starter":
			starters.append(&"trinket_beginners_charm")
		&"hero_timekeeper":
			starters.append(&"trinket_trait_support")
	return starters

static func _get_hero_pack_tags(hero_id: StringName, rolled_element: StringName) -> Dictionary:
	var overrides: Dictionary = {}
	if hero_id == &"hero_bounty_hunter" or hero_id == &"hero":
		var bounty_hunter_unit_tags: Dictionary = {
			&"?MerSpe": [rolled_element, &"Mercenary", &"Specialist"],
			&"?ASpeMerFodToy": [rolled_element, &"SOUL_AIR", &"Specialist", &"Mercenary", &"Food", &"Toy"],
			&"E?TnkMerPlaToy": [&"SOUL_EARTH", rolled_element, &"Tank", &"Mercenary", &"Plant", &"Toy"],
			&"F?FigMerMecApp": [&"SOUL_FIRE", rolled_element, &"Fighter", &"Mercenary", &"Mecha", &"Appliance"],
			&"W?SupMerAniCos": [&"SOUL_WATER", rolled_element, &"Support", &"Mercenary", &"Animal", &"Costume"],
			&"E??ATnkSpeMerFodPlaToy": [&"SOUL_EARTH", rolled_element, rolled_element, &"SOUL_AIR", &"Tank", &"Specialist", &"Mercenary", &"Food", &"Plant", &"Toy"],
			&"FW??FigSupMerAniMecAppCos": [&"SOUL_FIRE", &"SOUL_WATER", rolled_element, rolled_element, &"Fighter", &"Support", &"Mercenary", &"Animal", &"Mecha", &"Appliance", &"Costume"],
			&"W??ASupSpeMerFodAniToyCos": [&"SOUL_WATER", rolled_element, rolled_element, &"SOUL_AIR", &"Support", &"Specialist", &"Mercenary", &"Food", &"Animal", &"Toy", &"Costume"],
			&"F??AFigSpeMerFodMecToyApp": [&"SOUL_FIRE", rolled_element, rolled_element, &"SOUL_AIR", &"Fighter", &"Specialist", &"Mercenary", &"Food", &"Mecha", &"Toy", &"Appliance"],
			&"EF??TnkFigMerMecPlaToyApp": [&"SOUL_EARTH", &"SOUL_FIRE", rolled_element, rolled_element, &"Tank", &"Fighter", &"Mercenary", &"Mecha", &"Plant", &"Toy", &"Appliance"],
			&"EW??TnkSupMerAniPlaToyCos": [&"SOUL_EARTH", &"SOUL_WATER", rolled_element, rolled_element, &"Tank", &"Support", &"Mercenary", &"Animal", &"Plant", &"Toy", &"Costume"]
		}
		for unit_id in bounty_hunter_unit_tags:
			var updated_tags: Array[StringName] = []
			for tag in bounty_hunter_unit_tags[unit_id]:
				updated_tags.append(tag)
			overrides[unit_id] = updated_tags
	elif hero_id == &"hero_starter":
		var novice_unit_tags: Dictionary = {
			&"?NovPla": [rolled_element, &"Novice", &"Plant"],
			&"?ANovFod": [rolled_element, &"SOUL_AIR", &"Novice", &"Food"],
			&"E?NovPla": [&"SOUL_EARTH", rolled_element, &"Novice", &"Plant"],
			&"F?NovApp": [&"SOUL_FIRE", rolled_element, &"Novice", &"Appliance"],
			&"W?NovCos": [&"SOUL_WATER", rolled_element, &"Novice", &"Costume"],
			&"E??ANovPla": [&"SOUL_EARTH", rolled_element, rolled_element, &"SOUL_AIR", &"Novice", &"Plant"],
			&"F??ANovFod": [&"SOUL_FIRE", rolled_element, rolled_element, &"SOUL_AIR", &"Novice", &"Food"],
			&"W??ANovCos": [&"SOUL_WATER", rolled_element, rolled_element, &"SOUL_AIR", &"Novice", &"Costume"],
			&"EF??NovApp": [&"SOUL_EARTH", &"SOUL_FIRE", rolled_element, rolled_element, &"Novice", &"Appliance"],
			&"EW??NovPla": [&"SOUL_EARTH", &"SOUL_WATER", rolled_element, rolled_element, &"Novice", &"Plant"],
			&"FW??NovAni": [&"SOUL_FIRE", &"SOUL_WATER", rolled_element, rolled_element, &"Novice", &"Animal"]
		}
		for unit_id in novice_unit_tags:
			var updated_tags: Array[StringName] = []
			for tag in novice_unit_tags[unit_id]:
				updated_tags.append(tag)
			overrides[unit_id] = updated_tags

	return overrides

func get_effective_unit_tags(unit_def_id: StringName, default_tags: Array[StringName] = []) -> Array[StringName]:
	if dynamic_tag_overrides.has(unit_def_id):
		var overrides: Array[StringName] = []
		overrides.append_array(dynamic_tag_overrides[unit_def_id])
		return overrides
	return default_tags.duplicate()

func has_locked_cards() -> bool:
	if deck_def_id == &"":
		return false
	return active_deck_ids.size() < ordered_deck_pool.size()

func unlock_next_deck_card() -> StringName:
	"""Authoritative single source of truth for deck unlocking.
	Unlocks the next locked card from the ordered deck pool, initializes its progress,
	synchronizes active_deck_ids and cards_presented_count, and returns the unlocked card ID."""
	if not has_locked_cards():
		return &""
	
	for card_id in ordered_deck_pool:
		if not active_deck_ids.has(card_id):
			active_deck_ids.append(card_id)
			if not flashcard_progress.has(card_id):
				var progress = FlashcardProgress.new()
				progress.mastery_level = FlashcardProgress.MASTERY_MIN
				flashcard_progress[card_id] = progress
			cards_presented_count = active_deck_ids.size()
			refresh_boss_reveals()
			SignalBus.emit_signal("run_data_changed")
			return card_id
			
	return &""

func check_deck_expansion() -> bool:
	"""Every time this is called, add EXACTLY ONE new card if available.
	Delegates to unlock_next_deck_card() as the single source of truth."""
	return not unlock_next_deck_card().is_empty()

func prismatize_unit(instance: GachaBallInstance) -> void:
	"""POC Helper: Transforms a unit instance into a Prismatic variant with boosted stats and abilities."""
	if not is_instance_valid(instance):
		return
	instance.apply_prismatic_variant()

# ------------------------------------------------------------------
# Serialization (Save/Load)
# ------------------------------------------------------------------

## Converts the entire run state to a Dictionary for saving.
func to_save_dict(refresh_elapsed_time: bool = true) -> Dictionary:
	if refresh_elapsed_time and is_instance_valid(ActionQueue):
		elapsed_simulation_time = ActionQueue.get_global_run_timer()

	var saved_boss_ids: Dictionary = {}
	for level: int in revealed_boss_ids:
		saved_boss_ids[str(level)] = String(revealed_boss_ids[level])
	var saved_boss_positions: Dictionary = {}
	for level: int in defeated_boss_marker_positions:
		saved_boss_positions[str(level)] = defeated_boss_marker_positions[level]

	var data: Dictionary = {
		"run_id": run_id,
		"run_seed": run_seed,
		"gold": gold,
		"day": day,
		"current_boss_level": current_boss_level,
		"current_elite_level": current_elite_level,
		"bosses_defeated": bosses_defeated,
		"elites_defeated": elites_defeated,
		"elites_encountered_in_tier": elites_encountered_in_tier,
		"elite_milestones_offered": elite_milestones_offered.duplicate(),
		"total_enemies_defeated": total_enemies_defeated,
		"total_gold_earned": total_gold_earned,
		"total_tokens_earned": total_tokens_earned,
		"current_room_tokens": current_room_tokens,
		"next_battle_minigame_bonus_time": next_battle_minigame_bonus_time,
		"elapsed_simulation_time": elapsed_simulation_time,
		"shrine_remove_cost": shrine_remove_cost,
		"elite_reward_reroll_cost": elite_reward_reroll_cost,
		"merge_encounter_cost": merge_encounter_cost,
		"get_tokens_cost": get_tokens_cost,
		"deck_def_id": String(deck_def_id),
		"is_half_deck": is_half_deck,
		"cards_presented_count": cards_presented_count,
		"last_challenge_met_unlock_requirements": last_challenge_met_unlock_requirements,
		"last_regular_banner_id": String(last_regular_banner_id),
		"regular_banner_history": _serialize_stringname_int_dict(regular_banner_history),
		"last_elite_id": String(last_elite_id),
		"elite_encounter_history": _serialize_elite_encounter_history(),
		"last_boss_id": String(last_boss_id),
		"boss_encounter_history": _serialize_stringname_int_dict(boss_encounter_history),
		"revealed_boss_ids": saved_boss_ids,
		"defeated_boss_marker_positions": saved_boss_positions,
		"active_hero_set": String(get_active_hero_set()),
		"hero_element": String(hero_element),
		"encounter_last_offered_day": _serialize_encounter_last_offered_day(),
		"available_path_nodes": _serialize_available_path_nodes(),
		"rng_state": RNGManager.serialize() if is_instance_valid(RNGManager) else {},
		"uuid_state": UUIDUtils.serialize_state() if is_instance_valid(UUIDUtils) else {},
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
	run_id = data.get("run_id", "")
	run_seed = data.get("run_seed", 0)
	if is_instance_valid(UUIDUtils):
		var uuid_state: Variant = data.get("uuid_state", {})
		if uuid_state is Dictionary:
			UUIDUtils.restore_state(uuid_state, run_id)
		else:
			UUIDUtils.begin_run_scope(run_id)
	gold = data.get("gold", 0)
	day = data.get("day", 1)
	current_boss_level = data.get("current_boss_level", 0)
	current_elite_level = data.get("current_elite_level", 0)
	bosses_defeated = data.get("bosses_defeated", 0)
	elites_defeated = data.get("elites_defeated", 0)
	elites_encountered_in_tier = data.get("elites_encountered_in_tier", 0)
	elite_milestones_offered.clear()
	for m in data.get("elite_milestones_offered", []):
		elite_milestones_offered.append(int(m))
	total_enemies_defeated = data.get("total_enemies_defeated", 0)
	total_gold_earned = data.get("total_gold_earned", 0)
	total_tokens_earned = data.get("total_tokens_earned", 0)
	current_room_tokens = data.get("current_room_tokens", 0)
	next_battle_minigame_bonus_time = float(data.get("next_battle_minigame_bonus_time", 0.0))
	elapsed_simulation_time = data.get("elapsed_simulation_time", 0.0)
	shrine_remove_cost = data.get("shrine_remove_cost", data.get("black_market_remove_cost", 5))
	elite_reward_reroll_cost = data.get("elite_reward_reroll_cost", 5)
	merge_encounter_cost = data.get("merge_encounter_cost", 5)
	get_tokens_cost = data.get("get_tokens_cost", 5)
	deck_def_id = StringName(data.get("deck_def_id", ""))
	is_half_deck = data.get("is_half_deck", false)
	cards_presented_count = data.get("cards_presented_count", 0)
	last_challenge_met_unlock_requirements = data.get("last_challenge_met_unlock_requirements", false)
	last_regular_banner_id = StringName(data.get("last_regular_banner_id", ""))
	_deserialize_stringname_int_dict(regular_banner_history, data.get("regular_banner_history", {}))
	last_elite_id = StringName(data.get("last_elite_id", ""))
	_deserialize_elite_encounter_history(data.get("elite_encounter_history", {}))
	last_boss_id = StringName(data.get("last_boss_id", ""))
	_deserialize_stringname_int_dict(boss_encounter_history, data.get("boss_encounter_history", {}))
	revealed_boss_ids.clear()
	for level: Variant in data.get("revealed_boss_ids", {}):
		revealed_boss_ids[int(level)] = StringName(data["revealed_boss_ids"][level])
	defeated_boss_marker_positions.clear()
	for level: Variant in data.get("defeated_boss_marker_positions", {}):
		defeated_boss_marker_positions[int(level)] = float(data["defeated_boss_marker_positions"][level])
	active_hero_set = StringName(data.get("active_hero_set", Database.SET_BASE))
	
	_deserialize_encounter_last_offered_day(data.get("encounter_last_offered_day", {}))
	_deserialize_available_path_nodes(data.get("available_path_nodes", []))
	
	if data.has("rng_state") and is_instance_valid(RNGManager):
		var rng_dict: Dictionary = data.get("rng_state", {})
		if not rng_dict.is_empty():
			RNGManager.deserialize(rng_dict)
	
	# Clear and restore containers
	_containers.clear()
	var cont_data: Dictionary = data.get("containers", {}).duplicate(true)
	if cont_data.has("PlayerBench"):
		assert(not cont_data.has(String(RUN_CONTAINER_TAGS.PLAYER_SHELF)), "RunState.from_save_dict: save contains both legacy PlayerBench and PlayerShelf containers")
		cont_data[String(RUN_CONTAINER_TAGS.PLAYER_SHELF)] = cont_data["PlayerBench"]
		cont_data.erase("PlayerBench")
	for cname_str in cont_data.keys():
		var cname := StringName(cname_str)
		var uuids: Array = cont_data[cname_str]
		var container: DataContainer
		# Create appropriate container type based on name
		if cname_str.begins_with("RunInventoryT"):
			container = FixedArrayContainer.new(C.RUN_INVENTORY_CAP)
		elif cname == RUN_CONTAINER_TAGS.PLAYER_LINEUP:
			container = FixedArrayContainer.new(C.LINEUP_CAP)
		elif cname == RUN_CONTAINER_TAGS.PLAYER_SHELF:
			container = FixedArrayContainer.new(C.SHELF_CAP)
		elif cname == RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
			container = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
		else:
			container = FixedArrayContainer.new(max(5, uuids.size()))
		# Populate container with saved UUIDs
		container.container_tag = cname
		for i in range(uuids.size()):
			if i < container.get_size():
				container.set_uuid(i, uuids[i])
		_containers[cname] = container

	# Clear and restore instances in deterministic container order
	run_instances.clear()
	hero_instance = null
	var inst_data: Dictionary = data.get("instances", {})
	var restored_uuids := {}
	
	for cname in [RUN_CONTAINER_TAGS.PLAYER_LINEUP, RUN_CONTAINER_TAGS.PLAYER_SHELF, &"RunInventoryT1", &"RunInventoryT2", &"RunInventoryT3", RUN_CONTAINER_TAGS.PLAYER_TRINKETS]:
		var uuids: Array = cont_data.get(String(cname), [])
		for uuid in uuids:
			if not uuid.is_empty() and inst_data.has(uuid) and not restored_uuids.has(uuid):
				var inst := GachaBallInstance.new()
				inst.from_save_dict(inst_data[uuid])
				run_instances[uuid] = inst
				restored_uuids[uuid] = true
				var def_id := String(inst.definition_id)
				if def_id == "hero" or def_id.begins_with("hero_"):
					hero_instance = inst

	var remaining_uuids: Array = []
	for uuid in inst_data.keys():
		if not restored_uuids.has(uuid):
			remaining_uuids.append(uuid)
	remaining_uuids.sort()
	for uuid in remaining_uuids:
		var inst := GachaBallInstance.new()
		inst.from_save_dict(inst_data[uuid])
		run_instances[uuid] = inst
		var def_id := String(inst.definition_id)
		if def_id == "hero" or def_id.begins_with("hero_"):
			hero_instance = inst
	
	# Restore flashcard progress
	_deserialize_flashcard_progress(data.get("flashcard_progress", {}))
	_deserialize_active_deck_ids(data.get("active_deck_ids", []))
	_deserialize_ordered_deck_pool(data.get("ordered_deck_pool", []))
	refresh_boss_reveals()
	
	# Restore unlocked recipes
	_deserialize_unlocked_recipes(data.get("unlocked_recipes", {}))

	# Reconcile active_hero_set with hero_instance (healing legacy or corrupted saves)
	hero_element = StringName(data.get("hero_element", ""))
	if is_instance_valid(hero_instance):
		var expected_set: StringName = Database.get_hero_set(hero_instance.definition_id)
		if expected_set != Database.SET_BASE:
			active_hero_set = expected_set
		if hero_element.is_empty():
			var souls: Dictionary = hero_instance.get_trait_soul_counts()
			for s in ["FIRE", "EARTH", "WATER", "AIR"]:
				if souls.get(s, 0) > 0:
					hero_element = StringName("SOUL_" + s)
					break
		if not hero_element.is_empty():
			dynamic_tag_overrides = _get_hero_pack_tags(hero_instance.definition_id, hero_element)

func _serialize_available_path_nodes() -> Array:
	var result: Array = []
	for node in available_path_nodes:
		if is_instance_valid(node) and node.has_method("to_dict"):
			result.append(node.to_dict())
	return result

func _deserialize_available_path_nodes(data: Array) -> void:
	available_path_nodes.clear()
	for node_data in data:
		if node_data is Dictionary:
			available_path_nodes.append(PathNodeDefinition.from_dict(node_data))

func _serialize_encounter_last_offered_day() -> Dictionary:
	var result: Dictionary = {}
	for key in encounter_last_offered_day.keys():
		result[String(key)] = encounter_last_offered_day[key]
	return result

func _deserialize_encounter_last_offered_day(data: Dictionary) -> void:
	encounter_last_offered_day.clear()
	for key_str in data.keys():
		encounter_last_offered_day[String(key_str)] = int(data[key_str])

func _serialize_elite_encounter_history() -> Dictionary:
	var result: Dictionary = {}
	for key in elite_encounter_history.keys():
		result[String(key)] = elite_encounter_history[key]
	return result

func _deserialize_elite_encounter_history(data: Dictionary) -> void:
	elite_encounter_history.clear()
	for key_str in data.keys():
		elite_encounter_history[StringName(key_str)] = int(data[key_str])

func _serialize_stringname_int_dict(dict: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in dict.keys():
		result[String(key)] = int(dict[key])
	return result

func _deserialize_stringname_int_dict(target: Dictionary, data: Dictionary) -> void:
	target.clear()
	for key_str in data.keys():
		target[StringName(key_str)] = int(data[key_str])

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
