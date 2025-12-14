class_name BattleManager
extends Node

const RS = preload("res://scripts/RunState.gd")
enum Phases {START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER}
var _current_battle_phase: Phases

var _actor_queue: Array[GachaBallInstance] = [] # Dynamic list of units to act this turn
var _pending_reactions: Array[EffectRequest] = [] # New priority-driven queue
var _inline_events: Array[CombatEvent] = [] # Events from on_before_attack processing
var _is_processing_effect: bool = false
var _battle_over_deferred: bool = false
var _battle_over_emitted: bool = false
var is_test_mode: bool = false


const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
	ENEMY_TRINKETS = &"EnemyTrinkets",
	PLAYER_TRINKETS = &"PlayerTrinkets",
}

var _battle_instances: Dictionary = {}
var _containers: Dictionary = {}
var enemy_trinkets: Array[GachaBallInstance] = []

const FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
var _gacha_tokens: int = 0
var _last_minigame_results: Dictionary = {}
var _current_turn: int = 0
var _turn_start_abilities_triggered: bool = false

# Turn-scoped metadata for first-killed tracking and resurrection flags
var _turn_metadata: Dictionary = {}

# Turn-scoped death registry: {uuid: {team, died_in_phase, def_id}}
# Cleared only at the start of each combat phase, persists across all phases within a turn
# This is the SINGLE source of truth for "has this unit already died this turn"
var _dead_this_turn: Dictionary = {}

# -----------------------------------------------------------------------------
# INITIALIZATION & SETUP
# -----------------------------------------------------------------------------
@onready var _animator: Node = $"../BattleAnimator"

func _resolve_animator() -> void:
	if is_instance_valid(_animator):
		return
	var candidate = get_tree().get_first_node_in_group("battle_animator")
	if is_instance_valid(candidate):
		_animator = candidate
		if not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
			_animator.turn_animation_finished.connect(_on_turn_animation_finished)

func _ready() -> void:
	var existing := get_tree().get_nodes_in_group("battle_manager")
	if existing.size() > 0:
		var is_first = true
		for node in existing:
			if node != self: is_first = false; break
		if not is_first: queue_free(); return

	add_to_group("battle_manager")
	GameManager.register_battle_manager(self) # ADD THIS LINE
	
	# Sync test mode flag
	is_test_mode = GameManager.is_test_mode
	
	_change_phase(Phases.MANAGEMENT)

	_connect_signals()
	# Connect to flashcard completion signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)
	_resolve_animator()
	if is_instance_valid(_animator) and not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.connect(_on_turn_animation_finished)

func get_current_phase() -> Phases:
	return _current_battle_phase

func _exit_tree() -> void:
	GameManager.unregister_battle_manager() # ADD THIS LINE
	GameManager.is_in_battle = false
	SignalBus.emit_signal("battle_state_changed", false)
	if SignalBus.is_connected("end_turn_requested", _on_end_turn_requested):
		SignalBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if SignalBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		SignalBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if SignalBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.is_connected("results_acknowledged", _on_results_acknowledged):
		SignalBus.results_acknowledged.disconnect(_on_results_acknowledged)
	if is_instance_valid(_animator) and _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.disconnect(_on_turn_animation_finished)

func _connect_signals() -> void:
	SignalBus.end_turn_requested.connect(_on_end_turn_requested)
	SignalBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	# Apply deaths after animator finishes death fades
	if SignalBus.has_signal("apply_deaths_requested") and not SignalBus.is_connected("apply_deaths_requested", _on_apply_deaths_requested):
		SignalBus.apply_deaths_requested.connect(_on_apply_deaths_requested)
	# Removed legacy reshuffle trigger; draw now reshuffles atomically when needed.

func _emit_battle_inventory_changed() -> void:
	SignalBus.emit_signal("battle_inventory_changed")


func start_battle(encounter_def: EncounterDefinition) -> void:
	# Clear any existing selection when entering battle
	SignalBus.emit_signal("selection_clear_requested")
	# Create a fresh battle state with copies of units from run state.
	# IMPORTANT: The battle operates on these copies, leaving the original run state untouched.
	# Any changes to units during battle (HP, stats, etc.) will be discarded when the battle ends.
	_setup_battle(encounter_def)
	GameManager.is_in_battle = true
	SignalBus.emit_signal("battle_state_changed", true)
	SignalBus.emit_signal("battle_state_changed", true)
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Emit unit_stats_changed for all units that have equipped items after UI is populated
	call_deferred("_emit_stats_changed_for_equipped_units")
	
	# Start the first turn with the mini-game
	# In test mode, stay in MANAGEMENT to allow user to spawn trinkets/units first
	if not is_test_mode:
		call_deferred("_change_phase", Phases.START_OF_TURN)

func _setup_battle(encounter_def: EncounterDefinition = null) -> void:
	# IMPORTANT: When setting up a battle, we create fresh copies of all units from the run state.
	# These battle copies should start with their base stats (from their definition) and then have
	# equipment bonuses applied. Any stat changes from previous battles should be discarded.
	# This ensures battles always start from a clean, deterministic state.
	_battle_instances.clear()
	_containers.clear()
	_actor_queue.clear()
	_pending_reactions.clear()
	_inline_events.clear()
	_battle_over_emitted = false
	_battle_over_deferred = false
	_current_turn = 0 # Initialize turn counter
	_gacha_tokens = 0
	enemy_trinkets.clear()
	
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()
	var permanent_to_battle_uuid_map: Dictionary = {}

	# First pass: Create all battle copies and map their new UUIDs
	var hero_instance: GachaBallInstance = null
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or ((def is GachaBallDefinition) and def.tags and def.tags.has("hero"))
		if is_hero:
			hero_instance = perm_inst
			# Create a battle copy for the hero to prevent stat changes from persisting
			var hero_battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
			if is_instance_valid(hero_battle_copy):
				_battle_instances[hero_battle_copy.ball_uuid] = hero_battle_copy
				permanent_to_battle_uuid_map[perm_inst.ball_uuid] = hero_battle_copy.ball_uuid
			continue
		
		# Skip trinkets - they don't need battle copies and don't have base stats
		if def.category == &"TRINKET":
			continue
			
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy): continue
		_battle_instances[battle_copy.ball_uuid] = battle_copy
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

	# Second pass: Remap equipped item UUIDs on all battle copies (skip hero)
	for battle_uuid in _battle_instances:
		var battle_inst = _battle_instances[battle_uuid]
		if battle_inst.get_definition().category != &"UNIT": continue
		var original_equipped_uuids = battle_inst.equipped_item_uuids.duplicate()
		battle_inst.equipped_item_uuids.clear()
		battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())
		battle_inst.equipped_item_uuids.fill("")
		for i in range(original_equipped_uuids.size()):
			var permanent_item_uuid = original_equipped_uuids[i]
			if not permanent_item_uuid.is_empty() and permanent_to_battle_uuid_map.has(permanent_item_uuid):
				var battle_item_uuid: String = permanent_to_battle_uuid_map[permanent_item_uuid]
				battle_inst.equipped_item_uuids[i] = battle_item_uuid
				var item_instance: GachaBallInstance = _battle_instances.get(battle_item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i

	# Third pass: Place all instances in their correct, stable locations.
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or ((def is GachaBallDefinition) and def.tags and def.tags.has("hero"))
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc): continue
		if is_hero:
			# Place the hero's battle copy in PlayerLineup at position 0
			var hero_battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid)
			if hero_battle_uuid:
				var container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
				container.set_uuid(0, hero_battle_uuid)
				_update_instance_location(hero_battle_uuid, BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)
			continue
		
		# Skip trinkets - they don't have battle copies
		if def.category == &"TRINKET":
			continue
			
		var battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid)
		if not battle_uuid: continue
		var battle_copy = _battle_instances[battle_uuid]
		# An item's location is determined by what it's equipped to. Skip direct placement.
		if not battle_copy.equipped_on_uuid.is_empty():
			continue
		var target_container_name: StringName
		if perm_loc.container.begins_with("RunInventoryT"):
			var perm_def = perm_inst.get_definition()
			if perm_def is GachaBallDefinition:
				var tier = perm_def.tier
				target_container_name = &"BattleInventoryT%d" % tier
			else:
				# Skip non-GachaBallDefinition items (e.g., trinkets)
				continue
		else:
			match perm_loc.container:
				RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
				RS.RUN_CONTAINER_TAGS.PLAYER_BENCH:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_BENCH
				RS.RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
					target_container_name = BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
				_:
					# If it's not a recognized container, skip this instance
					continue

		var container: DataContainer = get_container(target_container_name)
		var index = perm_loc.index
		container.set_uuid(index, battle_copy.ball_uuid)
		_update_instance_location(battle_copy.ball_uuid, target_container_name, index)

	# Trinkets: enemy population and exclusivity
	# Enemy trinkets now come from the EncounterDefinition, populated by the EncounterGenerator
	_setup_enemy_lineup(encounter_def)
	
	# Setup enemy trinkets from encounter definition
	if not is_test_mode and is_instance_valid(encounter_def):
		_setup_enemy_trinkets_from_encounter(encounter_def)
	# Copy player trinkets from run state to battle instances
	_setup_player_trinkets()
	
	# Trigger on_battle_start for all units
	_trigger_battle_start_abilities()


