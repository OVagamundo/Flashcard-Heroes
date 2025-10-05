class_name BattleManager
extends Node

const RS = preload("res://scripts/RunState.gd")
enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

var _actor_queue: Array[GachaBallInstance] = []  # Dynamic list of units to act this turn
var _pending_reactions: Array[EffectRequest] = []  # New priority-driven queue
var _is_processing_effect: bool = false
var _battle_over_deferred: bool = false
var _battle_over_emitted: bool = false

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
	_change_phase(Phases.MANAGEMENT)
	_connect_signals()
	# Connect to flashcard completion signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)
	_resolve_animator()
	if is_instance_valid(_animator) and not _animator.turn_animation_finished.is_connected(_on_turn_animation_finished):
		_animator.turn_animation_finished.connect(_on_turn_animation_finished)

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



func start_battle(encounter_def: EncounterDefinition) -> void:
	# Clear any existing selection when entering battle
	SignalBus.emit_signal("selection_clear_requested")
	# Create a fresh battle state with copies of units from run state.
	# IMPORTANT: The battle operates on these copies, leaving the original run state untouched.
	# Any changes to units during battle (HP, stats, etc.) will be discarded when the battle ends.
	_setup_battle(encounter_def)
	GameManager.is_in_battle = true
	SignalBus.emit_signal("battle_state_changed", true)
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Emit unit_stats_changed for all units that have equipped items after UI is populated
	call_deferred("_emit_stats_changed_for_equipped_units")
	
	# Start the first turn with the mini-game
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
	_battle_over_emitted = false
	_battle_over_deferred = false
	_current_turn = 0  # Initialize turn counter
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
	# TODO: When populating enemy_trinkets for this battle, enforce exclusivity by excluding any
	#  definition with is_player_exclusive == true or legacy aliases: PLAYER_ONLY, PLAYER_TRINKET_ONLY,
	#  PLAYER_EXCLUSIVE_TRINKET. Apply this filtering at build time so AbilityResolver never sees
	#  ineligible enemy trinkets.
	_setup_enemy_lineup(encounter_def)

	# Create a test enemy trinket (Healing Amulet) as per implementation doc Phase 2
	var trinket_def = Database.get_definition(&"trinket_healing_amulet")
	if is_instance_valid(trinket_def):
		var trinket_inst = GachaBallInstance.new()
		trinket_inst.initialize_from_trinket(trinket_def)
		_battle_instances[trinket_inst.ball_uuid] = trinket_inst
		var et_container := get_container(BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
		if is_instance_valid(et_container):
			var idx := et_container.find_first_empty_slot()
			if idx == -1:
				idx = 0
			et_container.set_uuid(idx, trinket_inst.ball_uuid)
			_update_instance_location(trinket_inst.ball_uuid, BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, idx)
			enemy_trinkets.append(trinket_inst)

	# Copy player trinkets from run state to battle instances
	_setup_player_trinkets()
	
	# Trigger on_battle_start for all units
	_trigger_battle_start_abilities()

func _setup_enemy_lineup(encounter_def: EncounterDefinition = null) -> void:
	# TODO [Trinkets]: Populate enemy_trinkets here (5 slots, inspection-only). When building the
	#  list, filter out any definitions that are player-exclusive: either is_player_exclusive == true
	#  on the definition or legacy tag aliases in def.tags: PLAYER_ONLY, PLAYER_TRINKET_ONLY,
	#  PLAYER_EXCLUSIVE_TRINKET. In debug, optionally auto-fill with eligible trinkets if empty.
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
		
		for i in range(min(enemy_unit_ids.size(), 6)):
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
			if slot_index < 5:  # Player trinkets container has 5 slots
				battle_trinkets_container.set_uuid(slot_index, battle_trinket.ball_uuid)
				_update_instance_location(battle_trinket.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, slot_index)
				slot_index += 1

func get_container(container_name: StringName) -> DataContainer:
	if _containers.has(container_name):
		return _containers[container_name]

	var new_container: DataContainer

	match container_name:
		BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			new_container = FixedArrayContainer.new(6)
		BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
			new_container = FixedArrayContainer.new(6)
		BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
			new_container = FixedArrayContainer.new(12)
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
	if not is_instance_valid(instance):
		return false
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func _reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container):
		return false
	var instances_to_move = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).filter(
		func(inst): 
			var inst_def = inst.get_definition()
			return (inst_def is GachaBallDefinition) and inst_def.tier == tier_to_reshuffle and _is_player_owned(inst)
	)
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
	if uuid.is_empty():
		return false
	var instance := get_instance(uuid)
	if not is_instance_valid(instance):
		return false
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
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
		SignalBus.emit_signal("battle_inventory_changed")
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
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
		SignalBus.emit_signal("battle_inventory_changed")
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
		SignalBus.emit_signal("battle_inventory_changed")
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	if item_uuid.is_empty() or unit_uuid.is_empty():
		return false
	var item := get_instance(item_uuid)
	var unit := get_instance(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return false
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Composite atomic mutation API (Battle)
# ------------------------------------------------------------------

func bm_move_instance_to_discard(uuid: String) -> bool:
	if uuid.is_empty():
		return false
	var instance := get_instance(uuid)
	if not is_instance_valid(instance):
		return false
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return false
	# Ownership gate: only player-owned instances can enter the player's discard pile
	if not _is_player_owned(instance):
		return false
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
	SignalBus.emit_signal("battle_inventory_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_reshuffle_discard_pile(tier_to_reshuffle: int) -> bool:
	var moved := _reshuffle_tier_from_discard(tier_to_reshuffle)
	if not moved:
		return false
	if OS.is_debug_build():
		_bm_validate_state_consistency()
	SignalBus.emit_signal("battle_inventory_changed")
	# Ensure InventoryWindow grids reflect reshuffled draw pools immediately
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func bm_draw_gacha_instance(tier: int) -> bool:
	var cost := tier
	if _gacha_tokens < cost:
		return false
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := get_instances_in_container(container_tag)
	# If pool is empty, silently reshuffle that tier from discard (single emission at end)
	if tier_pool.is_empty():
		if not _reshuffle_tier_from_discard(tier):
			return false
		tier_pool = get_instances_in_container(container_tag)
		if tier_pool.is_empty():
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
			SignalBus.emit_signal("battle_inventory_changed")
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
	SignalBus.emit_signal("battle_inventory_changed")
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
			occurrences[u] = [{"container": cname, "index": i}]
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
			if is_instance_valid(GameManager.run_state):
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The management phase will be triggered by _on_results_acknowledged
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			SignalBus.emit_signal("battle_inventory_changed")
		Phases.COMBAT:
			pass
		Phases.END_OF_TURN:
			# Fire on_turn_end for all units, then start the next turn (mini-game)
			_trigger_turn_end_abilities()
			_change_phase(Phases.START_OF_TURN)

## Populate the actor queue at the start of combat.
## Preserves asymmetric attack order: players left-to-right, then enemies right-to-left.
## NOTE: Old system used LIFO (pop_back), new system uses FIFO (pop_front) for priority queue.
## To preserve visual order with FIFO:
##   - Players go left-to-right (index 0→5) → add in order
##   - Enemies go right-to-left (index 5→0) → add reversed
func _populate_actor_queue() -> void:
	_actor_queue.clear()
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	# With FIFO (pop_front), first in = first out
	# Add players in normal order (left-to-right execution)
	_actor_queue.append_array(player_lineup)
	# Add enemies reversed (right-to-left execution)
	enemy_lineup.reverse()
	_actor_queue.append_array(enemy_lineup)

## Enqueue an attack (on_attack trigger + basic attack fallback) for a single actor.
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	var target = _get_frontmost_target(is_player)
	if not is_instance_valid(target): return

	var context: Dictionary = {
		"source_uuid": attacker.ball_uuid,
		"target_uuid": target.ball_uuid,
		"target_initial_hp": target.current_hp
	}
	
	# Trigger on_attack abilities (e.g., Double Strike)
	AbilityResolver.process_trigger(&"on_attack", context)
	
	# Always add basic attack
	var basic_attack_def = Database.get_ability_definition(&"basic_attack")
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"basic_attack", basic_attack_def.effects[0], 
			[target.ball_uuid], context, 0  # Priority 0 for basic attack
		)
		enqueue_effect_request(basic_attack_request)

func _resolve_single_effect_request(request: EffectRequest, out_events: Array[CombatEvent], death_tracking: Dictionary = {}) -> void:
	# Validate source is still alive (allow empty source UUID for trinket effects)
	var source = null
	if not request.source_uuid.is_empty():
		source = get_instance_by_uuid(request.source_uuid)
		if not is_instance_valid(source):
			return
		# Only gate dead UNIT sources; allow ITEM/TRINKET sources to execute
		# Exceptions: allow lethal reactive abilities (e.g., counter-attacks, resilient aura) to run post-mortem
		var src_def = source.get_definition()
		if is_instance_valid(src_def) and src_def.category == &"UNIT" and source.current_hp <= 0:
			var ability_id_str := String(request.ability_id)
			var allows_lethal_execution := ability_id_str.contains("counter") or ability_id_str == "unit_tier3d_resilient_aura"
			if not allows_lethal_execution:
				return
	# Prepare execution targets from resolved targets. Only basic attacks may dynamically retarget.
	var exec_targets: Array[String] = []
	exec_targets.append_array(request.resolved_targets)
	var is_basic_attack := (request.ability_id == &"basic_attack")
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
		# Preferred: structured stat change results
		if typeof(res) == TYPE_DICTIONARY:
			var effect_data: Dictionary = res
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
				if amount >= 0:
					var heal_target_name := ""
					if not target_names.is_empty():
						heal_target_name = target_names[0]
					if source_name != "" and heal_target_name != "":
						out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s heals %s for %d HP" % [source_name, heal_target_name, amount]}))
					out_events.append(CombatEvent.new(CombatEvent.Type.HEAL, {"source_uuid": request.source_uuid, "source_name": source_name, "target_uuids": resolved_targets, "target_names": target_names, "amount": amount, "stat": "hp", "skip_bump": skip_bump}))
				else:
					var dealt: int = abs(amount)
					var damage_target_name := ""
					if not target_names.is_empty():
						damage_target_name = target_names[0]
					if source_name != "" and damage_target_name != "":
						out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s deals %d dmg to %s" % [source_name, dealt, damage_target_name]}))
					out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {"source_uuid": request.source_uuid, "source_name": source_name, "target_uuids": resolved_targets, "target_names": target_names, "amount": amount, "stat": "hp", "skip_bump": skip_bump}))
					# Note: DEATH events are deferred until after all reactive abilities are processed
					# This ensures counter-attacks happen before death animations
			elif stat == "pwr" and amount > 0 and not resolved_targets.is_empty():
				for i in range(resolved_targets.size()):
					var single_target_uuid := resolved_targets[i]
					var name_for_target := ""
					if i < target_names.size():
						name_for_target = target_names[i]
					if name_for_target != "":
						out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s gains %d PWR" % [name_for_target, amount]}))
					out_events.append(CombatEvent.new(CombatEvent.Type.STAT_BUFF, {"source_uuid": request.source_uuid, "source_name": source_name, "target_uuids": [single_target_uuid], "target_names": [name_for_target], "amount": amount, "stat": "pwr"}))
			# Legacy: integer damage
		elif typeof(res) == TYPE_INT:
			damage = int(res)
			if exec_targets.size() > 0:
				var src_inst2 = get_instance_by_uuid(request.source_uuid)
				var tgt_inst2 = get_instance_by_uuid(exec_targets[0])
				if is_instance_valid(src_inst2) and is_instance_valid(tgt_inst2):
					var src_name2 = ""
					var src_def2 = src_inst2.get_definition()
					if is_instance_valid(src_def2):
						if "display_name_key" in src_def2:
							src_name2 = tr(src_def2.display_name_key)
						elif "name" in src_def2:
							src_name2 = tr(src_def2.name)
						elif "id" in src_def2:
							src_name2 = String(src_def2.id)
					var tgt_name2 = ""
					var tgt_def2 = tgt_inst2.get_definition()
					if is_instance_valid(tgt_def2):
						if "display_name_key" in tgt_def2:
							tgt_name2 = tr(tgt_def2.display_name_key)
						elif "name" in tgt_def2:
							tgt_name2 = tr(tgt_def2.name)
						elif "id" in tgt_def2:
							tgt_name2 = String(tgt_def2.id)
					out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s deals %d dmg to %s" % [src_name2, damage, tgt_name2]}))
					# Legacy damage: encode as negative amount for consistency
					out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {"source_uuid": request.source_uuid, "target_uuids": [tgt_inst2.ball_uuid], "amount": -damage, "stat": "hp"}))
					# Note: DEATH events are deferred until after all reactive abilities are processed
					# This ensures counter-attacks happen before death animations
		# Apply deaths and enqueue inventory sync if needed
		# Special handling: defer death events for units with counter-attacks to allow final strikes
		_check_for_deaths_with_counter_delay(true, out_events, death_tracking)

