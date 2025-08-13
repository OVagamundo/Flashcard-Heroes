class_name BattleManager
extends Node

const RS = preload("res://scripts/RunState.gd")

enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

var _effect_queue: Array[EffectRequest] = []
var _is_processing_effect: bool = false
var _battle_over_emitted: bool = false

const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
}

var _battle_instances: Dictionary = {}
var _containers: Dictionary = {}

const FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
const CombatEvent = preload("res://scripts/CombatEvent.gd")
var _gacha_tokens: int = 0
var _last_minigame_results: Dictionary = {}
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
	# Removed legacy reshuffle trigger; draw now reshuffles atomically when needed.



func start_battle(encounter_def: EncounterDefinition) -> void:
	# Clear any existing selection when entering battle
	SignalBus.emit_signal("selection_clear_requested")
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
	_battle_instances.clear()
	_containers.clear()
	_effect_queue.clear()
	_battle_over_emitted = false
	_gacha_tokens = 0
	
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()
	var permanent_to_battle_uuid_map: Dictionary = {}

	# First pass: Create all battle copies and map their new UUIDs, except for the hero (use persistent instance for hero)
	var hero_instance: GachaBallInstance = null
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		if is_hero:
			hero_instance = perm_inst
			# Add the hero instance to _battle_instances so UI can find it during battle
			_battle_instances[perm_inst.ball_uuid] = perm_inst
			continue # Don't create a battle copy for the hero
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
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc): continue
		if is_hero:
			# Place the persistent hero instance directly in the PlayerLineup
			var container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			container.set_uuid(perm_loc.index, perm_inst.ball_uuid)
			_update_instance_location(perm_inst.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, perm_loc.index)
			continue
		var battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid)
		if not battle_uuid: continue
		var battle_copy = _battle_instances[battle_uuid]
		# An item's location is determined by what it's equipped to. Skip direct placement.
		if not battle_copy.equipped_on_uuid.is_empty():
			continue
		var target_container_name: StringName
		if perm_loc.container.begins_with("RunInventoryT"):
			var tier = perm_inst.get_definition().tier
			target_container_name = &"BattleInventoryT%d" % tier
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

	_setup_enemy_lineup(encounter_def)
	
	# Trigger on_battle_start for all units
	_trigger_battle_start_abilities()

func _setup_enemy_lineup(encounter_def: EncounterDefinition = null) -> void:
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
		func(inst): return inst.get_definition().tier == tier_to_reshuffle and _is_player_owned(inst)
	)
	if instances_to_move.is_empty():
		return false
	SignalBus.emit_signal("battle_log_event", "Reshuffling Tier %d discard pile..." % tier_to_reshuffle)
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
			if OS.is_debug_build():
				var sc_all := src_container.get_all_uuids()
				var sc_count := sc_all.count(item_uuid)
				if sc_count != 0:
					print("[BM][WARN] After equip-move source clear, uuid still present count=", sc_count, " in ", source_loc.container, " at src index ", source_loc.index)
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
	if OS.is_debug_build():
		var fa := from_container.get_all_uuids().count(instance.ball_uuid)
		if fa != 0:
			print("[BM][WARN] After move source clear, uuid still present count=", fa, " in ", source_loc.container, " at index ", source_loc.index)
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
		if OS.is_debug_build():
			var aa := a_container.get_all_uuids().count(a.ball_uuid)
			if aa != 0:
				print("[BM][WARN] After swap-degrade source clear, uuid still present count=", aa, " in ", source_loc.container, " at index ", source_loc.index)
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
			var actual := c2.get_uuid(loc.index)
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
			# Grant base 5 tokens for the turn
			_gacha_tokens += 5
			SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			# The flashcard mini-game is the first event of the turn.
			# TDD Section 9.4: Battle Flow
			if is_instance_valid(GameManager.run_state):
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The combat phase will now be triggered by _on_flashcard_completed
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			SignalBus.emit_signal("battle_inventory_changed")
		Phases.COMBAT:
			pass
		Phases.END_OF_TURN:
			pass