func _setup_enemy_lineup(encounter_def: EncounterDefinition = null) -> void:
	# NOTE: Test mode now uses this function via register_test_unit() for proper initialization parity
	if encounter_def:
		# Use the provided encounter definition
		var lineup_container: DataContainer = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		
		for placement in encounter_def.enemy_placements:
			var unit_def = Database.get_definition(placement.id)
			if not is_instance_valid(unit_def): continue
			
			var enemy_inst = GachaBallInstance.new()
			enemy_inst.initialize(unit_def)
			_battle_instances[enemy_inst.ball_uuid] = enemy_inst
			
			# Equip items
			for item_id in placement.get("items", []):
				var item_def = Database.get_definition(item_id)
				if not is_instance_valid(item_def): continue
				
				var item_inst = GachaBallInstance.new()
				item_inst.initialize(item_def)
				_battle_instances[item_inst.ball_uuid] = item_inst
				
				_perform_equip(item_inst, enemy_inst)
			
			lineup_container.set_uuid(placement.position, enemy_inst.ball_uuid)
			_update_instance_location(enemy_inst.ball_uuid, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, placement.position)
			# Note: unit_stats_changed will be emitted after UI is populated
	else:
		# Fallback to hardcoded enemy lineup
		var enemy_unit_ids = [&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d", &"enemy_hero"]
		var lineup_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		
		for i in range(min(enemy_unit_ids.size(), 5)):
			var unit_def = Database.get_definition(enemy_unit_ids[i])
			if not is_instance_valid(unit_def): continue
			
			var enemy_inst = GachaBallInstance.new()
			enemy_inst.initialize(unit_def)
			_battle_instances[enemy_inst.ball_uuid] = enemy_inst
			
			lineup_container.set_uuid(i, enemy_inst.ball_uuid)
			_update_instance_location(enemy_inst.ball_uuid, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, i)

## Copy player trinkets from run state to battle instances
func _setup_player_trinkets() -> void:
	if not is_instance_valid(GameManager.run_state):
		return
	
	var player_trinkets_container = GameManager.run_state.get_container(RS.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
	if not is_instance_valid(player_trinkets_container):
		return
	
	var battle_trinkets_container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
	var slot_index = 0
	
	for trinket_uuid in player_trinkets_container.get_all_non_empty_uuids():
		var perm_trinket = GameManager.get_instance_by_uuid(trinket_uuid)
		if not is_instance_valid(perm_trinket):
			continue
		
		# Create battle copy of the trinket
		var battle_trinket = GachaBallInstance.new()
		var trinket_def = perm_trinket.get_definition()
		if is_instance_valid(trinket_def):
			battle_trinket.initialize_from_trinket(trinket_def)
			_battle_instances[battle_trinket.ball_uuid] = battle_trinket
			
			# Place in battle trinkets container
			if slot_index < 5: # Player trinkets container has 5 slots
				battle_trinkets_container.set_uuid(slot_index, battle_trinket.ball_uuid)
				_update_instance_location(battle_trinket.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, slot_index)
				slot_index += 1

## Setup enemy trinkets from the encounter definition
func _setup_enemy_trinkets_from_encounter(encounter_def: EncounterDefinition) -> void:
	if not is_instance_valid(encounter_def):
		return
	
	var et_container := get_container(BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	if not is_instance_valid(et_container):
		return
	
	var slot_index = 0
	for trinket_id in encounter_def.enemy_trinket_ids:
		var trinket_def = Database.get_definition(trinket_id)
		if not is_instance_valid(trinket_def):
			continue
		
		# Skip player-exclusive trinkets
		if trinket_def.is_player_exclusive:
			continue
		
		# Create instance for the enemy trinket
		var trinket_inst = GachaBallInstance.new()
		trinket_inst.initialize_from_trinket(trinket_def)
		_battle_instances[trinket_inst.ball_uuid] = trinket_inst
		
		# Place in enemy trinkets container
		if slot_index < 5: # Max 5 enemy trinkets
			et_container.set_uuid(slot_index, trinket_inst.ball_uuid)
			_update_instance_location(trinket_inst.ball_uuid, BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, slot_index)
			enemy_trinkets.append(trinket_inst)
			slot_index += 1

func get_container(container_name: StringName) -> DataContainer:
	if _containers.has(container_name):
		return _containers[container_name]

	var new_container: DataContainer

	match container_name:
		BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			new_container = FixedArrayContainer.new(5)
		BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
			new_container = FixedArrayContainer.new(6)
		BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
			new_container = FixedArrayContainer.new(2)
		BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
			new_container = GrowableGridContainer.new(16)
		BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			new_container = FixedArrayContainer.new(5)
		BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
			new_container = FixedArrayContainer.new(5)
		_: # Default case for BattleInventoryT*
			if container_name.begins_with("BattleInventoryT"):
				new_container = GrowableGridContainer.new(16)
			else:
				# Failsafe for unknown container types
				new_container = FixedArrayContainer.new(1)

	_containers[container_name] = new_container
	return new_container

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(container_tag)
	if not is_instance_valid(container): return result
	var uuids = container.get_all_non_empty_uuids()
	for uuid in uuids:
		var instance = get_instance(uuid)
		if is_instance_valid(instance): result.append(instance)
	
	# Sort by location index using the _instance_locations dictionary
	result.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	return result

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"BattleInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	var instance = get_instance(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func _update_instance_location(uuid: String, container_name: StringName, index: int) -> void:
	var instance = get_instance(uuid)
	if not is_instance_valid(instance): return
	
	# Directly update the instance's properties, making it the source of truth.
	instance.location_container_tag = container_name
	instance.location_slot_index = index
	# Only clear equip linkage when moving to a physical container or clearing location.
	# Equipped items do not live in physical slots.
	if container_name != C.CONTAINER_EQUIPPED_ITEM:
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	
	# This function now ONLY handles direct container lookups.
	# The logic for resolving an equipped item's location is now handled by
	# the caller by checking the LocationIdentifier first. This change is
	# mandated by the new architecture to avoid ambiguity.
	var container = get_container(loc.container)
	if not is_instance_valid(container): return null
	
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid) if not uuid.is_empty() else null

func get_all_instances() -> Dictionary:
	return _battle_instances

# ------------------------------------------------------------------
# Atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	assert(is_instance_valid(instance), "bm_add_instance: instance is null")
	var container = get_container(container_name)
	if not is_instance_valid(container):
		return false
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			return false
	# Index
	container.set_uuid(slot, instance.ball_uuid)
	# Truth and registry
	_battle_instances[instance.ball_uuid] = instance
	_update_instance_location(instance.ball_uuid, container_name, slot)
	# Validate and emit
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func _reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container):
		return false
	var all_discarded = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var instances_to_move: Array[GachaBallInstance] = []
	for inst in all_discarded:
		var inst_def = inst.get_definition()
		if (inst_def is GachaBallDefinition) and inst_def.tier == tier_to_reshuffle and _is_player_owned(inst):
			instances_to_move.append(inst)
	if instances_to_move.is_empty():
		return false
	for instance in instances_to_move:
		# Restore stats to base values before moving back to draw pool
		instance.reset_battle_stats()
		_remove_instance_from_container(instance)
		var new_index = dest_container.find_first_empty_slot()
		if new_index == -1:
			new_index = dest_container.get_all_uuids().size()
		dest_container.set_uuid(new_index, instance.ball_uuid)
		_update_instance_location(instance.ball_uuid, dest_container_tag, new_index)
	return true

func bm_remove_instance(uuid: String) -> bool:
	assert(not uuid.is_empty(), "bm_remove_instance: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_remove_instance: instance not found for uuid " + uuid)
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return false
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if not is_instance_valid(parent):
			return false
		if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
			return false
		# Remove bonuses from the parent before clearing the mapping
		parent.unequip_item_bonus(instance)
		parent.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
		# Clear the item's location since equipped slots are logical, not physical
		_update_instance_location(instance.ball_uuid, &"", -1)
		# Notify that the parent unit's inventory changed so it can recalc stats/UI
		SignalBus.emit_signal("unit_inventory_changed", parent.ball_uuid)
	else:
		# If this is a player unit with equipped items, unequip and move them into PLAYER_ITEM_INVENTORY
		if instance.equipped_item_uuids.size() > 0 and _is_player_unit(instance):
			var inv := get_container(BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
			for i in range(instance.equipped_item_uuids.size()):
				var it_uuid := instance.equipped_item_uuids[i]
				if it_uuid.is_empty():
					continue
				var it := get_instance(it_uuid)
				if not is_instance_valid(it):
					continue
				# Clear mapping on both sides
				instance.equipped_item_uuids[i] = ""
				it.equipped_on_uuid = ""
				it.equipped_slot_index = -1
				# Rehome into item inventory to maintain validity during composite ops
				if is_instance_valid(inv):
					var empty := inv.find_first_empty_slot()
					if empty != -1:
						inv.set_uuid(empty, it.ball_uuid)
						_update_instance_location(it.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY, empty)
					else:
						return false
		# Extra hardening (player only): clear any stray items that believe they are equipped on this unit
		if _is_player_unit(instance):
			var inv2 := get_container(BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
			for k in _battle_instances.keys():
				var maybe_item: GachaBallInstance = _battle_instances[k]
				if not is_instance_valid(maybe_item):
					continue
				if maybe_item.equipped_on_uuid == instance.ball_uuid:
					maybe_item.equipped_on_uuid = ""
					maybe_item.equipped_slot_index = -1
					if is_instance_valid(inv2):
						var empty2 := inv2.find_first_empty_slot()
						if empty2 != -1:
							inv2.set_uuid(empty2, maybe_item.ball_uuid)
							_update_instance_location(maybe_item.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY, empty2)
						else:
							return false
		_remove_instance_from_container(instance)
	_battle_instances.erase(uuid)
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true


func bm_move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_move_instance: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_move_instance: target_loc is null")
	# Target is equipping onto a unit
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return false
		# Resolve source item whether from container or equipped slot
		var item_uuid := ""
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var src_unit := get_instance(source_loc.unit_uuid)
			if not is_instance_valid(src_unit): return false
			if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size(): return false
			item_uuid = src_unit.equipped_item_uuids[source_loc.index]
			# If moving between equipped slots, first unequip from the source unit to avoid ghost copies
			if not item_uuid.is_empty():
				var item := get_instance(item_uuid)
				if is_instance_valid(item):
					src_unit.unequip_item_bonus(item)
					src_unit.equipped_item_uuids[source_loc.index] = ""
					item.equipped_on_uuid = ""
					item.equipped_slot_index = -1
					_update_instance_location(item.ball_uuid, &"", -1)
					SignalBus.emit_signal("unit_inventory_changed", src_unit.ball_uuid)
		else:
			var inst_from_container := get_instance_by_location(source_loc)
			if not is_instance_valid(inst_from_container): return false
			item_uuid = inst_from_container.ball_uuid
			# Precise source removal by index to avoid ghost copies, then blank location before equip
			var src_container := get_container(source_loc.container)
			if not is_instance_valid(src_container): return false
			if src_container.get_uuid(source_loc.index) != item_uuid: return false
			src_container.set_uuid(source_loc.index, "")
			_update_instance_location(item_uuid, &"", -1)
		return bm_equip_item(item_uuid, unit.ball_uuid, target_loc.index)
	# Source is an equipped slot moving to a container
	if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var src_unit := get_instance(source_loc.unit_uuid)
		if not is_instance_valid(src_unit):
			return false
		if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
			return false
		var a_uuid := src_unit.equipped_item_uuids[source_loc.index]
		if a_uuid.is_empty():
			return false
		var a := get_instance(a_uuid)
		if not is_instance_valid(a):
			return false
		# Remove bonuses from the unit as we unequip
		src_unit.unequip_item_bonus(a)
		# Clear mapping on both sides, as equipped slots are logical, not physical
		src_unit.equipped_item_uuids[source_loc.index] = ""
		a.equipped_on_uuid = ""
		a.equipped_slot_index = -1
		# Place into target container slot
		var to_container := get_container(target_loc.container)
		if not is_instance_valid(to_container):
			return false
		to_container.set_uuid(target_loc.index, a.ball_uuid)
		_update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
		# Notify unit inventory changed after unequip
		SignalBus.emit_signal("unit_inventory_changed", src_unit.ball_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true
	# Default move
	var instance := get_instance_by_location(source_loc)
	if not is_instance_valid(instance):
		return false
	# Clear the exact source slot to avoid UUID-scan mismatches
	var from_container := get_container(source_loc.container)
	if not is_instance_valid(from_container):
		return false
	if from_container.get_uuid(source_loc.index) != instance.ball_uuid:
		return false
	from_container.set_uuid(source_loc.index, "")
	var to_container := get_container(target_loc.container)
	if not is_instance_valid(to_container):
		return false
	to_container.set_uuid(target_loc.index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, target_loc.container, target_loc.index)
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	assert(is_instance_valid(source_loc), "bm_swap_instances: source_loc is null")
	assert(is_instance_valid(target_loc), "bm_swap_instances: target_loc is null")
	# Handle swaps where target is an equipped slot
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return false
		# Resolve A from source (container or equipped)
		var a_uuid := ""
		var a: GachaBallInstance = null
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var src_unit := get_instance(source_loc.unit_uuid)
			if not is_instance_valid(src_unit): return false
			if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size(): return false
			a_uuid = src_unit.equipped_item_uuids[source_loc.index]
			a = get_instance(a_uuid)
			# Remove bonuses from the old unit before clearing mapping
			if is_instance_valid(a):
				src_unit.unequip_item_bonus(a)
			# Clear mapping for A leaving its equipped slot
			src_unit.equipped_item_uuids[source_loc.index] = ""
			if is_instance_valid(a):
				a.equipped_on_uuid = ""
				a.equipped_slot_index = -1
				_update_instance_location(a.ball_uuid, &"", -1)
		else:
			a = get_instance_by_location(source_loc)
			if not is_instance_valid(a): return false
			_remove_instance_from_container(a)
		# Resolve existing item B in target equipped slot
		if target_loc.index < 0 or target_loc.index >= unit.equipped_item_uuids.size():
			return false
		var b_uuid := unit.equipped_item_uuids[target_loc.index]
		var b: GachaBallInstance = null
		if not b_uuid.is_empty():
			b = get_instance(b_uuid)
		# If B exists, move it into source origin
		if is_instance_valid(b):
			# Clear target mapping first
			unit.unequip_item_bonus(b)
			unit.equipped_item_uuids[target_loc.index] = ""
			b.equipped_on_uuid = ""
			b.equipped_slot_index = -1
			if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
				var src_unit2 := get_instance(source_loc.unit_uuid)
				if not is_instance_valid(src_unit2): return false
				src_unit2.equipped_item_uuids[source_loc.index] = b.ball_uuid
				b.equipped_on_uuid = src_unit2.ball_uuid
				b.equipped_slot_index = source_loc.index
				b.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
				b.location_slot_index = source_loc.index
				# Apply bonuses on the new unit slot
				src_unit2.equip_item_bonus(b)
				# Notify UI for the source unit receiving B
				SignalBus.emit_signal("unit_inventory_changed", src_unit2.ball_uuid)
			else:
				var src_container := get_container(source_loc.container)
				if not is_instance_valid(src_container): return false
				src_container.set_uuid(source_loc.index, b.ball_uuid)
				_update_instance_location(b.ball_uuid, source_loc.container, source_loc.index)
		# Equip A into target slot
		unit.equipped_item_uuids[target_loc.index] = a.ball_uuid
		a.equipped_on_uuid = unit.ball_uuid
		a.equipped_slot_index = target_loc.index
		a.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
		a.location_slot_index = target_loc.index
		# Apply item bonuses like bm_equip_item does
		unit.equip_item_bonus(a)
		# If source was an equipped slot and target had no B, notify that source unit changed
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM and not is_instance_valid(b):
			var src_unit3 := get_instance(source_loc.unit_uuid)
			if is_instance_valid(src_unit3):
				SignalBus.emit_signal("unit_inventory_changed", src_unit3.ball_uuid)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		SignalBus.emit_signal("unit_inventory_changed", unit.ball_uuid)
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true
	# General swap across containers
	var a := get_instance_by_location(source_loc)
	var a_container := get_container(source_loc.container)
	var b_container := get_container(target_loc.container)
	if not is_instance_valid(a) or not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return false
	var b := get_instance_by_location(target_loc)
	if not is_instance_valid(b):
		# Degrade to move if target is empty — clear by exact source index
		if a_container.get_uuid(source_loc.index) != a.ball_uuid:
			return false
		a_container.set_uuid(source_loc.index, "")
		b_container.set_uuid(target_loc.index, a.ball_uuid)
		_update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
		if OS.is_debug_build():
			_bm_validate_state_consistency()
		_emit_battle_inventory_changed()
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true
	# True swap across real containers
	if a_container.get_uuid(source_loc.index) != a.ball_uuid:
		return false
	var b_uuid2 := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid2)
	_update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
	_update_instance_location(b.ball_uuid, source_loc.container, source_loc.index)
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	assert(not item_uuid.is_empty(), "bm_equip_item: item_uuid is empty")
	assert(not unit_uuid.is_empty(), "bm_equip_item: unit_uuid is empty")
	var item := get_instance(item_uuid)
	var unit := get_instance(unit_uuid)
	assert(is_instance_valid(item), "bm_equip_item: item instance not found")
	assert(is_instance_valid(unit), "bm_equip_item: unit instance not found")
	# Determine slot
	var target_slot := slot_index
	if target_slot < 0:
		target_slot = unit.equipped_item_uuids.find("")
		if target_slot == -1:
			return false
	if target_slot >= unit.equipped_item_uuids.size():
		return false
	# If item is in a physical container, remove it.
	# If it is currently equipped (logical array), clear the previous mapping by index and remove bonuses.
	var item_loc := item.get_location()
	if is_instance_valid(item_loc) and item_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		_remove_instance_from_container(item)
	else:
		if not item.equipped_on_uuid.is_empty():
			var prev_unit := get_instance(item.equipped_on_uuid)
			if is_instance_valid(prev_unit):
				var prev_idx := item.equipped_slot_index
				if prev_idx >= 0 and prev_idx < prev_unit.equipped_item_uuids.size():
					# Remove bonuses from the previous unit and clear mapping exactly at the old index
					prev_unit.unequip_item_bonus(item)
					if prev_unit.equipped_item_uuids[prev_idx] == item.ball_uuid:
						prev_unit.equipped_item_uuids[prev_idx] = ""
				SignalBus.emit_signal("unit_inventory_changed", prev_unit.ball_uuid)
			# Clear the item's equipped linkage while in transition
			item.equipped_on_uuid = ""
			item.equipped_slot_index = -1
		# Blank the location during transition to avoid stale lookups
		_update_instance_location(item.ball_uuid, &"", -1)
	# If slot occupied, move existing to player item inventory
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	if not existing_uuid.is_empty():
		var existing := get_instance(existing_uuid)
		if is_instance_valid(existing):
			existing.equipped_on_uuid = ""
			existing.equipped_slot_index = -1
			var inv := get_container(BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
			if is_instance_valid(inv):
				var empty := inv.find_first_empty_slot()
				if empty != -1:
					inv.set_uuid(empty, existing.ball_uuid)
					_update_instance_location(existing.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY, empty)
				else:
					return false
	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot
	# Apply item bonuses
	unit.equip_item_bonus(item)
	# Validate before notifying observers to avoid transient inconsistent states
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	# Emit ordering
	SignalBus.emit_signal("unit_inventory_changed", unit.ball_uuid)
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Composite atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_move_instance_to_discard(uuid: String) -> bool:
	assert(not uuid.is_empty(), "bm_move_instance_to_discard: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_move_instance_to_discard: instance not found")
	var loc := instance.get_location()
	assert(is_instance_valid(loc), "bm_move_instance_to_discard: instance has no location")
	# Ownership gate: only player-owned instances can enter the player's discard pile
	assert(_is_player_owned(instance), "bm_move_instance_to_discard: instance is not player owned")
	# If equipped, clear equip mapping; otherwise remove from its container
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if not is_instance_valid(parent):
			return false
		if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
			return false
		parent.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
	else:
		_remove_instance_from_container(instance)
	# Place into discard
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard_container):
		return false
	var index := discard_container.find_first_empty_slot()
	if index == -1:
		push_error("Discard pile full; cannot move %s" % instance.ball_uuid)
		return false
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_reshuffle_discard_pile(tier_to_reshuffle: int) -> bool:
	var moved := _reshuffle_tier_from_discard(tier_to_reshuffle)
	if not moved:
		return false
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	# Ensure InventoryWindow grids reflect reshuffled draw pools immediately
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_draw_gacha_instance(tier: int) -> bool:
	print("[DEBUG] bm_draw_gacha_instance called for tier %d" % tier)
	var cost := tier
	if _gacha_tokens < cost:
		print("[DEBUG] Not enough tokens: have %d, need %d" % [_gacha_tokens, cost])
		return false
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	print("[DEBUG] Tier pool for %s has %d instances" % [container_tag, tier_pool.size()])
	# If pool is empty, silently reshuffle that tier from discard (single emission at end)
	if tier_pool.is_empty():
		print("[DEBUG] Pool empty, attempting reshuffle from discard")
		if not _reshuffle_tier_from_discard(tier):
			print("[DEBUG] Reshuffle failed")
			return false
		tier_pool = get_instances_in_container(container_tag)
		if tier_pool.is_empty():
			print("[DEBUG] Pool still empty after reshuffle")
			return false
	# Spend tokens and announce
	_gacha_tokens -= cost
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	# Draw one
	var drawn_instance: GachaBallInstance = tier_pool.pick_random()
	var target_container_tag: StringName
	var target_container_capacity := 0
	match drawn_instance.get_definition().category:
		&"UNIT":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_BENCH
			target_container_capacity = 3
		&"ITEM":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
			target_container_capacity = 3
		_:
			# Unknown categories: remove from pool and discard
			_remove_instance_from_container(drawn_instance)
			var discard := get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
			var d_idx := discard.find_first_empty_slot()
			if d_idx == -1:
				d_idx = discard.get_all_uuids().size()
			discard.set_uuid(d_idx, drawn_instance.ball_uuid)
			_update_instance_location(drawn_instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, d_idx)
			if OS.is_debug_build():
				_bm_validate_state_consistency()
			_emit_battle_inventory_changed()
			# Keep InventoryWindow grids in sync on this early-return path
			SignalBus.emit_signal("inventory_ui_refresh_requested")
			return true
	# Remove from the draw pool first (so we can check if it became empty)
	_remove_instance_from_container(drawn_instance)
	# If the tier pool is now empty after removal, silently reshuffle
	if get_instances_in_container(container_tag).is_empty():
		_reshuffle_tier_from_discard(tier)
	# Place into target container if space, else discard
	var target_container := get_container(target_container_tag)
	var empty_slot := target_container.find_first_empty_slot()
	if empty_slot != -1 and empty_slot < target_container_capacity:
		target_container.set_uuid(empty_slot, drawn_instance.ball_uuid)
		_update_instance_location(drawn_instance.ball_uuid, target_container_tag, empty_slot)
	else:
		var discard2 := get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
		var di := discard2.find_first_empty_slot()
		if di == -1:
			di = discard2.get_all_uuids().size()
		discard2.set_uuid(di, drawn_instance.ball_uuid)
		_update_instance_location(drawn_instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, di)
	# Validate and emit once
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	_emit_battle_inventory_changed()
	# Ensure InventoryWindow (battle context) updates tier grids post-draw/reshuffle
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Golden Rule Validation (Battle)
# ------------------------------------------------------------------

func _bm_validate_state_consistency() -> bool:
	# Pass 1: scan containers, detect duplicates and equipped-item leaks; do not mutate state
	var occurrences: Dictionary = {}
	for cname in _containers.keys():
		var c: DataContainer = _containers[cname]
		if not is_instance_valid(c):
			continue
		var uuids := c.get_all_uuids()
		for i in range(uuids.size()):
			var u := uuids[i]
			if u.is_empty():
				continue
			if occurrences.has(u):
				push_error("Duplicate UUID %s also present at %s:%d" % [u, String(cname), i])
				return false
			occurrences[u] = [ {"container": cname, "index": i}]
			var inst: GachaBallInstance = _battle_instances.get(u)
			if not is_instance_valid(inst):
				push_error("Container references missing battle instance %s" % u)
				return false
			if inst.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				push_error("Equipped item %s appears in a battle container slot at %s:%d" % [u, String(cname), i])
				return false
	# Pass 2: verify each instance's declared location matches container truth; do not mutate state
	for u in _battle_instances.keys():
		var inst: GachaBallInstance = _battle_instances[u]
		if not is_instance_valid(inst):
			continue
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			continue
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent: GachaBallInstance = _battle_instances.get(loc.unit_uuid)
			if not is_instance_valid(parent):
				push_error("Equipped item %s has missing parent %s" % [u, loc.unit_uuid])
				return false
			if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
				push_error("Equipped item %s has invalid equipped index %d on %s" % [u, loc.index, parent.ball_uuid])
				return false
			if parent.equipped_item_uuids[loc.index] != u:
				push_error("Equipped item %s mapping mismatch on %s at slot %d" % [u, parent.ball_uuid, loc.index])
				return false
		else:
			var c2 := get_container(loc.container)
			if not is_instance_valid(c2):
				push_error("Missing battle container %s for %s" % [String(loc.container), u])
				return false
			var all2 := c2.get_all_uuids()
			if loc.index < 0 or loc.index >= all2.size():
				push_error("Location index out of bounds for %s: %s:%d (capacity=%d)" % [u, String(loc.container), loc.index, all2.size()])
				return false
			var actual = c2.get_uuid(loc.index)
			if actual != u:
				push_error("Location/content mismatch for %s: loc %s:%d has %s" % [u, String(loc.container), loc.index, actual])
				return false
	return true

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

func get_battle_inventory() -> Dictionary:
	return _containers

func get_discard_pile_inventory() -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(container): return result
	var all_uuids = container.get_all_uuids()
	for uuid in all_uuids:
		if uuid.is_empty(): result.append(null)
		else: result.append(get_instance(uuid))
	if result.size() < 16: result.resize(16)
	return result

func _change_phase(new_phase: Phases) -> void:
	_current_battle_phase = new_phase
	SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
	match _current_battle_phase:
		Phases.START_OF_TURN:
			# Increment turn counter and reset turn start flag
			_current_turn += 1
			_turn_start_abilities_triggered = false
			
			# Grant base 5 tokens for the turn
			_gacha_tokens += 5
			SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			
			# The flashcard mini-game is the first event of the turn.
			# TDD Section 9.4: Battle Flow
			# Turn start abilities will be triggered AFTER the mini-game in _on_results_acknowledged()
			if is_test_mode:
				# In test mode, skip minigame
				# Grant massive tokens for testing
				_gacha_tokens += 999
				SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
				# Transition to results acknowledged (which triggers turn start abilities)
				call_deferred("_on_results_acknowledged")
			elif is_instance_valid(GameManager.run_state):
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The management phase will be triggered by _on_results_acknowledged
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			_emit_battle_inventory_changed()
		Phases.COMBAT:
			pass
		Phases.END_OF_TURN:
			# Fire on_turn_end for all units
			# Note: _trigger_turn_end_abilities will start animations
			# The phase transition to START_OF_TURN will happen in _on_turn_animation_finished
			# when the burn animations complete
			_trigger_turn_end_abilities()

## Populate the actor queue at the start of combat.
## Preserves asymmetric attack order: players left-to-right, then enemies right-to-left.
## NOTE: Old system used LIFO (pop_back), new system uses FIFO (pop_front) for priority queue.
## To preserve visual order with FIFO:
##   - Players go left-to-right (index 0→5) → add in order
##   - Enemies go right-to-left (index 5→0) → add reversed
func _populate_actor_queue() -> void:
	_actor_queue.clear()
	_turn_metadata.clear() # Reset turn-scoped tracking (first-killed, resurrection flags)
	_dead_this_turn.clear() # Reset death registry for new turn
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	# With FIFO (pop_front), first in = first out
	# Add players in reverse order (right-to-left execution)
	player_lineup.reverse()
	_actor_queue.append_array(player_lineup)
	# Add enemies in normal order (left-to-right execution)
	_actor_queue.append_array(enemy_lineup)

## Grant a unit an extra action by inserting them at the front of the actor queue.
## Called by EffectGrantExtraAction when a unit equipped with Bloodlust Edge gets a kill.
## @param unit_uuid: String - The UUID of the unit to grant an extra action
func grant_extra_action(unit_uuid: String) -> void:
	var unit := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(unit):
		return
	# Only grant if unit is alive
	if unit.current_hp <= 0:
		return
	# Insert at front of queue so they act next
	_actor_queue.push_front(unit)

## Insert a newly summoned unit into the actor queue.
## Mid-turn summons should always participate in combat if they're still alive when their turn comes.
## Player units act right-to-left (high slot first), Enemy units act left-to-right (low slot first).
## NOTE: Dead units may have cleared container tags, so we can't rely on _is_player_unit for them.
func _insert_summoned_unit_into_queue(new_unit: GachaBallInstance) -> void:
	assert(is_instance_valid(new_unit), "_insert_summoned_unit_into_queue: new_unit is null")
	var is_player = _is_player_unit(new_unit)
	var slot_idx = new_unit.location_slot_index
	
	# Find alive same-team units still in queue to determine insertion position
	# We check HP > 0 because dead units have cleared container tags and won't be reliable
	var found_alive_same_team := false
	for i in range(_actor_queue.size()):
		var queued_unit = _actor_queue[i]
		# Skip dead units - their container tags are unreliable
		if queued_unit.current_hp <= 0:
			continue
		if _is_player_unit(queued_unit) == is_player:
			found_alive_same_team = true
			# Same team - check if our slot should act before this one
			if is_player:
				# Players: higher slots act first (4,3,2,1,0)
				if slot_idx > queued_unit.location_slot_index:
					_actor_queue.insert(i, new_unit)
					print("[DEBUG] Inserted summoned unit ", new_unit.ball_uuid, " before ", queued_unit.ball_uuid)
					return
			else:
				# Enemies: lower slots act first (0,1,2,3,4)
				if slot_idx < queued_unit.location_slot_index:
					_actor_queue.insert(i, new_unit)
					print("[DEBUG] Inserted summoned unit ", new_unit.ball_uuid, " before ", queued_unit.ball_uuid)
					return
	
	# If we found alive same-team units but didn't insert, add at end of same-team section
	if found_alive_same_team:
		for i in range(_actor_queue.size()):
			var queued_unit = _actor_queue[i]
			if queued_unit.current_hp <= 0:
				continue
			if _is_player_unit(queued_unit) != is_player:
				# Found where other team starts, insert before
				_actor_queue.insert(i, new_unit)
				print("[DEBUG] Inserted summoned unit ", new_unit.ball_uuid, " before other team at index ", i)
				return
		# All remaining alive units are same team, append at end
		_actor_queue.append(new_unit)
		print("[DEBUG] Appended summoned unit ", new_unit.ball_uuid, " after same-team units")
		return
	# No alive same-team units in queue - check if there are DEAD same-team units
	# Dead units still in queue = their slot hasn't acted yet (died before their turn)
	# No units at all = team has finished acting (all units popped from queue)
	var found_dead_same_team := false
	for queued_unit in _actor_queue:
		# Dead units have cleared container tags, so check by team negation:
		# If it's not a player unit AND we're looking for enemy team, it's same team
		# Use HP check: dead units (HP <= 0) with uncertain team are assumed same-team
		# if the queue context suggests it (e.g., only dead enemies remain after player kills them)
		if queued_unit.current_hp <= 0:
			# This dead unit is still in queue - its slot hasn't acted yet
			# The summon should get a turn since the team hasn't finished
			found_dead_same_team = true
			break
	
	if found_dead_same_team:
		# Team hasn't finished - dead units are still waiting for their turn
		# Add summon to end of queue
		_actor_queue.append(new_unit)
		print("[DEBUG] Appended summon ", new_unit.ball_uuid, " (dead same-team units still in queue)")
		return
	
	# No same-team units (alive OR dead) in queue - team has FINISHED acting
	# This happens when a unit POPS, acts, dies from counter, and triggers summon
	# The slot already had its turn, so the summon should NOT act this turn
	print("[DEBUG] Not adding summon ", new_unit.ball_uuid, " - team has finished acting (slot already acted)")


## Enqueue an attack (on_attack trigger + basic attack fallback) for a single actor.
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	var target = _get_frontmost_target(is_player)
	if not is_instance_valid(target): return
	# Build context for on_attack trigger (semantic keys per unified broadcast pattern)
	var context: Dictionary = {
		"attacker_uuid": attacker.ball_uuid,
		"target_uuid": target.ball_uuid,
		"target_initial_hp": target.current_hp
	}
	
	# Note: on_before_attack is now triggered in BasicAttackEffect.execute()
	# so it fires for ALL attacks including counter-attacks
	
	# Trigger on_attack abilities (e.g., Double Strike)
	print("[BM] _enqueue_attack_for:", attacker.ball_uuid, "-> target:", target.ball_uuid)
	AbilityResolver.process_trigger(&"on_attack", context)
	
	# Check if an ability replaced the basic attack
	if context.get("attack_replaced", false):
		return
	
	# Always add basic attack
	var basic_attack_def = Database.get_ability_definition(&"basic_attack")
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"basic_attack", basic_attack_def.effects[0],
			[target.ball_uuid], context, 0 # Priority 0 for basic attack
		)
		enqueue_effect_request(basic_attack_request)

func _resolve_single_effect_request(request: EffectRequest, out_events: Array[CombatEvent], death_tracking: Dictionary = {}) -> void:
	print("[DEBUG BM] _resolve_single_effect_request: ability=%s, source=%s" % [request.ability_id, request.source_uuid])
	# Validate source is still alive (allow empty source UUID for trinket effects)
	var source = null
	if not request.source_uuid.is_empty():
		source = get_instance_by_uuid(request.source_uuid)
		if not is_instance_valid(source):
			print("[DEBUG BM] EXIT: source instance is invalid for uuid=%s" % request.source_uuid)
			return
		# Only gate dead UNIT sources; allow ITEM/TRINKET sources to execute
		# Exceptions:
		# 1. Reactive abilities (counter-attacks, retaliation) allowed post-mortem
		# 2. on_death abilities - the dying unit IS expected to be dead when these execute
		var src_def = source.get_definition()
		if is_instance_valid(src_def) and src_def.category == &"UNIT" and source.current_hp <= 0:
			# Allow if this is the dying unit's own on_death trigger
			var dying_uuid: String = request.trigger_context.get("dying_uuid", "")
			var is_own_death_trigger: bool = (dying_uuid == request.source_uuid)
			# Allow reactive abilities that need to complete after lethal damage
			var ability_id_str := String(request.ability_id)
			var is_reactive_ability: bool = ability_id_str.contains("counter") or ability_id_str.contains("retaliate") or ability_id_str == "unit_tier3d_resilient_aura"
			
			print("[DEBUG BM] Dead source check: dying_uuid=%s, is_own_death=%s, is_reactive=%s" % [dying_uuid, is_own_death_trigger, is_reactive_ability])
			
			if not is_own_death_trigger and not is_reactive_ability:
				print("[DEBUG BM] EXIT: Dead unit's effect blocked (not own on_death, not reactive)")
				return

	# Prepare execution targets from resolved targets. Only basic attacks may dynamically retarget.
	var exec_targets: Array[String] = []
	exec_targets.append_array(request.resolved_targets)
	var is_basic_attack := (request.ability_id == &"basic_attack")
	
	# For ALL abilities (basic or triggered), validate targets are still alive AND in battle
	# Filter out dead targets to prevent ghost attacks
	# NOTE: Must check location_container_tag because reset_battle_stats_silent() restores HP before discard
	var valid_targets: Array[String] = []
	for target_uuid in exec_targets:
		var target_inst = get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_inst) and target_inst.current_hp > 0:
			# Also verify the target is still in an active battle container (not discard/removed)
			var loc_tag: StringName = target_inst.location_container_tag
			var is_in_battle: bool = (loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
								 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
								 loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH or
								 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
			if is_in_battle:
				valid_targets.append(target_uuid)
	
	# Allow targetless effects (e.g., summons) to proceed
	# They will provide their own targets in the return data
	# Only abort if we EXPECTED targets but they're all invalid
	if valid_targets.is_empty() and not exec_targets.is_empty():
		return
	
	exec_targets = valid_targets
	
	# For basic attacks only, apply retargeting to frontmost if needed
	if is_basic_attack and exec_targets.size() > 0:
		var first_target = get_instance_by_uuid(exec_targets[0])
		if not is_instance_valid(first_target) or first_target.current_hp <= 0:
			var attacker_is_player: bool = false
			if is_instance_valid(source):
				attacker_is_player = _is_player_unit(source)
			var new_target_inst = _get_frontmost_target(attacker_is_player)
			if is_instance_valid(new_target_inst):
				exec_targets[0] = new_target_inst.ball_uuid
			else:
				return
	# Execute without emitting UI; capture results for events
	var damage := 0
	if is_instance_valid(request.effect_definition):
		var sim_ctx = request.trigger_context.duplicate(true)
		sim_ctx["is_simulation"] = true
		sim_ctx["ability_id"] = request.ability_id
		var res = request.effect_definition.execute(request.source_uuid, exec_targets, self, sim_ctx)
		
		# CRITICAL: Collect on_before_attack inline events IMMEDIATELY after effect execution
		# These events (like Defensive Stance heal) must appear BEFORE any damage events
		# to maintain correct causal order: HEAL → DAMAGE (not DAMAGE → HEAL)
		var before_attack_inline_evts = collect_inline_events()
		out_events.append_array(before_attack_inline_evts)
		
		# IMPORTANT: Normalize legacy integer returns to dictionary format FIRST
		# This must happen before the TYPE_DICTIONARY check so the normalized value gets processed
		if typeof(res) == TYPE_INT:
			var damage_amount = int(res)
			res = {
				"stat": "hp",
				"amount": - damage_amount,
				"targets": exec_targets
			}
		
		# Preferred: structured stat change results
		if typeof(res) == TYPE_DICTIONARY:
			var effect_data: Dictionary = res
			
			# Handle cascading damage (special case for AOE)
			if effect_data.has("cascade_damage"):
				print("[BM] Processing cascade_damage from ability:", request.ability_id, "source:", request.source_uuid)
				var cascade_list = effect_data.get("cascade_damage", [])
				
				# Check if burn should be applied (same logic as main damage)
				var is_player_source = false
				var should_apply_burn = false
				if is_instance_valid(source):
					is_player_source = _is_player_unit(source)
					should_apply_burn = _has_team_trinket(is_player_source, &"trinket_burn_vial")
				
				for cascade_item in cascade_list:
					var cascade_target_uuid = String(cascade_item.get("target", ""))
					var cascade_amount = int(cascade_item.get("amount", 0))
					var cascade_skip_bump = bool(cascade_item.get("skip_bump", false))
					
					# Store original target for animation (in case Guardian redirects)
					var original_target_uuid = cascade_target_uuid
					
					# Inline damage processing for each cascade target
					var cascade_tgt = get_instance_by_uuid(cascade_target_uuid)
					if is_instance_valid(cascade_tgt):
						# GUARDIAN SENTINEL INTERCEPT CHECK (same as main damage path)
						var would_be_lethal = cascade_tgt.current_hp - cascade_amount <= 0
						var tgt_is_player_unit = _is_player_unit(cascade_tgt)
						var is_ally_damage = (tgt_is_player_unit != is_player_source)
						
						if would_be_lethal and is_ally_damage:
							var guardian = _find_guardian_on_team(tgt_is_player_unit, cascade_target_uuid)
							if is_instance_valid(guardian):
								# Create intercept event for leap animation
								out_events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
									"source_uuid": guardian.ball_uuid,
									"target_uuids": [cascade_target_uuid],
									"visual_payload": {
										"guardian_uuid": guardian.ball_uuid,
										"original_target_uuid": cascade_target_uuid,
										"damage": cascade_amount
									}
								}))
								# Redirect the damage target to Guardian
								cascade_target_uuid = guardian.ball_uuid
								cascade_tgt = guardian
						
						var old_hp = cascade_tgt.current_hp
						var old_burn = cascade_tgt.get_status_effect_amount(&"burn")
						var new_hp = apply_stat_delta(cascade_tgt, "hp", -cascade_amount)
						
						# Skip if target was already dead (apply_stat_delta returns null)
						if new_hp == null:
							continue
						
						var max_hp = 0
						var tgt_def = cascade_tgt.get_definition()
						if is_instance_valid(tgt_def):
							max_hp = tgt_def.base_hp
						
						# Apply burn if needed
						var burn_val = old_burn
						if should_apply_burn:
							burn_val = apply_stat_delta(cascade_tgt, "burn_stacks", 1)
						
						# Compute animation source - if source is an item, use the holder for animation
						var animation_source_uuid: String = request.source_uuid
						if is_instance_valid(source):
							var source_def = source.get_definition()
							if is_instance_valid(source_def) and source_def.category == &"ITEM":
								if not source.equipped_on_uuid.is_empty():
									animation_source_uuid = source.equipped_on_uuid
						
						# Compute bump direction using animation source
						var bump_dir := Vector2.ZERO
						var anim_source = get_instance_by_uuid(animation_source_uuid)
						if is_instance_valid(anim_source):
							var src_tag: StringName = anim_source.location_container_tag
							if src_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or src_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
								bump_dir = Vector2(1, 0)
							elif src_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or src_tag == BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
								bump_dir = Vector2(-1, 0)
						
						out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
							"source_uuid": request.source_uuid,
							"target_uuids": [cascade_target_uuid],
							"visual_payload": {
								"source_uuid": animation_source_uuid,
								"amount": - cascade_amount,
								"stat": "hp",
								"skip_bump": cascade_skip_bump,
								"bump_direction": bump_dir,
								"apply_burn": should_apply_burn,
								"targets_old_hp": [old_hp],
								"targets_new_hp": [new_hp],
								"targets_max_hp": [max_hp],
								"targets_old_burn": [old_burn],
								"targets_new_burn": [burn_val],
								"attack_type": "melee",
								"original_target_uuid": original_target_uuid, # For animation targeting when Guardian intercepts
								"projectile_data": {
									"stat": "hp",
									"amount": - cascade_amount,
									"color": "red"
								}
							}
						}))
						# Trigger on_hurt for counter-attacks AFTER damage is applied
						trigger_on_hurt(cascade_target_uuid, cascade_amount, request.source_uuid)
						
						# Drain on_hurt reactions (Aegis Charm, etc.) and collect their events
						# This allows Aegis to save a unit while shockwave continues to other targets
						drain_pending_reactions_inline(0)
						var cascade_hurt_inline_evts = collect_inline_events()
						out_events.append_array(cascade_hurt_inline_evts)
						
						# DETERMINISTIC ON_KILL: If cascade damage killed the target, trigger on_kill immediately
						# This ensures Bloodlust and other on_kill effects trigger for shockwave kills
						if cascade_tgt.current_hp <= 0:
							trigger_on_kill(request.source_uuid, cascade_target_uuid)
				# Check for deaths after cascade
				_check_for_deaths_with_counter_delay(true, out_events, death_tracking)
				return

			# Handle extra action effects (e.g., Bloodlust Edge on kill)
			if effect_data.has("extra_action"):
				var unit_uuid = String(effect_data.get("unit_uuid", ""))
				var unit = get_instance_by_uuid(unit_uuid)
				if is_instance_valid(unit):
					var unit_name = _get_instance_display_name(unit)
					out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s triggers Bloodlust!" % unit_name}))
				# grant_extra_action was already called in the effect, no further action needed
				return

			# Standard single-stat change processing
			var stat: String = String(effect_data.get("stat", ""))
			var amount: int = int(effect_data.get("amount", 0))
			var targets: Array = effect_data.get("targets", [])
			var skip_bump: bool = bool(effect_data.get("skip_bump", false))
			var resolved_targets: Array[String] = []
			var target_names: Array[String] = []
			for raw_target in targets:
				var target_uuid := String(raw_target)
				resolved_targets.append(target_uuid)
				var target_inst = get_instance_by_uuid(target_uuid)
				var target_label := _get_instance_display_name(target_inst)
				if target_label == "":
					target_label = target_uuid
				target_names.append(target_label)
			var source_name := ""
			if not String(request.source_uuid).is_empty():
				var src_inst = get_instance_by_uuid(request.source_uuid)
				source_name = _get_instance_display_name(src_inst)
			if source_name == "":
				source_name = String(request.ability_id)
		
			if stat == "hp" and not resolved_targets.is_empty():
				# Special case: Aegis Charm prevented lethal damage
				# Emit LETHAL_SAVE event for dramatic visual, then apply heal normally
				if effect_data.get("prevented_lethal", false):
					for tgt_uuid in resolved_targets:
						out_events.append(CombatEvent.new(CombatEvent.Type.LETHAL_SAVE, {
							"source_uuid": request.source_uuid,
							"target_uuids": [tgt_uuid],
							"ability_id": request.ability_id,
							"visual_payload": {
								"saved_uuid": tgt_uuid,
								"heal_amount": amount
							}
						}))
						var tgt = get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt):
							apply_stat_delta(tgt, "hp", amount)
					return # Don't process as normal heal
				
				if amount >= 0:
					var heal_target_name := ""
					if not target_names.is_empty():
						heal_target_name = target_names[0]
					if source_name != "" and heal_target_name != "":
						out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s heals %s for %d HP" % [source_name, heal_target_name, amount]}))
				
					# Apply HP delta via centralized function and capture OLD and NEW values
					var targets_old_hp: Array[int] = []
					var targets_new_hp: Array[int] = []
					var targets_max_hp: Array[int] = []
					for tgt_uuid in resolved_targets:
						var tgt = get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt):
							targets_old_hp.append(tgt.current_hp) # Capture BEFORE
							var new_hp = apply_stat_delta(tgt, "hp", amount) # ✅ Unified stat modification
							targets_new_hp.append(new_hp)
							var tgt_def = tgt.get_definition()
							if is_instance_valid(tgt_def):
								targets_max_hp.append(tgt_def.base_hp)
							else:
								targets_max_hp.append(0)
						else:
							targets_old_hp.append(0)
							targets_new_hp.append(0)
							targets_max_hp.append(0)
					
					out_events.append(CombatEvent.new(CombatEvent.Type.HEAL, {
						"source_uuid": request.source_uuid,
						"target_uuids": resolved_targets,
						"ability_id": request.ability_id,
						"trigger_type": request.trigger_context.get("trigger_type", ""),
						"ability_holder_uuid": request.source_uuid,
						"visual_payload": {
							"source_uuid": request.source_uuid,
							"amount": amount,
							"stat": "hp",
							"skip_bump": skip_bump,
							"targets_old_hp": targets_old_hp,
							"targets_new_hp": targets_new_hp,
							"targets_max_hp": targets_max_hp
						}
					}))
				else:
					var dealt: int = abs(amount)
					var damage_target_name := ""
					if not target_names.is_empty():
						damage_target_name = target_names[0]
					if source_name != "" and damage_target_name != "":
						out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s deals %d dmg to %s" % [source_name, dealt, damage_target_name]}))
					
					# Check if burn should be applied
					var is_player_source = false
					var should_apply_burn = false
					if is_instance_valid(source):
						is_player_source = _is_player_unit(source)
						should_apply_burn = _has_team_trinket(is_player_source, &"trinket_burn_vial")
					elif request.trigger_context.has("team"):
						is_player_source = (String(request.trigger_context.get("team")) == "PLAYER")
						should_apply_burn = _has_team_trinket(is_player_source, &"trinket_burn_vial")
					
					# Apply HP delta via centralized function and capture OLD and NEW values
					var targets_old_hp: Array[int] = []
					var targets_new_hp: Array[int] = []
					var targets_max_hp: Array[int] = []
					var targets_old_burn: Array[int] = []
					var targets_new_burn: Array[int] = []
					var damaged_uuids: Array[String] = [] # Track which targets actually received damage
					var original_target_uuids: Array[String] = [] # Track original targets for animation when Guardian intercepts
					
					for tgt_uuid in resolved_targets:
						var tgt = get_instance_by_uuid(tgt_uuid)
						# Skip already-dead or removed targets to prevent ghost attacks
						# Also check location_container_tag since reset_battle_stats_silent() restores HP before discard
						if not is_instance_valid(tgt) or tgt.current_hp <= 0:
							continue
						var loc_tag: StringName = tgt.location_container_tag
						var is_in_battle: bool = (loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
											 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
											 loc_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH or
											 loc_tag == BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
						if not is_in_battle:
							continue
					
						# GUARDIAN SENTINEL INTERCEPT CHECK
						# If this damage would be lethal to an ally, redirect to Guardian Sentinel
						var original_tgt_uuid = tgt_uuid # Save BEFORE potential redirect
						var actual_damage = abs(amount)
						var would_be_lethal = tgt.current_hp - actual_damage <= 0
						var tgt_is_player_unit = _is_player_unit(tgt)
						var is_ally_damage = (tgt_is_player_unit != is_player_source) # Enemy attacking player or vice versa
						
						if would_be_lethal and is_ally_damage:
							var guardian = _find_guardian_on_team(tgt_is_player_unit, tgt_uuid)
							if is_instance_valid(guardian):
								# Create intercept event for leap animation
								out_events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
									"source_uuid": guardian.ball_uuid,
									"target_uuids": [tgt_uuid],
									"visual_payload": {
										"guardian_uuid": guardian.ball_uuid,
										"original_target_uuid": tgt_uuid,
										"damage": actual_damage
									}
								}))
								# Redirect the damage target to Guardian
								tgt_uuid = guardian.ball_uuid
								tgt = guardian
						
						damaged_uuids.append(tgt_uuid) # Track actual damage target (may be Guardian)
						original_target_uuids.append(original_tgt_uuid) # Track original for animation
						targets_old_hp.append(tgt.current_hp) # Capture BEFORE
						targets_old_burn.append(tgt.get_status_effect_amount(&"burn")) # Capture BEFORE
						var new_hp = apply_stat_delta(tgt, "hp", amount) # ✅ Unified stat modification
						targets_new_hp.append(new_hp)
						
						# Get max HP from definition
						var tgt_def = tgt.get_definition()
						if is_instance_valid(tgt_def):
							targets_max_hp.append(tgt_def.base_hp)
						else:
							targets_max_hp.append(0)
						
						# Apply burn if needed
						var burn_val = 0
						if should_apply_burn:
							burn_val = apply_stat_delta(tgt, "burn_stacks", 1) # ✅ Unified status effect
						targets_new_burn.append(burn_val)
					
					# Skip generating DAMAGE event if all targets were dead
					if damaged_uuids.is_empty():
						return
					
					# Compute animation source - if source is an item, use the holder for animation
					var animation_source_uuid: String = request.source_uuid
					if is_instance_valid(source):
						var source_def = source.get_definition()
						if is_instance_valid(source_def) and source_def.category == &"ITEM":
							# Items don't have visual representations - use the holder unit
							if not source.equipped_on_uuid.is_empty():
								animation_source_uuid = source.equipped_on_uuid
					
					# Compute bump direction using animation source (holder for items)
					var bump_dir := Vector2.ZERO
					var anim_source = get_instance_by_uuid(animation_source_uuid)
					if is_instance_valid(anim_source):
						var src_tag: StringName = anim_source.location_container_tag
						if src_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or src_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
							bump_dir = Vector2(1, 0) # Player bumps right
						elif src_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or src_tag == BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
							bump_dir = Vector2(-1, 0) # Enemy bumps left
					
					out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
						"source_uuid": request.source_uuid,
						"target_uuids": damaged_uuids,
						"ability_id": request.ability_id,
						"trigger_type": request.trigger_context.get("trigger_type", ""),
						"ability_holder_uuid": request.source_uuid,
						"visual_payload": {
							"source_uuid": animation_source_uuid,
							"amount": amount,
							"stat": "hp",
							"skip_bump": skip_bump,
							"bump_direction": bump_dir, # Pre-computed for presentation
							"apply_burn": should_apply_burn,
							"targets_old_hp": targets_old_hp,
							"targets_new_hp": targets_new_hp,
							"targets_max_hp": targets_max_hp,
							"targets_old_burn": targets_old_burn,
							"targets_new_burn": targets_new_burn,
							"attack_type": "melee",
							"original_target_uuids": original_target_uuids, # For animation targeting when Guardian intercepts
							"projectile_data": {
								"stat": "hp",
								"amount": amount,
								"color": "red"
							}
						}
					}))
					# CRITICAL: Trigger on_hurt AFTER apply_stat_delta so condition checks see post-damage HP
					# This enables DAMAGE_WAS_NON_LETHAL to correctly detect lethal damage
					for tgt_uuid in damaged_uuids:
						trigger_on_hurt(tgt_uuid, abs(amount), request.source_uuid)
					
					# AEGIS FIX: Drain on_hurt effects BEFORE death check
					# This allows effects like Aegis Charm (prevent lethal damage) to heal units
					# to 1 HP before death is detected
					drain_pending_reactions_inline(0)
					
					# CRITICAL: Collect inline events (like LETHAL_SAVE) immediately and append
					# to out_events so they stay with the DAMAGE event they're reacting to.
					# Without this, inline events would be collected in the main combat loop
					# and inserted before subsequent attack events, breaking causal order.
					var hurt_inline_evts = collect_inline_events()
					out_events.append_array(hurt_inline_evts)
					
					# DETERMINISTIC ON_KILL: If this damage killed the target, trigger on_kill immediately
					# This ensures kills are detected at the moment of state change, not by snapshot comparison
					for tgt_uuid in damaged_uuids:
						var tgt = get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt) and tgt.current_hp <= 0:
							trigger_on_kill(request.source_uuid, tgt_uuid)
			elif stat == "pwr" and amount > 0 and not resolved_targets.is_empty():
				var log_targets_str = ""
				if not target_names.is_empty():
					log_targets_str = ", ".join(target_names)
				if log_targets_str != "":
					out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "Gains %d PWR: %s" % [amount, log_targets_str]}))
				
				var targets_old_pwr: Array[int] = []
				var targets_new_pwr: Array[int] = []
				
				for i in range(resolved_targets.size()):
					var single_target_uuid := resolved_targets[i]
					var tgt = get_instance_by_uuid(single_target_uuid)
					if is_instance_valid(tgt):
						targets_old_pwr.append(tgt.current_pwr)
						var new_p = apply_stat_delta(tgt, "pwr", amount) # ✅ Apply THEN snapshot
						targets_new_pwr.append(new_p)
					else:
						targets_old_pwr.append(0)
						targets_new_pwr.append(0)
				
				out_events.append(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": request.source_uuid,
					"target_uuids": resolved_targets,
					"ability_id": request.ability_id,
					"trigger_type": request.trigger_context.get("trigger_type", ""),
					"ability_holder_uuid": request.source_uuid,
					"visual_payload": {
						"source_uuid": request.source_uuid,
						"amount": amount,
						"stat": "pwr",
						"targets_old_pwr": targets_old_pwr,
						"targets_new_pwr": targets_new_pwr
					}
				}))
				
			elif stat == "burn_stacks" and not resolved_targets.is_empty():
				var targets_old_val: Array[int] = []
				var targets_new_val: Array[int] = []
				
				for i in range(resolved_targets.size()):
					var single_target_uuid := resolved_targets[i]
					var tgt = get_instance_by_uuid(single_target_uuid)
					if is_instance_valid(tgt):
						targets_old_val.append(tgt.get_status_effect_amount(&"burn"))
						var new_v = apply_stat_delta(tgt, "burn_stacks", amount)
						targets_new_val.append(new_v)
					else:
						targets_old_val.append(0)
						targets_new_val.append(0)
				
				out_events.append(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": request.source_uuid,
					"target_uuids": resolved_targets,
					"ability_id": request.ability_id,
					"trigger_type": request.trigger_context.get("trigger_type", ""),
					"ability_holder_uuid": request.source_uuid,
					"visual_payload": {
						"source_uuid": request.source_uuid,
						"amount": amount,
						"stat": "burn_stacks",
						"targets_old_val": targets_old_val,
						"targets_new_val": targets_new_val
					}
				}))
			# Handle summon effects (e.g., item_t2_c02)
			elif effect_data.has("summon_unit_id"):
				var unit_id = effect_data.get("summon_unit_id")
				var holder_uuid = effect_data.get("holder_uuid", "")
				var holder_location = effect_data.get("holder_location")
				
				var is_resurrection = effect_data.get("is_resurrection", false)
				
				if unit_id and is_instance_valid(holder_location):
					# Create new instance - try units first, then general database
					var unit_def = Database.units.get(unit_id)
					if not is_instance_valid(unit_def):
						unit_def = Database.get_definition(unit_id)
					if is_instance_valid(unit_def):
						var new_inst = GachaBallInstance.new()
						new_inst.initialize(unit_def)
						# Ensure fresh state (clears any default/shared status effects)
						new_inst.reset_battle_stats_silent() # Silent during simulation
						
						# Add to battle model IMMEDIATELY so it can be targeted in this turn
						_battle_instances[new_inst.ball_uuid] = new_inst
						
						# Handle Old Unit: Use unified cleanup logic (skip for resurrection)
						if not is_resurrection:
							var holder_inst = get_instance(holder_uuid)
							if is_instance_valid(holder_inst):
								_perform_unit_death_cleanup(holder_inst)
						else:
							# For resurrection: clear the slot of the dead unit (if still there)
							var rez_container = get_container(holder_location.container)
							if is_instance_valid(rez_container):
								var old_uuid = rez_container.get_uuid(holder_location.index)
								if not old_uuid.is_empty():
									var old_inst = get_instance(old_uuid)
									if is_instance_valid(old_inst) and old_inst.current_hp <= 0:
										_perform_unit_death_cleanup(old_inst)
						
						# Set new unit's location
						_update_instance_location(
							new_inst.ball_uuid,
							holder_location.container,
							holder_location.index
						)
						
						# Update the physical container so targeting logic can find the new unit
						# This is safe because FixedArrayContainer.set_uuid does NOT emit signals
						var container = get_container(holder_location.container)
						if is_instance_valid(container):
							container.set_uuid(holder_location.index, new_inst.ball_uuid)
						
						# Update Actor Queue: If the holder was waiting to act, replace them with the new unit
						for i in range(_actor_queue.size()):
							if _actor_queue[i].ball_uuid == holder_uuid:
								_actor_queue[i] = new_inst
								break
						
						# Create SUMMON event (presentation layer only)
						# Include complete snapshot of new unit so presenter can create view without queries
						var new_unit_icon = unit_def.icon if "icon" in unit_def else null
						var new_unit_tier = unit_def.tier if "tier" in unit_def else 0
						var new_unit_category = unit_def.category if "category" in unit_def else &"UNIT"
						var new_unit_name_key = unit_def.display_name_key if "display_name_key" in unit_def else ""
						
						out_events.append(CombatEvent.new(CombatEvent.Type.SUMMON, {
							"source_uuid": request.source_uuid,
							"target_uuids": [new_inst.ball_uuid],
							"ability_id": request.ability_id,
							"trigger_type": request.trigger_context.get("trigger_type", ""),
							"ability_holder_uuid": request.source_uuid,
							"visual_payload": {
								"old_unit_uuid": holder_uuid,
								"new_unit_uuid": new_inst.ball_uuid,
								"old_unit_location": holder_location,
								# Complete new unit snapshot for view creation
								"new_unit_snapshot": {
									"uuid": new_inst.ball_uuid,
									"hp": new_inst.current_hp,
									"pwr": new_inst.current_pwr,
									"burn_stacks": new_inst.get_status_effect_amount(&"burn"),
									"def_id": unit_def.id,
									"icon": new_unit_icon,
									"tier": new_unit_tier,
									"category": new_unit_category,
									"display_name_key": new_unit_name_key
								}
							}
						}))
			# Handle boss summon effects (array of units to summon)
			elif effect_data.has("summon_units"):
				var summon_list: Array = effect_data.get("summon_units", [])
				var team: String = effect_data.get("team", "ENEMY")
				var target_container_tag: StringName = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "ENEMY" else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
				
				for summon_data in summon_list:
					var unit_id = summon_data.get("unit_id")
					var unit_def = Database.get_definition(unit_id)
					if not is_instance_valid(unit_def):
						continue
					
					# Find empty slot in target lineup
					var lineup_container = get_container(target_container_tag)
					if not is_instance_valid(lineup_container):
						break
					
					var empty_slot: int = lineup_container.find_first_empty_slot()
					if empty_slot == -1 or empty_slot >= 5:
						break # No more slots
					
					# Create and place unit
					var new_unit = GachaBallInstance.new()
					new_unit.initialize(unit_def)
					new_unit.reset_battle_stats_silent()
					
					_battle_instances[new_unit.ball_uuid] = new_unit
					lineup_container.set_uuid(empty_slot, new_unit.ball_uuid)
					_update_instance_location(new_unit.ball_uuid, target_container_tag, empty_slot)
					
					# Insert into actor queue so summoned unit can act this turn if its slot hasn't passed
					_insert_summoned_unit_into_queue(new_unit)
					
					# Create location for visual payload
					var summon_loc = LocationIdentifier.new()
					summon_loc.container = target_container_tag
					summon_loc.index = empty_slot
					
					# Create SUMMON event for animation
					var new_unit_icon = unit_def.icon if "icon" in unit_def else null
					var new_unit_tier = unit_def.tier if "tier" in unit_def else 0
					var new_unit_category = unit_def.category if "category" in unit_def else &"UNIT"
					var new_unit_name_key = unit_def.display_name_key if "display_name_key" in unit_def else ""
					
					out_events.append(CombatEvent.new(CombatEvent.Type.SUMMON, {
						"source_uuid": request.source_uuid,
						"target_uuids": [new_unit.ball_uuid],
						"ability_id": request.ability_id,
						"trigger_type": request.trigger_context.get("trigger_type", ""),
						"ability_holder_uuid": request.source_uuid,
						"visual_payload": {
							"old_unit_uuid": "", # No old unit for boss summons
							"new_unit_uuid": new_unit.ball_uuid,
							"old_unit_location": summon_loc,
							"new_unit_snapshot": {
								"uuid": new_unit.ball_uuid,
								"hp": new_unit.current_hp,
								"pwr": new_unit.current_pwr,
								"burn_stacks": new_unit.get_status_effect_amount(&"burn"),
								"def_id": unit_def.id,
								"icon": new_unit_icon,
								"tier": new_unit_tier,
								"category": new_unit_category,
								"display_name_key": new_unit_name_key
							}
						}
					}))
	# CRITICAL FIX: Death check MUST run unconditionally after any effect execution
	# This was previously inside the TYPE_DICTIONARY block, causing deaths from the
	# last attack of a turn to miss on_ally_death triggers when effect returned null
	_check_for_deaths_with_counter_delay(true, out_events, death_tracking)