## New priority-driven combat phase resolution.
## Uses actor queue with nested reaction loops for cascading effects.
func _resolve_combat_phase() -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	_populate_actor_queue()
	
	var all_events_for_animator: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}  # Shared across all effects in this turn to prevent duplicate death events
	
	# Capture HP snapshot BEFORE simulation so animations can show incremental changes
	var hp_snapshot: Dictionary = {}
	for k in _battle_instances.keys():
		var maybe_inst = _battle_instances.get(k)
		if is_instance_valid(maybe_inst) and maybe_inst.get_definition().category == &"UNIT":
			hp_snapshot[maybe_inst.ball_uuid] = maybe_inst.current_hp
	
	var actor_index = 0
	while not _actor_queue.is_empty():
		var current_actor: GachaBallInstance = _actor_queue.pop_front()
		actor_index += 1
		
		if not is_instance_valid(current_actor):
			continue
		
		var actor_def = current_actor.get_definition()
		var actor_name = tr(actor_def.display_name_key) if "display_name_key" in actor_def else String(actor_def.id)
		
		if current_actor.current_hp <= 0:
			continue

		_enqueue_attack_for(current_actor)
		
		# Reaction loop: process all pending reactions before moving to next actor
		var reaction_count = 0
		while not _pending_reactions.is_empty():
			# Sort by priority (highest first) on every iteration
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var current_reaction = _pending_reactions.pop_front()
			reaction_count += 1
			
			var src_inst = get_instance_by_uuid(current_reaction.source_uuid)
			var src_name = "[Unknown]"
			if is_instance_valid(src_inst) and is_instance_valid(src_inst.get_definition()):
				var src_def = src_inst.get_definition()
				src_name = tr(src_def.display_name_key) if "display_name_key" in src_def else String(src_def.id)
			var tgt_names = []
			for tgt_uuid in current_reaction.resolved_targets:
				var tgt_inst = get_instance_by_uuid(tgt_uuid)
				if is_instance_valid(tgt_inst) and is_instance_valid(tgt_inst.get_definition()):
					var tgt_def = tgt_inst.get_definition()
					tgt_names.append(tr(tgt_def.display_name_key) if "display_name_key" in tgt_def else String(tgt_def.id))
			
			var reaction_events: Array[CombatEvent] = []
			_resolve_single_effect_request(current_reaction, reaction_events, death_tracking)
			
			# Log what happened in this reaction
			for event in reaction_events:
				match event.type:
					CombatEvent.Type.DAMAGE:
						var dmg_amount = abs(event.amount)
						for dmg_tgt_uuid in event.target_uuids:
							var dmg_tgt = get_instance_by_uuid(dmg_tgt_uuid)
							if is_instance_valid(dmg_tgt):
								var dmg_tgt_def = dmg_tgt.get_definition()
								var dmg_tgt_name = tr(dmg_tgt_def.display_name_key) if "display_name_key" in dmg_tgt_def else String(dmg_tgt_def.id)
					CombatEvent.Type.HEAL:
						var heal_amount = event.amount
						for heal_tgt_uuid in event.target_uuids:
							var heal_tgt = get_instance_by_uuid(heal_tgt_uuid)
							if is_instance_valid(heal_tgt):
								var heal_tgt_def = heal_tgt.get_definition()
								var heal_tgt_name = tr(heal_tgt_def.display_name_key) if "display_name_key" in heal_tgt_def else String(heal_tgt_def.id)
					CombatEvent.Type.DEATH:
						for death_tgt_uuid in event.target_uuids:
							var death_tgt = get_instance_by_uuid(death_tgt_uuid)
							if is_instance_valid(death_tgt):
								var death_tgt_def = death_tgt.get_definition()
								var death_tgt_name = tr(death_tgt_def.display_name_key) if "display_name_key" in death_tgt_def else String(death_tgt_def.id)
			
			all_events_for_animator.append_array(reaction_events)
			
			# Process any deferred deaths that can now be finalized (units that died but had counter-attacks)
			# This happens after each reaction so deaths occur immediately after counter-attacks complete
			var deferred_death_events: Array[CombatEvent] = []
			_process_completed_counter_deaths(deferred_death_events, death_tracking)
			all_events_for_animator.append_array(deferred_death_events)

			if _is_battle_over():
				_battle_over_deferred = true
				_pending_reactions.clear()
				_actor_queue.clear()
				break
		
		if _battle_over_deferred:
			break

	_is_processing_effect = false
	if not all_events_for_animator.is_empty():
		# HP snapshot was captured BEFORE simulation, so animations show incremental changes
		_animator.set_hp_snapshot(hp_snapshot)
		_animator.play_turn(all_events_for_animator)
	else:
		_on_turn_animation_finished()