func _count_requests_for_source(uuid: String) -> int:
	var c := 0
	for req in _effect_queue:
		if req != null and req.source_uuid == uuid:
			c += 1
	return c

func _populate_effect_queue() -> void:
	_effect_queue.clear()
	
	# Process enemy attacks
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for attacker in enemy_lineup:
		var target = _get_frontmost_target(false)
		if is_instance_valid(target):
			# Trigger on_attack for the enemy unit
			var context: Dictionary = {"source_uuid": attacker.ball_uuid, "target_uuid": target.ball_uuid}
			var before_for_source = _count_requests_for_source(attacker.ball_uuid)
			AbilityResolver.process_trigger(&"on_attack", context)
			
			# If no abilities were queued for this attacker, add default basic attack
			if _count_requests_for_source(attacker.ball_uuid) == before_for_source:
				var basic_attack_effect: EffectDefinition = null
				var basic_attack_def = Database.get_ability_definition(&"basic_attack")
				if is_instance_valid(basic_attack_def):
					var effects_array = basic_attack_def.effects
					if effects_array.size() > 0 and is_instance_valid(effects_array[0]):
						basic_attack_effect = effects_array[0]
				if not is_instance_valid(basic_attack_effect):
					var BasicAttackEffectScript = preload("res://scripts/BasicAttackEffect.gd")
					basic_attack_effect = BasicAttackEffectScript.new()
				if is_instance_valid(basic_attack_effect):
					var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", basic_attack_effect, [target.ball_uuid], context)
					_effect_queue.append(request)
	
	# Process player attacks
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	# Enqueue in reverse so LIFO processing executes left->right for players
	for i in range(player_lineup.size() - 1, -1, -1):
		var attacker = player_lineup[i]
		var target = _get_frontmost_target(true)
		if is_instance_valid(target):
			# Trigger on_attack for the player unit
			var context: Dictionary = {"source_uuid": attacker.ball_uuid, "target_uuid": target.ball_uuid}
			var before_for_source = _count_requests_for_source(attacker.ball_uuid)
			AbilityResolver.process_trigger(&"on_attack", context)
			
			# If no abilities were queued for this attacker, add default basic attack
			if _count_requests_for_source(attacker.ball_uuid) == before_for_source:
				var basic_attack_effect: EffectDefinition = null
				var basic_attack_def = Database.get_ability_definition(&"basic_attack")
				if is_instance_valid(basic_attack_def):
					var effects_array = basic_attack_def.effects
					if effects_array.size() > 0 and is_instance_valid(effects_array[0]):
						basic_attack_effect = effects_array[0]
				if not is_instance_valid(basic_attack_effect):
					var BasicAttackEffectScript = preload("res://scripts/BasicAttackEffect.gd")
					basic_attack_effect = BasicAttackEffectScript.new()
				if is_instance_valid(basic_attack_effect):
					var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", basic_attack_effect, [target.ball_uuid], context)
					_effect_queue.append(request)

func _resolve_single_effect_request(request: EffectRequest, out_events: Array[CombatEvent]) -> void:
	# Validate source is still alive
	var source = get_instance_by_uuid(request.source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return
	# Retarget dynamically if first target is dead or invalid
	var exec_targets: Array[String] = []
	exec_targets.append_array(request.resolved_targets)
	if exec_targets.size() > 0:
		var first_target = get_instance_by_uuid(exec_targets[0])
		var attacker_is_player = _is_player_unit(source)
		if not is_instance_valid(first_target) or first_target.current_hp <= 0:
			var new_target_inst = _get_frontmost_target(attacker_is_player)
			if is_instance_valid(new_target_inst):
				exec_targets[0] = new_target_inst.ball_uuid
			else:
				return
	# Execute without emitting UI; capture basic damage if returned
	var damage := 0
	if is_instance_valid(request.effect_definition):
		var sim_ctx = request.trigger_context.duplicate(true)
		sim_ctx["is_simulation"] = true
		var res = request.effect_definition.execute(request.source_uuid, exec_targets, self, sim_ctx)
		if typeof(res) == TYPE_INT:
			damage = int(res)
			# Construct the same log message as BasicAttackEffect for compatibility
			if exec_targets.size() > 0:
				var src_inst = get_instance_by_uuid(request.source_uuid)
				var tgt_inst = get_instance_by_uuid(exec_targets[0])
				if is_instance_valid(src_inst) and is_instance_valid(tgt_inst):
					var src_name = tr(src_inst.get_definition().display_name_key)
					var tgt_name = tr(tgt_inst.get_definition().display_name_key)
					out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": "%s deals %d dmg to %s" % [src_name, damage, tgt_name]}))
					out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {"target_uuids": [tgt_inst.ball_uuid]}))
	# Apply deaths and enqueue inventory sync if needed
	_check_for_deaths(true, out_events)