## New priority-driven combat phase resolution.
## Uses actor queue with nested reaction loops for cascading effects.
func get_board_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for uuid in _battle_instances:
		var inst = _battle_instances[uuid]
		if is_instance_valid(inst):
			var location = inst.get_location()
			# CRITICAL FIX: Only include instances that have visual representations
			# Equipped items, inventory items, and trinkets don't have their own views
			# Including them causes unpredictable iteration order during registry population
			if is_instance_valid(location) and location is LocationIdentifier:
				var container = location.container
				# Only include units in lineups and bench - these have GachaBallView instances
				if container == &"PlayerLineup" or container == &"EnemyLineup" or container == &"PlayerBench":
					# Get definition for visual data
					var def = inst.get_definition()
					
					# TRUE DECOUPLING: Store VALUES not references
					# Presentation will never query BattleManager or GameManager
					snapshot[uuid] = {
						# Core stats
						"hp": inst.current_hp,
						"pwr": inst.current_pwr,
						"burn_stacks": inst.get_status_effect_amount(&"burn"),
						# Definition data for view creation
						"def_id": def.id if is_instance_valid(def) else "",
						"icon": def.icon if (is_instance_valid(def) and "icon" in def) else null,
						"tier": def.tier if (is_instance_valid(def) and "tier" in def) else 0,
						"category": def.category if (is_instance_valid(def) and "category" in def) else &"UNIT",
						"display_name_key": def.display_name_key if (is_instance_valid(def) and "display_name_key" in def) else "",
						# Location as VALUES not reference - no coupling!
						"container_tag": container, # StringName value
						"slot_index": location.index # int value
					}
	return snapshot