func _on_turn_animation_finished() -> void:
	# This signal is the single source of truth for when animations are complete.
	# It is safe to proceed to the next phase.
	_is_processing_effect = false
	
	if _current_battle_phase == Phases.START_OF_TURN:
		# Turn start abilities finished animating, transition to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)
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
	if not is_instance_valid(instance): return
	# Ownership gate: only player-owned instances can enter the player's discard pile
	if not _is_player_owned(instance): return
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
	if not is_instance_valid(instance): return
	var loc = get_location_for_uuid(instance.ball_uuid)
	if not is_instance_valid(loc): return
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
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {"target_uuids": [unit.ball_uuid]}))
			elif not is_simulation:
				# Trigger on_death for the dying unit
				var death_context: Dictionary = {"source_uuid": unit.ball_uuid}
				AbilityResolver.process_trigger(&"on_death", death_context)
				# Trigger on_ally_death ONLY for other player units (same team)
				var player_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
				for ally in player_allies:
					if ally.ball_uuid != unit.ball_uuid:
						var ally_death_context: Dictionary = {
							"source_uuid": ally.ball_uuid,
							"fainting_ally_uuid": unit.ball_uuid,
							"fainting_ally_location": get_location_for_uuid(unit.ball_uuid)
						}
						AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				# Move equipped items to discard while ownership resolves via equipped parent
				for item_uuid in unit.equipped_item_uuids:
					if not item_uuid.is_empty():
						var item_instance := get_instance(item_uuid)
						if is_instance_valid(item_instance):
							_move_instance_to_discard(item_instance)
				# Clear the unit's slots locally
				unit.equipped_item_uuids.fill("")
				# Move the dead unit itself to discard
				_move_instance_to_discard(unit)
		
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				# This keeps the unit visible for counter-attacks
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {"target_uuids": [unit.ball_uuid]}))
			elif not is_simulation:
				# Trigger on_death for the dying unit
				var death_context2: Dictionary = {"source_uuid": unit.ball_uuid}
				AbilityResolver.process_trigger(&"on_death", death_context2)
				# Trigger on_ally_death ONLY for other enemy units (same team)
				var enemy_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
				for ally in enemy_allies:
					if ally.ball_uuid != unit.ball_uuid:
						var ally_death_context2: Dictionary = {
							"source_uuid": ally.ball_uuid,
							"fainting_ally_uuid": unit.ball_uuid,
							"fainting_ally_location": get_location_for_uuid(unit.ball_uuid)
						}
						AbilityResolver.process_trigger(&"on_ally_death", ally_death_context2)
				# Ensure enemy-equipped items do not outlive their parent.
				for item_uuid in unit.equipped_item_uuids:
					if item_uuid.is_empty():
						continue
					var item_instance2 := get_instance(item_uuid)
					if is_instance_valid(item_instance2):
						# Clear the item's equipped linkage and logical location
						item_instance2.equipped_on_uuid = ""
						item_instance2.equipped_slot_index = -1
						_update_instance_location(item_instance2.ball_uuid, &"", -1)
						# Enemy items are destroyed on parent death; remove from registry
						if _battle_instances.has(item_instance2.ball_uuid):
							_battle_instances.erase(item_instance2.ball_uuid)
				# Clear the enemy unit's local slots
				unit.equipped_item_uuids.fill("")
				_remove_instance_from_container(unit)
				if _battle_instances.has(unit.ball_uuid):
					_battle_instances.erase(unit.ball_uuid)
		
	if something_changed and not is_simulation:
		SignalBus.emit_signal("battle_inventory_changed")