func _process_effect_queue() -> void:
	if _is_processing_effect: return
	_is_processing_effect = true
	_resolve_animator()
	# Process one request at a time so data and UI advance in lockstep per unit.
	while not _effect_queue.is_empty():
		var events: Array[CombatEvent] = []
		var request: EffectRequest = _effect_queue.pop_back()
		_resolve_single_effect_request(request, events)

		# Play just this request's events, then continue to the next.
		if is_instance_valid(_animator):
			await _animator.play_turn(events)
		else:
			# Fallback: directly emit events with pacing if animator missing
			for e in events:
				match e.type:
					CombatEvent.Type.LOG_MESSAGE:
						SignalBus.emit_signal("battle_log_event", e.text)
					CombatEvent.Type.DAMAGE:
						if e.target_uuids.size() > 0:
							SignalBus.emit_signal("unit_stats_changed", e.target_uuids[0])
					CombatEvent.Type.INVENTORY_SYNC:
						SignalBus.emit_signal("battle_inventory_changed")
				await get_tree().process_frame
				await get_tree().create_timer(0.8).timeout

		if _is_battle_over():
			break

	_is_processing_effect = false
	_on_turn_animation_finished()

func _on_turn_animation_finished() -> void:
	# If we're mid-processing per-effect animations, ignore intermediate finished signals.
	if _is_processing_effect:
		return
	# Reset processing flag after animations complete
	_is_processing_effect = false
	# After all animations, advance phases unless battle ended
	if _is_battle_over():
		return
	# Trigger end-of-turn abilities and advance
	_trigger_turn_end_abilities()
	_change_phase(Phases.END_OF_TURN)
	await get_tree().create_timer(0.1).timeout
	_change_phase(Phases.START_OF_TURN)

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
			
			# Trigger on_death for the dying unit
			var death_context: Dictionary = {"source_uuid": unit.ball_uuid}
			AbilityResolver.process_trigger(&"on_death", death_context)
			
			# Trigger on_ally_death for all other units
			var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			for ally in all_units:
				if ally.ball_uuid != unit.ball_uuid:
					var ally_death_context: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
					AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
			
			# First move equipped items to discard while ownership still resolves via equipped parent
			for item_uuid in unit.equipped_item_uuids:
				if not item_uuid.is_empty():
					var item_instance := get_instance(item_uuid)
					if is_instance_valid(item_instance):
						_move_instance_to_discard(item_instance)
			# Clear the unit's slots locally (parent mapping was cleared per-item above)
			unit.equipped_item_uuids.fill("")
			# Now move the dead unit itself to discard (removes from lineup and updates location atomically)
			_move_instance_to_discard(unit)
		
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			something_changed = true
			
			# Trigger on_death for the dying unit
			var death_context: Dictionary = {"source_uuid": unit.ball_uuid}
			AbilityResolver.process_trigger(&"on_death", death_context)
			
			# Trigger on_ally_death for all other units
			var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			for ally in all_units:
				if ally.ball_uuid != unit.ball_uuid:
					var ally_death_context: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
					AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
			
			# Ensure enemy-equipped items do not outlive their parent.
			# Clear equipped linkage and erase enemy items from the registry BEFORE removing the unit.
			# This prevents validator errors where items claim a parent that has been erased.
			for item_uuid in unit.equipped_item_uuids:
				if item_uuid.is_empty():
					continue
				var item_instance := get_instance(item_uuid)
				if is_instance_valid(item_instance):
					# Clear the item's equipped linkage and logical location
					item_instance.equipped_on_uuid = ""
					item_instance.equipped_slot_index = -1
					_update_instance_location(item_instance.ball_uuid, &"", -1)
					# Enemy items are destroyed on parent death; remove from registry
					if _battle_instances.has(item_instance.ball_uuid):
						_battle_instances.erase(item_instance.ball_uuid)
			# Clear the enemy unit's local slots (we are about to remove the unit)
			unit.equipped_item_uuids.fill("")
			
			_remove_instance_from_container(unit)
			if _battle_instances.has(unit.ball_uuid):
				_battle_instances.erase(unit.ball_uuid)
		
	if something_changed:
		if is_simulation:
			if out_events != null:
				out_events.append(CombatEvent.new(CombatEvent.Type.INVENTORY_SYNC))
		else:
			SignalBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if player_lineup.is_empty() or enemy_lineup.is_empty():
		_current_battle_phase = Phases.BATTLE_OVER
		if not _battle_over_emitted:
			_battle_over_emitted = true
			SignalBus.emit_signal("battle_phase_changed", get_current_phase_name())
			var player_won := not player_lineup.is_empty()
			var results: Dictionary = {
				"victory": player_won
			}
			SignalBus.emit_signal("battle_ended", results)
		return true
	return false