func _resolve_combat_phase() -> void:
	if _is_processing_effect: return
	_resolve_animator()
	_populate_actor_queue()
	
	# 1. Capture State BEFORE Simulation
	var start_snapshot = get_board_snapshot()
	var turn_log: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	var _actor_index = 0
	while not _actor_queue.is_empty():
		var current_actor: GachaBallInstance = _actor_queue.pop_front()
		_actor_index += 1
		
		if not is_instance_valid(current_actor):
			continue
		
		if current_actor.current_hp <= 0:
			continue

		_enqueue_attack_for(current_actor)
		
		# Reaction loop - process ALL reactions before checking battle-over
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var current_reaction = _pending_reactions.pop_front()
			
			var reaction_events: Array[CombatEvent] = []
			_resolve_single_effect_request(current_reaction, reaction_events, death_tracking)
			
			# Collect inline events generated DURING effect execution (e.g., on_before_attack heals)
			# These must appear BEFORE the damage events to maintain causal order:
			# HEAL animation → HP label update → DAMAGE animation → HP label update
			var inline_evts = collect_inline_events()
			turn_log.append_array(inline_evts)
			
			turn_log.append_array(reaction_events)
			
			# Process deferred deaths
			var deferred_death_events: Array[CombatEvent] = []
			_process_completed_counter_deaths(deferred_death_events, death_tracking)
			turn_log.append_array(deferred_death_events)
		
		# NOTE: on_kill triggers are now fired immediately in _resolve_single_effect_request
		# when damage causes HP <= 0, so no snapshot comparison needed here
		
		# Process any on_kill reactions (like Bloodlust granting extra action)
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var kill_reaction = _pending_reactions.pop_front()
			var kill_reaction_events: Array[CombatEvent] = []
			_resolve_single_effect_request(kill_reaction, kill_reaction_events, death_tracking)
			turn_log.append_array(kill_reaction_events)
	
		# Check battle-over AFTER all reactions for this actor are processed
		# This allows summons and other reactive abilities to complete
		if _is_battle_over():
			_battle_over_deferred = true
			_actor_queue.clear()
			break

	# CRITICAL: Final reaction drain - process ANY remaining reactions after all actors have acted
	# This ensures reactive abilities (on_hurt, on_ally_death, item/trinket reactions) fully complete
	# even if they were enqueued during the last actor's attack resolution
	while not _pending_reactions.is_empty():
		_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
		var final_reaction = _pending_reactions.pop_front()
		
		var final_reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(final_reaction, final_reaction_events, death_tracking)
		
		# Collect inline events
		var final_inline_evts = collect_inline_events()
		turn_log.append_array(final_inline_evts)
		
		turn_log.append_array(final_reaction_events)
		
		# Process deferred deaths for final reactions
		var final_death_events: Array[CombatEvent] = []
		_process_completed_counter_deaths(final_death_events, death_tracking)
		turn_log.append_array(final_death_events)

	# Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()

	_is_processing_effect = false
	# DO NOT unblock inventory updates here!
	# Keep them blocked until animations finish to prevent _redraw_board() from destroying views
	# _block_inventory_updates will be set to false in _on_turn_animation_finished()
	
	# 2. Send Log to Animator (The VCR Playback)
	if not turn_log.is_empty():
		_animator.play_turn_sequence(start_snapshot, turn_log)
	else:
		_on_turn_animation_finished()