## Check if a unit has counter-attack abilities that could trigger on lethal damage
func _has_lethal_counter_abilities(unit: GachaBallInstance) -> bool:
	if not is_instance_valid(unit):
		return false
	
	var definition = unit.get_definition()
	if not is_instance_valid(definition):
		return false
	
	# Check unit's own abilities for counter-attacks
	for ability in definition.ability_definitions:
		if not is_instance_valid(ability) or ability.trigger != &"on_hurt":
			continue
		if String(ability.id) == "unit_tier3d_resilient_aura":
			return true
		# Check if it's a counter-attack ability (uses ATTACKER target or has "counter" in ID)
		for effect in ability.effects:
			if is_instance_valid(effect) and effect.target_type == C.TARGET_ATTACKER:
				return true
		if ability.id.contains("counter"):
			return true
	
	return false

## Enhanced death checking that defers death events for units with counter-attacks
func _check_for_deaths_with_counter_delay(is_simulation: bool = false, out_events = null, death_tracking = null) -> void:
	var something_changed = false
	var deferred_deaths: Array[String] = []  # Units whose deaths should be deferred
	
	# Check player units
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					var sim_flag_key: String = "death_triggers_emitted_" + unit.ball_uuid
					if not death_tracking.has(sim_flag_key):
						# on_death for the dying unit
						AbilityResolver.process_trigger(&"on_death", {"source_uuid": unit.ball_uuid})
						# on_ally_death for same-team allies
						var player_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
						for ally in player_allies:
							if ally.ball_uuid != unit.ball_uuid:
								var ally_ctx := {
									"source_uuid": ally.ball_uuid,
									"fainting_ally_uuid": unit.ball_uuid,
									"fainting_ally_location": get_location_for_uuid(unit.ball_uuid)
								}
								AbilityResolver.process_trigger(&"on_ally_death", ally_ctx)
						death_tracking[sim_flag_key] = true
				# Check if this unit has counter-attacks that could trigger
				if _has_lethal_counter_abilities(unit):
					# Defer death event for units with counter-attacks
					deferred_deaths.append(unit.ball_uuid)
				else:
					# Immediate death event for units without counter-attacks
					if death_tracking != null:
						_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
					else:
						out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {"target_uuids": [unit.ball_uuid]}))
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				for item_uuid in unit.equipped_item_uuids:
					if not item_uuid.is_empty():
						var item_instance := get_instance(item_uuid)
						if is_instance_valid(item_instance):
							_move_instance_to_discard(item_instance)
				unit.equipped_item_uuids.fill("")
				_move_instance_to_discard(unit)
	
	# Check enemy units (same logic)
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			var unit_def2 = unit.get_definition()
			var unit_name2 = tr(unit_def2.display_name_key) if "display_name_key" in unit_def2 else String(unit_def2.id)
			something_changed = true
			if is_simulation and out_events != null:
				# Emit death-related triggers once during simulation so reactions can resolve
				if death_tracking != null:
					var sim_flag_key2: String = "death_triggers_emitted_" + unit.ball_uuid
					if not death_tracking.has(sim_flag_key2):
						# on_death for the dying unit
						AbilityResolver.process_trigger(&"on_death", {"source_uuid": unit.ball_uuid})
						# on_ally_death for same-team allies (enemy side)
						var enemy_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
						for ally in enemy_allies:
							if ally.ball_uuid != unit.ball_uuid:
								var ally_ctx2 := {
									"source_uuid": ally.ball_uuid,
									"fainting_ally_uuid": unit.ball_uuid,
									"fainting_ally_location": get_location_for_uuid(unit.ball_uuid)
								}
								AbilityResolver.process_trigger(&"on_ally_death", ally_ctx2)
						death_tracking[sim_flag_key2] = true
				if _has_lethal_counter_abilities(unit):
					deferred_deaths.append(unit.ball_uuid)
				else:
					if death_tracking != null:
						_create_death_event_if_needed(unit.ball_uuid, out_events, death_tracking)
					else:
						out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {"target_uuids": [unit.ball_uuid]}))
			elif not is_simulation:
				# Triggers already handled during simulation; perform cleanup only.
				for item_uuid in unit.equipped_item_uuids:
					if item_uuid.is_empty():
						continue
					var item_instance2 := get_instance(item_uuid)
					if is_instance_valid(item_instance2):
						item_instance2.equipped_on_uuid = ""
						item_instance2.equipped_slot_index = -1
						_update_instance_location(item_instance2.ball_uuid, &"", -1)
						if _battle_instances.has(item_instance2.ball_uuid):
							_battle_instances.erase(item_instance2.ball_uuid)
				unit.equipped_item_uuids.fill("")
				_remove_instance_from_container(unit)
				if _battle_instances.has(unit.ball_uuid):
					_battle_instances.erase(unit.ball_uuid)
	
	# Store deferred deaths for processing after their counter-attacks complete
	if not deferred_deaths.is_empty():
		# Store current deferred deaths, merging with any existing ones
		var existing_deferred: Array = get_meta("deferred_deaths", [])
		existing_deferred.append_array(deferred_deaths)
		set_meta("deferred_deaths", existing_deferred)
	
	if something_changed and not is_simulation:
		SignalBus.emit_signal("battle_inventory_changed")