## Resolve targets for an effect based on target type and context.
## @param source_uuid: String - The UUID of the source instance
## @param target_type: StringName - The type of target to resolve (e.g., "SELF", "FRONTMOST_ENEMY")
## @param context: Dictionary - The context of the event
## @return Array[String] - Array of target UUIDs
func resolve_target(source_uuid: String, target_type: StringName, context: Dictionary) -> Array[String]:
	var source_instance = get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
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
		C.TARGET_FRONTMOST_ENEMY:
			var is_source_player = _is_player_unit(source_instance)
			var target = _get_frontmost_target(!is_source_player)
			if is_instance_valid(target):
				return [target.ball_uuid]
			return []
		C.TARGET_RANDOM_ENEMY:
			var is_source_player = _is_player_unit(source_instance)
			var enemies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			if not enemies.is_empty():
				var random_enemy = enemies[randi() % enemies.size()]
				return [random_enemy.ball_uuid]
			return []
		C.TARGET_RANDOM_ALLY:
			var is_source_player = _is_player_unit(source_instance)
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
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
			var is_source_player = _is_player_unit(source_instance)
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
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
		_:
			result = false
	
	# Apply inversion if specified
	return !result if condition_def.invert_result else result

## Enqueue an effect request for processing.
## @param effect_request: EffectRequest - The effect request to enqueue
func enqueue_effect_request(effect_request: EffectRequest) -> void:
	if is_instance_valid(effect_request):
		_effect_queue.append(effect_request)

## Get an instance by UUID.
## @param uuid: String - The UUID of the instance
## @return GachaBallInstance - The instance, or null if not found
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid, null)

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
func _get_ally_behind(source_instance: GachaBallInstance) -> GachaBallInstance:
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
		func(inst): return inst.get_definition().tier == tier_to_reshuffle and _is_player_owned(inst)
	)
	if instances_to_move.is_empty(): return
	SignalBus.emit_signal("battle_log_event", "Reshuffling Tier %d discard pile..." % tier_to_reshuffle)
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
		_populate_effect_queue()
		_change_phase(Phases.COMBAT)
		_process_effect_queue()

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
	_change_phase(Phases.MANAGEMENT)
	
	var correct_answers: int = _last_minigame_results.get("correct_answers", 0)
	var gacha_gain = correct_answers
	
	_gacha_tokens += gacha_gain
	SignalBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	_last_minigame_results.clear()
	
	SignalBus.emit_signal("close_modal_requested")