func _on_turn_animation_finished() -> void:
	print("[DEBUG] _on_turn_animation_finished called. Phase: ", get_current_phase_name())
	# This signal is the single source of truth for when animations are complete.
	# It is safe to proceed to the next phase.
	_is_processing_effect = false
	
	# Finalize any remaining deaths (removes zombies)
	_finalize_deaths()
	
	if _current_battle_phase == Phases.START_OF_TURN:
		# Turn start abilities finished animating, transition to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)
	elif _current_battle_phase == Phases.END_OF_TURN:
		# Check if battle is over after poison/turn-end effects
		if _battle_over_deferred or _is_battle_over():
			_battle_over_deferred = false
			_emit_battle_over()
			return
		# Poison/turn-end animations finished, now start the next turn
		_change_phase(Phases.START_OF_TURN)
	elif _current_battle_phase == Phases.COMBAT:
		# If a battle over condition was detected during simulation, emit it now
		if _battle_over_deferred:
			_battle_over_deferred = false
			# Emit and transition to BATTLE_OVER now that visuals are done
			_emit_battle_over()
			return
		# After combat finishes, trigger end of turn abilities, then start next turn
		_change_phase(Phases.END_OF_TURN)

func _move_instance_to_discard(instance: GachaBallInstance) -> void:
	assert(is_instance_valid(instance), "_move_instance_to_discard: instance is null")
	print("[DEBUG] _move_instance_to_discard: ", instance.ball_uuid, " from container: ", instance.location_container_tag)
	# Ownership gate: only player-owned instances can enter the player's discard pile
	assert(_is_player_owned(instance), "_move_instance_to_discard: instance is not player owned")
	# Atomically remove from current location (equipped or container) and place into discard
	var loc := get_location_for_uuid(instance.ball_uuid)
	if is_instance_valid(loc):
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent := get_instance(loc.unit_uuid)
			if is_instance_valid(parent):
				if loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
					# Clear the parent's slot mapping if it points to this instance
					if parent.equipped_item_uuids[loc.index] == instance.ball_uuid:
						parent.equipped_item_uuids[loc.index] = ""
			# Clear equipped linkage on the item itself
			instance.equipped_on_uuid = ""
			instance.equipped_slot_index = -1
		else:
			var src := get_container(loc.container)
			if is_instance_valid(src):
				var uuids := src.get_all_uuids()
				var si := uuids.find(instance.ball_uuid)
				if si != -1:
					src.set_uuid(si, "")
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard_container): return
	var index := discard_container.find_first_empty_slot()
	if index == -1:
		# Discard full: do not attempt out-of-bounds write; leave instance removed and log via validator
		return
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)

func _remove_instance_from_container(instance: GachaBallInstance) -> void:
	assert(is_instance_valid(instance), "_remove_instance_from_container: instance is null")
	var loc = get_location_for_uuid(instance.ball_uuid)
	assert(is_instance_valid(loc), "_remove_instance_from_container: instance has no location")
	var container = get_container(loc.container)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx: int = uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			_update_instance_location(instance.ball_uuid, &"", -1)
		else:
			push_error("Remove failed: %s not found in stated container %s" % [instance.ball_uuid, String(loc.container)])