## Helper function to create DEATH events only once per unit
func _create_death_event_if_needed(unit_uuid: String, out_events: Array, death_tracking: Dictionary) -> void:
	if death_tracking.has(unit_uuid):
		return  # Already created death event for this unit
	
	death_tracking[unit_uuid] = true
	out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {"target_uuids": [unit_uuid]}))

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
		
		var unit_def = unit.get_definition()
		var unit_name = tr(unit_def.display_name_key) if "display_name_key" in unit_def else String(unit_def.id)
			
		# Check if this unit still has pending counter-attack abilities in the queue
		var has_pending_counters = false
		for request in _pending_reactions:
			if request.source_uuid == uuid and request.ability_id and str(request.ability_id).contains("counter"):
				has_pending_counters = true
				break
		
		# If no pending counter-attacks, this unit can die now
		if not has_pending_counters:
			if out_events != null and death_tracking != null:
				_create_death_event_if_needed(uuid, out_events, death_tracking)
		else:
			# Still has pending counter-attacks, keep deferred
			remaining_deferred.append(uuid)
	
	# Update the deferred deaths list
	if remaining_deferred.is_empty():
		remove_meta("deferred_deaths")
	else:
		set_meta("deferred_deaths", remaining_deferred)

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
			if _is_in_player_container_tag(unit.location_container_tag):
				# Player unit: move equipped items to discard then move unit to discard
				for item_uuid in unit.equipped_item_uuids:
					if not item_uuid.is_empty():
						var item_instance := get_instance(item_uuid)
						if is_instance_valid(item_instance):
							_move_instance_to_discard(item_instance)
				unit.equipped_item_uuids.fill("")
				_move_instance_to_discard(unit)
			else:
				# Enemy unit: clear equipped linkage and erase items, then remove unit
				for item_uuid2 in unit.equipped_item_uuids:
					if item_uuid2.is_empty():
						continue
					var item2 := get_instance(item_uuid2)
					if is_instance_valid(item2):
						item2.equipped_on_uuid = ""
						item2.equipped_slot_index = -1
						_update_instance_location(item2.ball_uuid, &"", -1)
						if _battle_instances.has(item2.ball_uuid):
							_battle_instances.erase(item2.ball_uuid)
				unit.equipped_item_uuids.fill("")
				_remove_instance_from_container(unit)
				if _battle_instances.has(unit.ball_uuid):
					_battle_instances.erase(unit.ball_uuid)
	# After removals, refresh UI
	SignalBus.emit_signal("battle_inventory_changed")
	# If battle is now over, defer victory to end of animations
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if _current_battle_phase == Phases.COMBAT and _is_battle_over():
		_battle_over_deferred = true

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var over := player_lineup.is_empty() or enemy_lineup.is_empty()
	return over