func _check_for_deaths(is_simulation: bool = false, out_events = null) -> void:
	var something_changed = false
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not _register_death(unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "PLAYER",
					"dying_location": death_location,
					"equipped_items": _snapshot_equipped_items(unit)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context: Dictionary = {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": "PLAYER"
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
				# _perform_unit_death_cleanup(unit)
		
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not _register_death(unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "ENEMY",
					"dying_location": death_location,
					"equipped_items": _snapshot_equipped_items(unit)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context: Dictionary = {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": "ENEMY"
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
## Centralized logic for cleaning up a dead unit.
## Moves player units to discard, removes enemy units entirely.

## Snapshot equipped items for context enrichment (effects should use context, not query instances)
func _snapshot_equipped_items(unit: GachaBallInstance) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item_uuid in unit.equipped_item_uuids:
		if not item_uuid.is_empty():
			var item = get_instance(item_uuid)
			if is_instance_valid(item):
				var item_def = item.get_definition()
				items.append({
					"uuid": item.ball_uuid,
					"def_id": item.definition_id,
					"equipped_on_uuid": item.equipped_on_uuid,
					"slot_index": item.equipped_slot_index,
					"category": item_def.category if is_instance_valid(item_def) else &"ITEM"
				})
	return items

# -----------------------------------------------------------------------------
# UNIFIED DEATH TRACKING
# -----------------------------------------------------------------------------
# These functions provide the SINGLE source of truth for death tracking within a turn.
# All code paths that detect deaths must use _register_death() to ensure:
#   1. Each unit dies exactly ONCE per turn
#   2. DEATH events are generated exactly ONCE per death
#   3. Death triggers (on_death, on_ally_death) fire exactly ONCE per death

## Register a unit as dead. Returns true if this is a NEW death, false if already registered.
## This is the ONLY function that should mark a unit as dead. All death detection code paths
## must call this before creating DEATH events or firing triggers.
func _register_death(unit: GachaBallInstance, phase: StringName) -> bool:
	assert(is_instance_valid(unit), "_register_death: unit is null")
	
	if _dead_this_turn.has(unit.ball_uuid):
		return false # Already dead this turn - prevent duplicate processing
	
	var is_player = _is_player_unit(unit)
	_dead_this_turn[unit.ball_uuid] = {
		"team": "PLAYER" if is_player else "ENEMY",
		"died_in_phase": phase,
		"def_id": unit.definition_id
	}
	return true

## Check if a unit has already died this turn. Use this to skip dead units in loops.
func is_dead_this_turn(unit_uuid: String) -> bool:
	return _dead_this_turn.has(unit_uuid)

## Get death info for a unit (team, phase, def_id). Returns empty dict if not dead.
func get_death_info(unit_uuid: String) -> Dictionary:
	return _dead_this_turn.get(unit_uuid, {})

func _perform_unit_death_cleanup(unit: GachaBallInstance) -> void:
	assert(is_instance_valid(unit), "_perform_unit_death_cleanup: unit is null")
	print("[DEBUG] _perform_unit_death_cleanup for: ", unit.ball_uuid, " HP: ", unit.current_hp, " container: ", unit.location_container_tag)
	
	# Guard against duplicate cleanup calls - if container is already empty, unit was already cleaned up
	if unit.location_container_tag == &"" or unit.location_container_tag == &"DiscardPile":
		return
	
	if _is_player_owned(unit):
		# Player unit: move equipped items to discard then move unit to discard
		for item_uuid in unit.equipped_item_uuids:
			if not item_uuid.is_empty():
				var item_instance := get_instance(item_uuid)
				if is_instance_valid(item_instance):
					_move_instance_to_discard(item_instance)
		unit.equipped_item_uuids.fill("")
		
		# Reset unit state (clear damage, status effects) before moving to discard
		unit.reset_battle_stats_silent() # Silent during simulation
		
		_move_instance_to_discard(unit)
	else:
		# Enemy unit: clear equipped linkage and erase items, then remove unit from container
		# CRITICAL: Do NOT erase from _battle_instances yet! The unit's on_death reactions
		# need to resolve first. Premature erasure causes get_instance_by_uuid() to return null
		# and the effect execution to be skipped. We track these for later cleanup.
		for item_uuid in unit.equipped_item_uuids:
			if not item_uuid.is_empty():
				var item_instance := get_instance(item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = ""
					item_instance.equipped_slot_index = -1
					_update_instance_location(item_instance.ball_uuid, &"", -1)
					# Defer item erasure too - items have on_death abilities!
					if not has_meta("_deferred_enemy_erasures"):
						set_meta("_deferred_enemy_erasures", [])
					var erasure_list: Array = get_meta("_deferred_enemy_erasures")
					erasure_list.append(item_instance.ball_uuid)
					set_meta("_deferred_enemy_erasures", erasure_list)
		unit.equipped_item_uuids.fill("")
		_remove_instance_from_container(unit)
		# Defer unit erasure until after all reactions have resolved
		if not has_meta("_deferred_enemy_erasures"):
			set_meta("_deferred_enemy_erasures", [])
		var erasure_list2: Array = get_meta("_deferred_enemy_erasures")
		erasure_list2.append(unit.ball_uuid)
		set_meta("_deferred_enemy_erasures", erasure_list2)

## Check if a unit has counter-attack abilities that could trigger on lethal damage
func _has_lethal_counter_abilities(unit: GachaBallInstance) -> bool:
	assert(is_instance_valid(unit), "_has_lethal_counter_abilities: unit is null")
	
	var definition = unit.get_definition()
	if not is_instance_valid(definition):
		return false
	
	# Check unit's own abilities for counter-attacks
	for ability in definition.ability_definitions:
		if not is_instance_valid(ability) or ability.trigger != &"on_hurt":
			continue
		if String(ability.id) == "unit_tier3d_resilient_aura":
			return true
		# Check if it's a counter-attack ability (uses ATTACKER target or has "counter"/"retaliate" in ID)
		for effect in ability.effects:
			if is_instance_valid(effect) and effect.target_type == C.TARGET_ATTACKER:
				return true
		var ability_id_str := String(ability.id)
		if ability_id_str.contains("counter") or ability_id_str.contains("retaliate"):
			return true
	
	# Check equipped items for on_hurt abilities (retaliation, counter, etc.)
	for item_uuid in unit.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		var item_instance = get_instance_by_uuid(item_uuid)
		if not is_instance_valid(item_instance):
			continue
		var item_def = item_instance.get_definition()
		if not is_instance_valid(item_def):
			continue
		for ability in item_def.ability_definitions:
			if not is_instance_valid(ability) or ability.trigger != &"on_hurt":
				continue
			var ability_id_str := String(ability.id)
			if ability_id_str.contains("counter") or ability_id_str.contains("retaliate"):
				return true
			for effect in ability.effects:
				if is_instance_valid(effect) and (effect.target_type == C.TARGET_ATTACKER or effect.target_type == C.TARGET_RANDOM_ENEMY):
					return true
	
	return false

## Enhanced death checking that defers death events for units with counter-attacks
func _check_for_deaths_with_counter_delay(is_simulation: bool = false, out_events = null, death_tracking = null) -> void:
	var something_changed = false
	var deferred_deaths: Array[String] = [] # Units whose deaths should be deferred
	
	# SKIP death trigger processing if called from drain_pending_reactions_inline
	# This prevents duplicate on_ally_death triggers for already-dead units
	if death_tracking != null and death_tracking.get("__skip_death_triggers__", false):
		return
	
	# CAUSALITY FIX: Drain pending on_hurt reactions BEFORE processing on_death triggers
	# This ensures the event order is: DAMAGE → on_hurt effects → DEATH → on_death effects
	# Without this, on_death SUMMON events would be generated before on_hurt HEAL/BUFF events
	if is_simulation and out_events != null and not _pending_reactions.is_empty():
		# Process all pending reactions (on_hurt, counter-attacks, etc.) FIRST
		drain_pending_reactions_inline(0)
		# Append the generated events to out_events in the correct causal order
		var inline_evts: Array[CombatEvent] = collect_inline_events()
		for evt in inline_evts:
			out_events.append(evt)
	
	# Check player units
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					# Use unified death registry to prevent cross-phase duplicate processing
					if _register_death(unit, &"COMBAT"):
						# Track first-killed for resurrection (before triggers fire)
						var first_killed_key := "first_killed_player_unit"
						if not _turn_metadata.has(first_killed_key):
							var unit_def_fk = unit.get_definition()
							if is_instance_valid(unit_def_fk) and not unit_def_fk.is_hero:
								var loc_snapshot = get_location_for_uuid(unit.ball_uuid)
								if is_instance_valid(loc_snapshot):
									_turn_metadata[first_killed_key] = {
										"def_id": unit.definition_id,
										"team": "PLAYER",
										"location_snapshot": loc_snapshot
									}
						# on_death for the dying unit (semantic key: dying_uuid)
						# Enrich context so effects use context data, not get_instance()
						var death_location = get_location_for_uuid(unit.ball_uuid)
						var death_ctx := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "PLAYER",
							"dying_location": death_location,
							"equipped_items": _snapshot_equipped_items(unit)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx)
						
						# Check if this unit has on_hurt reactions that should complete before death
						# (counter-attacks, resilient aura buffs, etc.)
						# If so, defer DEATH event AND on_ally_death until after reactions complete
						if _has_lethal_counter_abilities(unit):
							# DEATH event and on_ally_death will be generated by _process_completed_counter_deaths()
							# after all counter-attacks and buffs have resolved
							# Store the dying unit's info for deferred on_ally_death trigger
							if not has_meta("deferred_ally_deaths_player"):
								set_meta("deferred_ally_deaths_player", [])
							var deferred_list: Array = get_meta("deferred_ally_deaths_player")
							deferred_list.append({
								"uuid": unit.ball_uuid,
								"location": death_location,
								"slot": unit.location_slot_index,
								"def_id": unit.definition_id
							})
							set_meta("deferred_ally_deaths_player", deferred_list)
						else:
							# No on_hurt reactions - generate DEATH event immediately
							# Use _create_death_event_if_needed to ensure consistent tracking
							_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
							
							# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
							var ally_death_ctx := {
								"fainting_ally_uuid": unit.ball_uuid,
								"fainting_ally_location": death_location,
								"fainting_ally_team": "PLAYER"
							}
							AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
				
				# Game state cleanup is deferred - unit stays in containers for reaction targeting
				# But DEATH event may be immediate or deferred depending on on_hurt abilities
				deferred_deaths.append(unit.ball_uuid)
				
				# Legacy immediate path removed to enforce ordering
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				_perform_unit_death_cleanup(unit)
	
	# Check enemy units (same logic)
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			var _unit_def2 = unit.get_definition()
			var _unit_name2 = tr(_unit_def2.display_name_key) if "display_name_key" in _unit_def2 else String(_unit_def2.id)
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					# Use unified death registry to prevent cross-phase duplicate processing
					if _register_death(unit, &"COMBAT"):
						# Track first-killed for resurrection (before triggers fire)
						var first_killed_key2 := "first_killed_enemy_unit"
						if not _turn_metadata.has(first_killed_key2):
							var unit_def_fk2 = unit.get_definition()
							if is_instance_valid(unit_def_fk2) and not unit_def_fk2.is_hero:
								var loc_snapshot2 = get_location_for_uuid(unit.ball_uuid)
								if is_instance_valid(loc_snapshot2):
									_turn_metadata[first_killed_key2] = {
										"def_id": unit.definition_id,
										"team": "ENEMY",
										"location_snapshot": loc_snapshot2
									}
									print("[DEBUG BM] Stored first_killed_enemy_unit: def_id=%s" % unit.definition_id)
						# on_death for the dying unit (semantic key: dying_uuid)
						# Enrich context so effects use context data, not get_instance()
						var death_location2 = get_location_for_uuid(unit.ball_uuid)
						var death_ctx2 := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "ENEMY",
							"dying_location": death_location2,
							"equipped_items": _snapshot_equipped_items(unit)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx2)
						
						# Check if this unit has on_hurt reactions that should complete before death
						# (counter-attacks, resilient aura buffs, etc.)
						# If so, defer DEATH event AND on_ally_death until after reactions complete
						if _has_lethal_counter_abilities(unit):
							# DEATH event and on_ally_death will be generated by _process_completed_counter_deaths()
							# after all counter-attacks and buffs have resolved
							# Store the dying unit's info for deferred on_ally_death trigger
							if not has_meta("deferred_ally_deaths_enemy"):
								set_meta("deferred_ally_deaths_enemy", [])
							var deferred_list2: Array = get_meta("deferred_ally_deaths_enemy")
							deferred_list2.append({
								"uuid": unit.ball_uuid,
								"location": death_location2,
								"slot": unit.location_slot_index,
								"def_id": unit.definition_id
							})
							set_meta("deferred_ally_deaths_enemy", deferred_list2)
						else:
							# No on_hurt reactions - generate DEATH event immediately
							# Use _create_death_event_if_needed to ensure consistent tracking
							_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
							
							# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
							var ally_death_ctx2 := {
								"fainting_ally_uuid": unit.ball_uuid,
								"fainting_ally_location": death_location2,
								"fainting_ally_team": "ENEMY"
							}
							AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx2)
				
				# Game state cleanup is deferred - unit stays in containers for reaction targeting
				# But DEATH event may be immediate or deferred depending on on_hurt abilities
				deferred_deaths.append(unit.ball_uuid)
				
				# Legacy immediate path removed to enforce ordering
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				_perform_unit_death_cleanup(unit)
	
	# Store deferred deaths for processing after their counter-attacks complete
	if not deferred_deaths.is_empty():
		# Store current deferred deaths, merging with any existing ones
		var existing_deferred: Array = get_meta("deferred_deaths", [])
		existing_deferred.append_array(deferred_deaths)
		set_meta("deferred_deaths", existing_deferred)
	
	if something_changed and not is_simulation:
		_emit_battle_inventory_changed()

## Helper function to create DEATH events only once per unit
func _create_death_event_if_needed(unit_uuid: String, out_events: Array, death_tracking: Dictionary) -> void:
	if death_tracking.has(unit_uuid):
		return # Already created death event for this unit
	
	death_tracking[unit_uuid] = true
	out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
		"target_uuids": [unit_uuid],
		"visual_payload": {}
	}))

## Check if any deferred counter-attack units have completed their abilities and should now die
func _process_completed_counter_deaths(out_events = null, death_tracking = null) -> void:
	if not has_meta("deferred_deaths"):
		return
	
	var deferred_deaths: Array = get_meta("deferred_deaths")
	var remaining_deferred: Array = []
	
	
	for uuid in deferred_deaths:
		var unit = get_instance_by_uuid(uuid)
		if not is_instance_valid(unit):
			continue
		
		var _unit_def = unit.get_definition()
		var _unit_name = tr(_unit_def.display_name_key) if "display_name_key" in _unit_def else String(_unit_def.id)
			
		# Check if this unit still has ANY pending reactions (counters, on_death, etc.)
		var has_pending_counters = false
		for request in _pending_reactions:
			if request.source_uuid == uuid:
				has_pending_counters = true
				break
		
		# If no pending counter-attacks, this unit can die now
		if not has_pending_counters:
			if out_events != null and death_tracking != null:
				_create_death_event_if_needed(uuid, out_events, death_tracking)
			
			# Process deferred on_ally_death triggers for this unit
			# These were stored when the death was detected but counter-attacks were pending
			_process_deferred_ally_death(uuid, "PLAYER")
			_process_deferred_ally_death(uuid, "ENEMY")
			
			# CRITICAL FIX: Actually clean up the unit from the game state
			# Without this, units stay in lineup with HP<=0 and die again on next turn
			_perform_unit_death_cleanup(unit)
		else:
			# Still has pending counter-attacks, keep deferred
			remaining_deferred.append(uuid)
	
	# Update the deferred deaths list
	if remaining_deferred.is_empty():
		remove_meta("deferred_deaths")
	else:
		set_meta("deferred_deaths", remaining_deferred)

## Helper function to process deferred on_ally_death triggers after counter-attacks resolve
func _process_deferred_ally_death(dying_uuid: String, team: String) -> void:
	var meta_key = "deferred_ally_deaths_player" if team == "PLAYER" else "deferred_ally_deaths_enemy"
	if not has_meta(meta_key):
		return
	
	var deferred_list: Array = get_meta(meta_key)
	var remaining_list: Array = []
	
	for entry in deferred_list:
		if entry.uuid != dying_uuid:
			remaining_list.append(entry)
			continue
		
		# This dying unit's on_ally_death triggers can now fire
		var death_location = entry.location
		
		# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
		var ally_death_ctx := {
			"fainting_ally_uuid": dying_uuid,
			"fainting_ally_location": death_location,
			"fainting_ally_team": team
		}
		AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
	
	# Update the deferred list
	if remaining_list.is_empty():
		remove_meta(meta_key)
	else:
		set_meta(meta_key, remaining_list)

func _on_apply_deaths_requested(dead_unit_uuids: Array) -> void:
	if dead_unit_uuids == null:
		return
	for uuid in dead_unit_uuids:
		var unit := get_instance_by_uuid(String(uuid))
		if not is_instance_valid(unit):
			continue
		# Apply the same non-simulation removal rules as in _check_for_deaths
		var def = unit.get_definition()
		if is_instance_valid(def) and def.category == &"UNIT":
			_perform_unit_death_cleanup(unit)
	# After removals, refresh UI
	_emit_battle_inventory_changed()
	# If battle is now over, defer victory to end of animations
	var _player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var _enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if _current_battle_phase == Phases.COMBAT and _is_battle_over():
		_battle_over_deferred = true

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	# Check if any hero died - immediate defeat
	for unit in player_lineup:
		var def = unit.get_definition()
		if is_instance_valid(def) and def.is_hero and unit.current_hp <= 0:
			return true # Hero died = defeat
	
	# Check if any player units are alive
	var player_has_alive = false
	for unit in player_lineup:
		if unit.current_hp > 0:
			player_has_alive = true
			break
	
	# Check if any enemy units are alive
	var enemy_has_alive = false
	for unit in enemy_lineup:
		if unit.current_hp > 0:
			enemy_has_alive = true
			break
	
	# Battle is over if either side has no living units
	return not player_has_alive or not enemy_has_alive

func _emit_battle_over() -> void:
	# Transition to BATTLE_OVER and emit results once animations are finished.
	_current_battle_phase = Phases.BATTLE_OVER
	if not _battle_over_emitted:
		_battle_over_emitted = true
		SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
		
		# Determine victory/defeat - hero death = defeat even if other player units alive
		var player_won := true
		var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		
		# Check if any hero died - immediate defeat
		for unit in player_lineup:
			var def = unit.get_definition()
			if is_instance_valid(def) and def.is_hero and unit.current_hp <= 0:
				player_won = false
				break
		
		# If no hero died, check if any player units are alive
		if player_won:
			var any_player_alive := false
			for unit in player_lineup:
				if unit.current_hp > 0:
					any_player_alive = true
					break
			player_won = any_player_alive
		
		var results: Dictionary = {"victory": player_won}
		SignalBus.emit_signal("battle_ended", results)
		if player_won:
			_on_battle_victory()

func _restore_hero_location_to_run_state() -> void:
	"""Restore hero's location to original run state location after battle ends."""
	if not is_instance_valid(GameManager.run_state):
		return
	
	var hero_instance = GameManager.run_state.hero_instance
	if is_instance_valid(hero_instance):
		# Restore hero to its original run state location (PlayerLineup:0)
		hero_instance.location_container_tag = GameManager.run_state.RUN_CONTAINER_TAGS.PLAYER_LINEUP
		hero_instance.location_slot_index = 0

func _on_battle_victory() -> void:
	# Only restore the hero's location in the run state.
	# The hero's stats (HP, power, etc.) remain as they were before the battle.
	# All other battle state (including unit HP changes) is discarded.
	_restore_hero_location_to_run_state()
	# Note: All battle instances (including the hero's battle copy) will be garbage collected
	# when the battle scene is freed, leaving the original hero instance unchanged.

## Resolve targets for an effect based on target type and context.
## @param source_uuid: String - The UUID of the source instance
## @param target_type: StringName - The type of target to resolve (e.g., "SELF", "FRONTMOST_ENEMY")
## @param context: Dictionary - The context of the event
## @return Array[String] - Array of target UUIDs

func resolve_target(source_uuid: String, target_type: StringName, context: Dictionary) -> Array[String]:
	var source_instance = get_instance_by_uuid(source_uuid)
	var is_player_team := false
	if context.has("team"):
		is_player_team = (String(context.get("team")) == "PLAYER")
	elif is_instance_valid(source_instance):
		var src_def = source_instance.get_definition()
		if is_instance_valid(src_def):
			if src_def.category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
				var holder = get_instance_by_uuid(source_instance.equipped_on_uuid)
				if is_instance_valid(holder):
					is_player_team = _is_player_unit(holder)
			elif src_def.category == &"TRINKET":
				# Determine team from container tag
				is_player_team = (source_instance.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
			else:
				is_player_team = _is_player_unit(source_instance)
	else:
		return []

	match target_type:
		C.TARGET_SELF:
			return [source_uuid]
		C.TARGET_HOLDER:
			# For items, return the unit they're equipped to
			if source_instance.get_definition().category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
				return [source_instance.equipped_on_uuid]
			# For units, return self
			return [source_uuid]
		C.TARGET_ATTACK_TARGET:
			# Return the target from the attack context (if still alive)
			var target_uuid: String = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				var target_instance = get_instance_by_uuid(target_uuid)
				# Only target if still alive (prevents ghost attacks on dead units)
				if is_instance_valid(target_instance) and target_instance.current_hp > 0:
					return [target_uuid]
			return []
		C.TARGET_TRIGGERING_ENTITY:
			# Return the entity that triggered the event (if still alive)
			var triggering_uuid: String = context.get("triggering_uuid", "")
			if not triggering_uuid.is_empty():
				var triggering_instance = get_instance_by_uuid(triggering_uuid)
				# Only target if still alive
				if is_instance_valid(triggering_instance) and triggering_instance.current_hp > 0:
					return [triggering_uuid]
			return []
		C.TARGET_ATTACKER:
			# Return the original attacker from the context (for counter-attacks)
			# This enables reactive abilities to target the unit that dealt damage
			var attacker_uuid: String = context.get("attacker_uuid", "")
			if not attacker_uuid.is_empty():
				var attacker_instance = get_instance_by_uuid(attacker_uuid)
				# Only target the attacker if they are still alive (prevents infinite loops with dead units)
				if is_instance_valid(attacker_instance) and attacker_instance.current_hp > 0:
					return [attacker_uuid]
			return []
		C.TARGET_FRONTMOST_ENEMY:
			var target = _get_frontmost_target(is_player_team)
			if is_instance_valid(target):
				return [target.ball_uuid]
			return []
		# Support frontmost ally for trinket effects
		&"FRONTMOST_ALLY":
			# Per docs: Player frontmost = rightmost (highest index). Enemy frontmost = leftmost (lowest index).
			var ally_lineup_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
			var living_allies = get_instances_in_container(ally_lineup_tag).filter(func(unit): return unit.current_hp > 0)
			# print("DEBUG: Resolving FRONTMOST_ALLY. Source: ", source_uuid, " Is Player: ", is_player_team, " Allies: ", living_allies.size())
			if living_allies.is_empty():
				return []
			var best_unit: GachaBallInstance = living_allies[0]
			var best_index: int = get_location_for_uuid(best_unit.ball_uuid).index
			for u in living_allies:
				var idx: int = get_location_for_uuid(u.ball_uuid).index
				if is_player_team:
					# Pick highest index
					if idx > best_index:
						best_unit = u
						best_index = idx
				else:
					# Pick lowest index
					if idx < best_index:
						best_unit = u
						best_index = idx
			return [best_unit.ball_uuid]
		C.TARGET_RANDOM_ENEMY:
			var enemies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).filter(func(u): return u.current_hp > 0)
			if not enemies.is_empty():
				var random_enemy = enemies[randi() % enemies.size()]
				return [random_enemy.ball_uuid]
			return []
		C.TARGET_RANDOM_ALLY:
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			if not allies.is_empty():
				var random_ally = allies[randi() % allies.size()]
				return [random_ally.ball_uuid]
			return []
		C.TARGET_ALLY_BEHIND:
			var ally_behind = _get_ally_behind(source_instance)
			if is_instance_valid(ally_behind):
				return [ally_behind.ball_uuid]
			return []
		C.TARGET_ALLY_SLOT_AHEAD:
			# Return empty array for summoning slots (not implemented yet)
			return []
		C.TARGET_ADJACENT_ALLIES:
			var adjacent = _get_adjacent_allies(source_instance)
			var uuids: Array[String] = []
			for ally in adjacent:
				uuids.append(ally.ball_uuid)
			return uuids
		C.TARGET_ALL_ALLIES:
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).filter(func(u): return u.current_hp > 0)
			var uuids: Array[String] = []
			for ally in allies:
				uuids.append(ally.ball_uuid)
			return uuids
		_:
			return []

## Check if a condition is met for an ability.
## @param condition_def: ConditionDefinition - The condition to check
## @param source_uuid: String - The UUID of the source instance
## @param context: Dictionary - The context of the event
## @return bool - True if condition is met
func check_condition(condition_def: ConditionDefinition, source_uuid: String, context: Dictionary) -> bool:
	if not is_instance_valid(condition_def):
		return true # No condition means always true
	
	var source_instance = get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return false
	
	var result = false
	match condition_def.condition_type:
		C.COND_TEAM_SIZE_LESS_THAN_ENEMY:
			var is_source_player = _is_player_unit(source_instance)
			var ally_count = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).size()
			var enemy_count = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).size()
			result = ally_count < enemy_count
		C.COND_SLOT_AHEAD_IS_EMPTY:
			var slot_ahead = _get_slot_ahead(source_instance)
			result = slot_ahead == null
		C.COND_TARGET_HP_GREATER_THAN_SELF_HP:
			var target_uuid: String = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				var target_instance = get_instance_by_uuid(target_uuid)
				if is_instance_valid(target_instance):
					result = target_instance.current_hp > source_instance.current_hp
		C.COND_DAMAGE_WAS_NON_LETHAL:
			# Check if the unit that took damage is still alive (HP > 0)
			# For equipped items, we need to check the damaged unit from context, not the item itself
			var damaged_unit_uuid = context.get("source_uuid", "")
			var damaged_unit = get_instance_by_uuid(damaged_unit_uuid) if not damaged_unit_uuid.is_empty() else source_instance
			result = damaged_unit.current_hp > 0 if is_instance_valid(damaged_unit) else false
		C.COND_DAMAGE_WAS_RECEIVED:
			# Always true when processing on_hurt triggers - damage was received regardless of lethal outcome
			# This enables counter-attacks to trigger even when the damage is lethal
			result = true
		_:
			result = false
	
	# Apply inversion if specified
	return !result if condition_def.invert_result else result

## Enqueue an effect request for processing.
## @param effect_request: EffectRequest - The effect request to enqueue
func enqueue_effect_request(request: EffectRequest) -> void:
	## New priority-driven system: requests are added to _pending_reactions
	## and sorted by priority before execution. Higher priority = executes first.
	_pending_reactions.push_back(request)

## Get the current size of the pending reactions queue.
## Used by BasicAttackEffect to capture the queue state before triggering on_before_attack.
func get_pending_reactions_size() -> int:
	return _pending_reactions.size()

## Drain pending reactions inline during effect execution.
## Used by BasicAttackEffect to process on_before_attack defensive abilities
## BEFORE damage is calculated. This ensures Defensive Stance HP boost happens first.
## Events are stored in _inline_events for the outer loop to collect.
## @param start_index: int - Only process reactions at index >= start_index (reactions added after this point)
func drain_pending_reactions_inline(start_index: int) -> void:
	# Only process reactions that were added AFTER start_index
	# This prevents processing unrelated reactions (like on_ally_death) that were already queued
	if start_index >= _pending_reactions.size():
		return # No new reactions to process
	
	# Extract only the new reactions (from start_index to end)
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	# Remove the processed reactions from the queue (keep earlier ones)
	_pending_reactions.resize(start_index)
	
	# Sort by priority before processing
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	for request in reactions_to_process:
		# Capture events to _inline_events so they can be collected by the outer loop
		# IMPORTANT: Pass a special death_tracking that disables death checking
		# The outer loop will handle death checking properly - we're only processing pre-attack heals here
		# which don't cause deaths, and any existing dead units were already processed
		_resolve_single_effect_request(request, _inline_events, {"__skip_death_triggers__": true})

## Collect any events generated during inline reaction processing (e.g., on_before_attack)
## Called by the outer resolution loop to insert these before damage events.
func collect_inline_events() -> Array[CombatEvent]:
	var events = _inline_events.duplicate()
	_inline_events.clear()
	return events

## Get an instance by UUID.
## @param uuid: String - The UUID of the instance
## @return GachaBallInstance - The instance, or null if not found
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid, null)

## Get the Hero's UUID (player's unit at slot 0, or first available player unit).
func get_hero_uuid() -> String:
	var player_lineup = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	if is_instance_valid(player_lineup):
		var hero_uuid = player_lineup.get_uuid(0)
		if not hero_uuid.is_empty():
			return hero_uuid
		
		# Fallback: find first non-empty slot in player lineup
		for i in range(player_lineup.get_size()):
			var uuid = player_lineup.get_uuid(i)
			if not uuid.is_empty():
				return uuid
	return ""

## Check if a unit is on the player's side.
## @param instance: GachaBallInstance - The instance to check
## @return bool - True if the unit is on the player's side
func _is_player_unit(instance: GachaBallInstance) -> bool:
	return instance.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or instance.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH

func _is_in_player_container_tag(tag: StringName) -> bool:
	if tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
		return true
	if tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
		return true
	if tag == BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
		return true
	if tag == BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
		return true
	var tag_str := String(tag)
	return tag_str.begins_with("BattleInventoryT")

func _is_player_owned(instance: GachaBallInstance) -> bool:
	if not is_instance_valid(instance):
		return false
	var def = instance.get_definition()
	if not is_instance_valid(def):
		return false
	match def.category:
		&"UNIT":
			return _is_in_player_container_tag(instance.location_container_tag)
		&"ITEM":
			if not instance.equipped_on_uuid.is_empty():
				var holder := get_instance(instance.equipped_on_uuid)
				if is_instance_valid(holder):
					return _is_player_unit(holder)
				return false
			return _is_in_player_container_tag(instance.location_container_tag)
		_:
			return false

## Get the ally unit behind the source unit.
## @param source_instance: GachaBallInstance - The source unit
## @return GachaBallInstance - The ally behind, or null if none
func _get_definition_display_name(definition: Resource) -> String:
	if not is_instance_valid(definition):
		return ""
	if "display_name_key" in definition:
		return tr(definition.display_name_key)
	if "name_key" in definition:
		return tr(definition.name_key)
	if "name" in definition:
		return tr(definition.name)
	if "id" in definition:
		return String(definition.id)
	return ""

func _get_instance_display_name(inst: GachaBallInstance) -> String:
	if not is_instance_valid(inst):
		return ""
	var definition = inst.get_definition()
	return _get_definition_display_name(definition)

func _get_ally_behind(source_instance: GachaBallInstance) -> GachaBallInstance:
	if not is_instance_valid(source_instance):
		return null
	var container_name = source_instance.location_container_tag
	var container = get_container(container_name)
	if not is_instance_valid(container):
		return null
	
	var source_index = container.get_index_of_uuid(source_instance.ball_uuid)
	if source_index == -1:
		return null
	
	var behind_index = source_index - 1
	if behind_index >= 0:
		var behind_uuid = container.get_uuid(behind_index)
		if not behind_uuid.is_empty():
			var inst = get_instance_by_uuid(behind_uuid)
			if is_instance_valid(inst) and inst.current_hp > 0:
				return inst
	
	return null

## Get the slot ahead of the source unit.
## @param source_instance: GachaBallInstance - The source unit
## @return GachaBallInstance - The unit ahead, or null if empty
func _get_slot_ahead(source_instance: GachaBallInstance) -> GachaBallInstance:
	var container_name = source_instance.location_container_tag
	var container = get_container(container_name)
	if not is_instance_valid(container):
		return null
	
	var source_index = container.get_index_of_uuid(source_instance.ball_uuid)
	if source_index == -1:
		return null
	
	var ahead_index = source_index + 1
	if ahead_index < container.get_all_uuids().size():
		var ahead_uuid = container.get_uuid(ahead_index)
		if not ahead_uuid.is_empty():
			var inst = get_instance_by_uuid(ahead_uuid)
			if is_instance_valid(inst) and inst.current_hp > 0:
				return inst
	
	return null

## Get adjacent allies (front and back).
## @param source_instance: GachaBallInstance - The source unit
## @return Array[GachaBallInstance] - Array of adjacent allies
func _get_adjacent_allies(source_instance: GachaBallInstance) -> Array[GachaBallInstance]:
	var adjacent: Array[GachaBallInstance] = []
	
	var ally_behind = _get_ally_behind(source_instance)
	if is_instance_valid(ally_behind):
		adjacent.append(ally_behind)
	
	var ally_ahead = _get_slot_ahead(source_instance)
	if is_instance_valid(ally_ahead):
		adjacent.append(ally_ahead)
	
	return adjacent

## Trigger on_hurt event for a unit that took damage.
## @param target_uuid: String - The UUID of the unit that took damage
## @param damage_amount: int - The amount of damage taken
## @param attacker_uuid: String - The UUID of the unit that caused the damage
## Apply a stat change to an instance and return the new value.
## This is the SINGLE modification point for all stat changes (HP, PWR, status effects).
## Ensures snapshots are always captured post-change for VCR pattern.
## @param instance: GachaBallInstance to modify
## @param stat_type: String - "hp", "pwr", "burn_stacks", etc.
## @param delta: int - Amount to change (positive or negative)
## @return Variant - New value after change, or null if operation was skipped (e.g., damage to dead unit)
func apply_stat_delta(instance: GachaBallInstance, stat_type: String, delta: int) -> Variant:
	assert(is_instance_valid(instance), "apply_stat_delta: instance is null")
	
	# CRITICAL: Reject damage to already-dead units
	# This is the "Validate Before Apply" pattern - ensures ghost attacks are impossible
	# Heals and buffs still apply normally (they won't resurrect without explicit resurrection logic)
	if stat_type == "hp" and delta < 0 and instance.current_hp <= 0:
		return null # Signal to caller: operation skipped - target already dead
	
	# CRITICAL: Use SILENT methods during simulation to prevent UI coupling
	# The BattleAnimator handles all visual updates during COMBAT phase
	match stat_type:
		"hp":
			var new_hp = instance.current_hp + delta
			instance.set_current_hp_silent(new_hp) # Silent during simulation
			return new_hp
		"pwr":
			var new_pwr = instance.current_pwr + delta
			instance.set_current_pwr_silent(new_pwr) # Silent during simulation
			return new_pwr
		"burn_stacks":
			# Status effects use add_status_effect_silent internally
			instance.add_status_effect_silent(&"burn", delta) # Silent during simulation
			return instance.status_effects.get(&"burn", 0)
		_:
			# Generic status effect pattern: "effect_name_stacks"
			if stat_type.ends_with("_stacks"):
				var effect_name = stat_type.trim_suffix("_stacks")
				instance.add_status_effect_silent(StringName(effect_name), delta) # Silent
				return instance.status_effects.get(StringName(effect_name), 0)
			else:
				push_error("Unknown stat type: %s" % stat_type)
				return 0

func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String) -> void:
	# Get target instance data for context (effects should not query instances directly)
	var target_instance = get_instance_by_uuid(target_uuid)
	var victim_team := ""
	var victim_current_hp := 0
	if is_instance_valid(target_instance):
		victim_current_hp = target_instance.current_hp
		if target_instance.location_container_tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
			victim_team = "PLAYER"
		elif target_instance.location_container_tag == BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			victim_team = "ENEMY"
	
	# Semantic context keys: victim_uuid = the damaged unit
	var hurt_context: Dictionary = {
		"victim_uuid": target_uuid,
		"damage_taken": damage_amount,
		"attacker_uuid": attacker_uuid,
		"victim_team": victim_team,
		"victim_current_hp": victim_current_hp
	}
	AbilityResolver.process_trigger(&"on_hurt", hurt_context)

## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	# Semantic context keys: attacker_uuid = the killer
	var kill_context: Dictionary = {
		"attacker_uuid": killer_uuid,
		"killed_uuid": killed_uuid
	}
	AbilityResolver.process_trigger(&"on_kill", kill_context)

## Trigger on_battle_start abilities for all units.
func _trigger_battle_start_abilities() -> void:
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in all_units:
		var battle_start_context: Dictionary = {"source_uuid": unit.ball_uuid}
		AbilityResolver.process_trigger(&"on_battle_start", battle_start_context)

## Trigger on_turn_start abilities for all units and trinkets.
func _trigger_turn_start_abilities() -> void:
	if _turn_start_abilities_triggered:
		return
		
	_turn_start_abilities_triggered = true # Set flag here to prevent multiple calls
	
	# Trigger turn start abilities for all instances using unified processing
	var turn_start_context: Dictionary = {"turn": _current_turn}
	AbilityResolver.process_trigger(&"on_turn_start", turn_start_context)
	
	# Process turn start effects (heals, etc.) without starting combat
	# Don't populate actor queue - we're just processing turn start abilities
	if not _pending_reactions.is_empty():
		_resolve_pending_reactions_only()
	else:
		# No turn start abilities to process - transition to MANAGEMENT directly
		_on_turn_animation_finished()


## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
func _resolve_pending_reactions_only() -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	
	# Process only pending reactions (turn start abilities), don't populate actor queue
	var all_events_for_animator: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot BEFORE simulation
	var start_snapshot = get_board_snapshot()
	
	# Process all pending reactions (turn start abilities)
	while not _pending_reactions.is_empty():
		var request: EffectRequest = _pending_reactions.pop_front()
		var reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(request, reaction_events, death_tracking)
		all_events_for_animator.append_array(reaction_events)
	
	# Clean up deferred enemy instances AFTER all reactions have resolved
	_flush_deferred_enemy_erasures()
	
	_is_processing_effect = false
	if not all_events_for_animator.is_empty():
		_animator.play_turn_sequence(start_snapshot, all_events_for_animator)
	else:
		_on_turn_animation_finished()