func _emit_battle_over() -> void:
	# Transition to BATTLE_OVER and emit results once animations are finished.
	_current_battle_phase = Phases.BATTLE_OVER
	if not _battle_over_emitted:
		_battle_over_emitted = true
		SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
		var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		var player_won := not player_lineup.is_empty()
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
			# Return the target from the attack context
			var target_uuid: String = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				return [target_uuid]
			return []
		C.TARGET_TRIGGERING_ENTITY:
			# Return the entity that triggered the event
			var triggering_uuid: String = context.get("triggering_uuid", "")
			if not triggering_uuid.is_empty():
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
			var enemies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			if not enemies.is_empty():
				var random_enemy = enemies[randi() % enemies.size()]
				return [random_enemy.ball_uuid]
			return []
		C.TARGET_RANDOM_ALLY:
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
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
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
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
		return true  # No condition means always true
	
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
			return get_instance_by_uuid(behind_uuid)
	
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
			return get_instance_by_uuid(ahead_uuid)
	
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
func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String) -> void:
	var hurt_context: Dictionary = {
		"source_uuid": target_uuid,
		"damage_taken": damage_amount,
		"attacker_uuid": attacker_uuid
	}
	AbilityResolver.process_trigger(&"on_hurt", hurt_context)

## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String) -> void:
	var kill_context: Dictionary = {
		"source_uuid": killer_uuid,
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
		
	_turn_start_abilities_triggered = true  # Set flag here to prevent multiple calls
	
	# Trigger turn start abilities for all instances using unified processing
	var turn_start_context: Dictionary = {"turn": _current_turn}
	AbilityResolver.process_trigger(&"on_turn_start", turn_start_context)
	
	# Process turn start effects (heals, etc.) without starting combat
	# Don't populate actor queue - we're just processing turn start abilities
	if not _pending_reactions.is_empty():
		_resolve_pending_reactions_only()


## Process pending reactions without populating the actor queue
## Used for turn start abilities that shouldn't trigger combat
func _resolve_pending_reactions_only() -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	
	# Process only pending reactions (turn start abilities), don't populate actor queue
	var all_events_for_animator: Array[CombatEvent] = []
	var death_tracking: Dictionary = {}
	
	# Capture HP snapshot BEFORE simulation
	var hp_snapshot: Dictionary = {}
	for k in _battle_instances.keys():
		var maybe_inst = _battle_instances.get(k)
		if is_instance_valid(maybe_inst) and maybe_inst.get_definition().category == &"UNIT":
			hp_snapshot[maybe_inst.ball_uuid] = maybe_inst.current_hp
	
	# Process all pending reactions (turn start abilities)
	while not _pending_reactions.is_empty():
		var request: EffectRequest = _pending_reactions.pop_front()
		var reaction_events: Array[CombatEvent] = []
		_resolve_single_effect_request(request, reaction_events, death_tracking)
		all_events_for_animator.append_array(reaction_events)
	
	_is_processing_effect = false
	if not all_events_for_animator.is_empty():
		_animator.set_hp_snapshot(hp_snapshot)
		_animator.play_turn(all_events_for_animator)
	else:
		_on_turn_animation_finished()

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities() -> void:
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in all_units:
		var turn_end_context: Dictionary = {"source_uuid": unit.ball_uuid}
		AbilityResolver.process_trigger(&"on_turn_end", turn_end_context)

func _reshuffle_discard_pile(tier_to_reshuffle: int) -> void:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container): return
	var instances_to_move = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).filter(
		func(inst): 
			var inst_def = inst.get_definition()
			return (inst_def is GachaBallDefinition) and inst_def.tier == tier_to_reshuffle and _is_player_owned(inst)
	)
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
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int) -> void:
	# Delegate to atomic composite; preserves legacy signal order
	# Ignore draw intents during COMBAT to enforce strict input blocking.
	if _current_battle_phase != Phases.MANAGEMENT:
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
	# TDD Section 9.4: Battle Flow
	# This handler is only for the battle context.
	if not is_instance_valid(get_node_or_null("/root/Main/VBoxContainer/ContentArea/SubViewport/Battle")):
		return

	_last_minigame_results = results

	var correct_answers: int = results.get("correct_answers", 0)
	var gacha_gain = 5 + correct_answers  # TDD: gacha_gain = 5 (base) + results.correct_answers
	
	# Display ResultsPopup
	var popup = WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Turn Start!", "You earned %d Gacha Tokens." % correct_answers, "Okay"]
	})

func _on_results_acknowledged() -> void:
	"""Called when player acknowledges the results popup"""
	
	var correct_answers: int = _last_minigame_results.get("correct_answers", 0)
	var gacha_gain = correct_answers
	
	_gacha_tokens += gacha_gain
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	_last_minigame_results.clear()
	
	SignalBus.emit_signal("close_modal_requested")
	
	# Trigger turn start abilities AFTER mini-game completion, but only from turn 2 onwards
	if _current_turn >= 2 and not _turn_start_abilities_triggered:
		_trigger_turn_start_abilities()
		# Don't transition to MANAGEMENT yet - let abilities execute and animate first
		# _on_turn_animation_finished() will transition to MANAGEMENT after animations complete
	else:
		# No abilities to execute, go directly to MANAGEMENT
		_change_phase(Phases.MANAGEMENT)