## Flush deferred enemy instance erasures. Called after all reactions have resolved.
## This ensures enemy units and items are still available in _battle_instances while
## their on_death abilities are being processed.
func _flush_deferred_enemy_erasures() -> void:
	if not has_meta("_deferred_enemy_erasures"):
		return
	var erasure_list: Array = get_meta("_deferred_enemy_erasures")
	for uuid in erasure_list:
		if _battle_instances.has(uuid):
			_battle_instances.erase(uuid)
	remove_meta("_deferred_enemy_erasures")

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities() -> void:
	# print("DEBUG: _trigger_turn_end_abilities called")
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var all_events: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture board snapshot for animation
	var start_snapshot = get_board_snapshot()
	
	# 1. Process Status Effects (Burn)
	# We inline the logic here to combine events into a single animation sequence
	# print("DEBUG: Processing status effects for ", all_units.size(), " units")
	for unit in all_units:
		if unit.current_hp <= 0: continue # Skip dead units
		var burn_stacks = unit.get_status_effect_amount(&"burn")
		if burn_stacks > 0:
			var damage = burn_stacks
			var old_hp = unit.current_hp # Capture BEFORE
			# Apply HP delta via centralized function
			var new_hp = apply_stat_delta(unit, "hp", -damage)
			var max_hp = 0
			var unit_def = unit.get_definition()
			if is_instance_valid(unit_def):
				max_hp = unit_def.base_hp
			
			var unit_name = _get_instance_display_name(unit)
			all_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s takes %d burn dmg" % [unit_name, damage]}))
			all_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": - damage,
					"stat": "hp",
					"skip_bump": true,
					"is_burn_damage": true,
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp]
				}
			}))
			
			var new_stacks = floor(burn_stacks / 2.0)
			var old_stacks = burn_stacks
			if new_stacks > 0:
				# Apply burn decay via centralized function
				var decay_delta = new_stacks - burn_stacks # Negative delta
				apply_stat_delta(unit, "burn_stacks", decay_delta)
			else:
				unit.clear_status_effect(&"burn")
				new_stacks = 0
			
			# Emit BUFF event for burn decay so animator updates the visual
			all_events.append(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": "",
				"target_uuids": [unit.ball_uuid],
				"visual_payload": {
					"amount": int(new_stacks) - int(old_stacks), # Negative = decay
					"stat": "burn_stacks",
					"new_val": int(new_stacks) # Key name matches BuffAnimation
				}
			}))
				
			if unit.current_hp <= 0:
				# Use unified death registry to prevent duplicate processing
				if not _register_death(unit, &"END_OF_TURN"):
					continue # Already died earlier this turn (e.g., in COMBAT phase)
				
				_create_death_event_if_needed(unit.ball_uuid, all_events, death_tracking)
				
				# Track first-killed for resurrection (must happen before on_death triggers)
				var is_player_unit = _is_player_unit(unit)
				var first_killed_key := "first_killed_player_unit" if is_player_unit else "first_killed_enemy_unit"
				if not _turn_metadata.has(first_killed_key):
					var unit_def_fk = unit.get_definition()
					if is_instance_valid(unit_def_fk) and not unit_def_fk.is_hero:
						var loc_snapshot = get_location_for_uuid(unit.ball_uuid)
						if is_instance_valid(loc_snapshot):
							_turn_metadata[first_killed_key] = {
								"def_id": unit.definition_id,
								"team": "PLAYER" if is_player_unit else "ENEMY",
								"location_snapshot": loc_snapshot
							}
				
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = get_location_for_uuid(unit.ball_uuid)
				var death_team = "PLAYER" if is_player_unit else "ENEMY"
				var death_context = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": death_team,
					"dying_location": death_location,
					"equipped_items": _snapshot_equipped_items(unit)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context := {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": death_team
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
				# Process any reactions generated by on_death (like Soul Echo summons)
				while not _pending_reactions.is_empty():
					_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
					var death_reaction = _pending_reactions.pop_front()
					var death_reaction_events: Array[CombatEvent] = []
					_resolve_single_effect_request(death_reaction, death_reaction_events, death_tracking)
					all_events.append_array(death_reaction_events)

	# 2. Process on_turn_end triggers
	# print("DEBUG: Processing on_turn_end triggers")
	# 2. Process on_turn_end triggers
	# print("DEBUG: Processing on_turn_end triggers")
	# Call once globally; AbilityResolver iterates all units
	AbilityResolver.process_trigger(&"on_turn_end", {})
	
	# 3. Resolve pending reactions from on_turn_end
	# print("DEBUG: Resolving ", _pending_reactions.size(), " pending reactions")
	while not _pending_reactions.is_empty():
		var request: EffectRequest = _pending_reactions.pop_front()
		var reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(request, reaction_events, death_tracking)
		all_events.append_array(reaction_events)
	
	# 4. Play animations or finish immediately
	if not all_events.is_empty():
		_is_processing_effect = true
		_resolve_animator()
		_animator.play_turn_sequence(start_snapshot, all_events)
	else:
		# No events to animate, proceed immediately
		_on_turn_animation_finished()


# Deprecated: Logic moved into _trigger_turn_end_abilities
func _process_turn_end_status_effects() -> void:
	pass

func _reshuffle_discard_pile(tier_to_reshuffle: int) -> void:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container): return
	var all_discarded = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var instances_to_move: Array[GachaBallInstance] = []
	for inst in all_discarded:
		var inst_def = inst.get_definition()
		if (inst_def is GachaBallDefinition) and inst_def.tier == tier_to_reshuffle and _is_player_owned(inst):
			instances_to_move.append(inst)
	if instances_to_move.is_empty(): return
	for instance in instances_to_move:
		# Restore stats to base values before moving back to draw pool
		instance.reset_battle_stats()
		
		_remove_instance_from_container(instance)
		var new_index = dest_container.find_first_empty_slot()
		if new_index == -1: new_index = dest_container.get_all_uuids().size()
		dest_container.set_uuid(new_index, instance.ball_uuid)
		_update_instance_location(instance.ball_uuid, dest_container_tag, new_index)


func _get_frontmost_target(attacker_is_player: bool) -> GachaBallInstance:
	var target_lineup_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if attacker_is_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var living_targets = get_instances_in_container(target_lineup_tag).filter(func(unit): return unit.current_hp > 0)
	if living_targets.is_empty(): return null
	
	# Sort by location index to ensure consistent targeting
	living_targets.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	
	# Player attacks from left to right (0 to n), enemies from right to left (n to 0)
	return living_targets[0] if attacker_is_player else living_targets[-1]

func _on_end_turn_requested() -> void:
	if _current_battle_phase == Phases.MANAGEMENT:
		_change_phase(Phases.COMBAT)
		call_deferred("_resolve_combat_phase")
	else:
		pass

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	# CRITICAL: Do not recalculate stats during COMBAT phase
	# This would emit unit_stats_changed which triggers SlotView updates, destroying registered views
	if _current_battle_phase == Phases.COMBAT:
		return
	
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int) -> void:
	print("[DEBUG] _on_draw_gacha_requested called for tier %d, current phase: %s" % [tier, _current_battle_phase])
	# Delegate to atomic composite; preserves legacy signal order
	# Ignore draw intents during COMBAT to enforce strict input blocking.
	if _current_battle_phase != Phases.MANAGEMENT:
		print("[DEBUG] Not in MANAGEMENT phase, ignoring draw request")
		return
	bm_draw_gacha_instance(tier)

# Helper function to equip an item on a unit
func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
	var empty_slot_idx: int = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
		item_instance.equipped_on_uuid = unit_instance.ball_uuid
		item_instance.equipped_slot_index = empty_slot_idx
		
		# Apply the item's stat bonuses to the unit
		unit_instance.equip_item_bonus(item_instance)


func _emit_stats_changed_for_equipped_units() -> void:
	# Emit unit_stats_changed for all units that have equipped items
	for instance in _battle_instances.values():
		if is_instance_valid(instance) and instance.get_definition().category == &"UNIT":
			var has_equipped_items = false
			var equipped_count = 0
			for item_uuid in instance.equipped_item_uuids:
				if not item_uuid.is_empty():
					has_equipped_items = true
					equipped_count += 1
			if has_equipped_items:
				SignalBus.emit_signal("unit_stats_changed", instance.ball_uuid)

func _on_flashcard_completed(results: Dictionary) -> void:
	print("[DEBUG] _on_flashcard_completed called with results: ", results)
	# TDD Section 9.4: Battle Flow
	# This handler is only for the battle context.
	# BattleManager only exists during battle, so we don't need to check is_in_battle.
	# Force close any lingering FlashcardMinigame window to prevent freeze.
	# This acts as a failsafe if WindowManager.open_modal_window() fails to close it.
	var minigame = get_tree().get_root().find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame):
		minigame.queue_free()

	_last_minigame_results = results

	var correct_answers: int = results.get("correct_answers", 0)
	var gacha_gain = 5 + correct_answers # TDD: gacha_gain = 5 (base) + results.correct_answers
	
	print("[DEBUG] Opening ResultsPopup modal")
	# Display ResultsPopup
	WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Turn Start!", "You earned %d Gacha Tokens." % correct_answers, "Okay"]
	})

func _on_results_acknowledged() -> void:
	print("[DEBUG] _on_results_acknowledged called. Current phase: ", get_current_phase_name())
	"""Called when player acknowledges the results popup"""
	
	var correct_answers: int = _last_minigame_results.get("correct_answers", 0)
	var gacha_gain = correct_answers
	
	_gacha_tokens += gacha_gain
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	_last_minigame_results.clear()
	
	SignalBus.emit_signal("close_modal_requested")
	
	# Trigger turn start abilities AFTER mini-game completion
	if not _turn_start_abilities_triggered:
		_trigger_turn_start_abilities()
		# Don't transition to MANAGEMENT yet - let abilities execute and animate first
		# _on_turn_animation_finished() will transition to MANAGEMENT after animations complete
	else:
		# No abilities to execute, go directly to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)


# ------------------------------------------------------------------
# Polymorphic Adapter API (Matches RunState interface)
# ------------------------------------------------------------------

func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	return bm_add_instance(instance, container_name, index)

func remove_instance(uuid: String) -> bool:
	return bm_remove_instance(uuid)

func move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	return bm_move_instance(source_loc, target_loc)

func swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	return bm_swap_instances(source_loc, target_loc)

func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	return bm_equip_item(item_uuid, unit_uuid, slot_index)
func _has_team_trinket(is_player_team: bool, trinket_id: StringName) -> bool:
	var container_tag = BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
	var trinkets = get_instances_in_container(container_tag)
	for trinket in trinkets:
		if trinket.definition_id == trinket_id:
			return true
	return false

## Find a Guardian Sentinel unit on the specified team that can intercept lethal damage.
## Returns the Guardian with highest HP, or null if none available.
## Guardian Sacrifice ability: intercepts lethal damage to allies.
func _find_guardian_on_team(is_player_team: bool, exclude_uuid: String) -> GachaBallInstance:
	var lineup_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var units = get_instances_in_container(lineup_tag)
	
	var best_guardian: GachaBallInstance = null
	for unit in units:
		# Skip the unit that would receive the original damage
		if unit.ball_uuid == exclude_uuid:
			continue
		# Skip dead units
		if unit.current_hp <= 0:
			continue
		
		# Check if unit has Guardian Sacrifice ability
		var def = unit.get_definition()
		if not is_instance_valid(def):
			continue
		
		var has_guardian_ability := false
		for ability in def.ability_definitions:
			if ability.id == &"unit_tier3b_guardian_sacrifice":
				has_guardian_ability = true
				break
		
		if has_guardian_ability:
			if best_guardian == null or unit.current_hp > best_guardian.current_hp:
				best_guardian = unit
	
	return best_guardian

func _finalize_deaths() -> void:
	# Removes units with <= 0 HP from containers and discard, WITHOUT triggering abilities.
	# This is called after VCR playback to synchronize logical state with visual state.
	print("[DEBUG] _finalize_deaths called. Current phase: ", get_current_phase_name())
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	print("[DEBUG] Found ", all_units.size(), " units in lineups")
	var something_changed = false
	
	for unit in all_units:
		print("[DEBUG] Checking unit ", unit.ball_uuid, " HP: ", unit.current_hp, " already_dead: ", is_dead_this_turn(unit.ball_uuid))
		if unit.current_hp <= 0 and is_dead_this_turn(unit.ball_uuid):
			something_changed = true
			# Use unified cleanup logic which handles:
			# 1. Item cleanup (move to discard or destroy)
			# 2. Stat reset (for player units) - CRITICAL FIX
			# 3. Unit removal/move to discard
			_perform_unit_death_cleanup(unit)
	
	if something_changed:
		_emit_battle_inventory_changed()

# =============================================================================
# TEST MODE HELPERS
# These functions ensure test mode uses the same initialization paths as real battles.
# =============================================================================

## Register a unit for test mode using the same logic as _setup_enemy_lineup().
## Guarantees 100% parity with real battle initialization.
## @param unit_def_id: StringName - The ID of the unit definition
## @param is_enemy: bool - True for enemy team, false for player team
## @param position: int - Slot position (0-4), or -1 for auto-placement
## @return GachaBallInstance - The created instance, or null on failure
func register_test_unit(unit_def_id: StringName, is_enemy: bool, position: int = -1) -> GachaBallInstance:
	var unit_def = Database.get_definition(unit_def_id)
	if not is_instance_valid(unit_def):
		push_warning("[TestMode] Unit definition not found: %s" % unit_def_id)
		return null
	
	var container_tag = BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_enemy else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var lineup_container: DataContainer = get_container(container_tag)
	
	# Find position if not specified
	var slot := position
	if slot < 0:
		slot = lineup_container.find_first_empty_slot()
		if slot == -1:
			push_warning("[TestMode] No empty slots in lineup")
			return null
	
	# Create instance EXACTLY like _setup_enemy_lineup does
	var unit_inst = GachaBallInstance.new()
	unit_inst.initialize(unit_def)
	_battle_instances[unit_inst.ball_uuid] = unit_inst
	
	# Place in container EXACTLY like _setup_enemy_lineup does
	lineup_container.set_uuid(slot, unit_inst.ball_uuid)
	_update_instance_location(unit_inst.ball_uuid, container_tag, slot)
	
	print("[TestMode] Registered unit: %s at %s slot %d" % [unit_def_id, container_tag, slot])
	return unit_inst

## Equip an item on a unit using the same logic as real battles.
## Uses _perform_equip() to guarantee parity.
## @param item_def_id: StringName - The ID of the item definition
## @param unit_uuid: String - UUID of the unit to equip on
## @return GachaBallInstance - The created item instance, or null on failure
func register_test_item_on_unit(item_def_id: StringName, unit_uuid: String) -> GachaBallInstance:
	var item_def = Database.get_definition(item_def_id)
	if not is_instance_valid(item_def):
		push_warning("[TestMode] Item definition not found: %s" % item_def_id)
		return null
	
	var unit = get_instance(unit_uuid)
	if not is_instance_valid(unit):
		push_warning("[TestMode] Unit not found: %s" % unit_uuid)
		return null
	
	# Check for empty equipment slot
	if not unit.equipped_item_uuids.has(""):
		push_warning("[TestMode] Unit %s has no empty equipment slots" % unit_uuid)
		return null
	
	# Create and equip item EXACTLY like _setup_enemy_lineup does
	var item_inst = GachaBallInstance.new()
	item_inst.initialize(item_def)
	_battle_instances[item_inst.ball_uuid] = item_inst
	
	# Use existing _perform_equip for proper stat application
	_perform_equip(item_inst, unit)
	
	print("[TestMode] Equipped item: %s on unit: %s" % [item_def_id, unit_uuid])
	return item_inst

## Register a trinket for test mode using the same logic as _setup_enemy_trinkets_from_encounter().
## @param trinket_def_id: StringName - The ID of the trinket definition
## @param is_enemy: bool - True for enemy team, false for player team
## @return GachaBallInstance - The created instance, or null on failure
func register_test_trinket(trinket_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	var trinket_def = Database.get_definition(trinket_def_id)
	if not is_instance_valid(trinket_def):
		push_warning("[TestMode] Trinket definition not found: %s" % trinket_def_id)
		return null
	
	var container_tag = BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS if is_enemy else BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS
	var trinket_container: DataContainer = get_container(container_tag)
	
	# Find empty slot
	var slot := trinket_container.find_first_empty_slot()
	if slot == -1:
		push_warning("[TestMode] No empty trinket slots for team: %s" % ("enemy" if is_enemy else "player"))
		return null
	
	# Create instance EXACTLY like _setup_enemy_trinkets_from_encounter does
	var trinket_inst = GachaBallInstance.new()
	trinket_inst.initialize_from_trinket(trinket_def)
	_battle_instances[trinket_inst.ball_uuid] = trinket_inst
	
	# Place in container
	trinket_container.set_uuid(slot, trinket_inst.ball_uuid)
	_update_instance_location(trinket_inst.ball_uuid, container_tag, slot)
	
	# For enemy trinkets, also add to legacy array
	if is_enemy:
		enemy_trinkets.append(trinket_inst)
	
	print("[TestMode] Registered trinket: %s for %s at slot %d" % [trinket_def_id, "enemy" if is_enemy else "player", slot])
	return trinket_inst

## Trigger on_battle_start abilities for all units currently on the board.
## Call this after setting up your test entities.
func trigger_test_battle_start() -> void:
	print("[TestMode] Triggering on_battle_start for all units...")
	_trigger_battle_start_abilities()
	call_deferred("_emit_stats_changed_for_equipped_units")
	_emit_battle_inventory_changed()
	print("[TestMode] Battle start trigger complete")

## Clear all entities for a specific team. Used to reset before re-applying test setup.
## @param is_enemy: bool - True to clear enemy team, false to clear player team
func clear_test_team(is_enemy: bool) -> void:
	if is_enemy:
		# Clear enemy lineup
		var enemy_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		for i in range(5):
			var uuid = enemy_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = get_instance(uuid)
				if is_instance_valid(inst):
					# Remove equipped items from registry
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							_battle_instances.erase(item_uuid)
					_battle_instances.erase(uuid)
				enemy_container.set_uuid(i, "")
		
		# Clear enemy trinkets
		enemy_trinkets.clear()
		var trinket_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				_battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared enemy team")
	else:
		# Clear player lineup (excluding hero at position 0)
		var player_container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		for i in range(1, 5): # Skip hero at position 0
			var uuid = player_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = get_instance(uuid)
				if is_instance_valid(inst):
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							_battle_instances.erase(item_uuid)
					_battle_instances.erase(uuid)
				player_container.set_uuid(i, "")
		
		# Clear player trinkets
		var trinket_container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				_battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared player team (kept hero)")
	
	_emit_battle_inventory_changed()
