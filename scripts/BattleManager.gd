class_name BattleManager
extends Node

const RS = preload("res://scripts/RunState.gd")

enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

var _effect_queue: Array[EffectRequest] = []
var _is_processing_effect: bool = false

const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
}

# Target resolution constants
const SELF = &"SELF"
const HOLDER = &"HOLDER"
const ATTACK_TARGET = &"ATTACK_TARGET"
const TRIGGERING_ENTITY = &"TRIGGERING_ENTITY"
const FRONTMOST_ENEMY = &"FRONTMOST_ENEMY"
const RANDOM_ENEMY = &"RANDOM_ENEMY"
const RANDOM_ALLY = &"RANDOM_ALLY"
const ALLY_BEHIND = &"ALLY_BEHIND"
const ALLY_SLOT_AHEAD = &"ALLY_SLOT_AHEAD"
const ADJACENT_ALLIES = &"ADJACENT_ALLIES"
const ALL_ALLIES = &"ALL_ALLIES"

# Condition constants
const TEAM_SIZE_LESS_THAN_ENEMY = &"TEAM_SIZE_LESS_THAN_ENEMY"
const SLOT_AHEAD_IS_EMPTY = &"SLOT_AHEAD_IS_EMPTY"
const TARGET_HP_GREATER_THAN_SELF_HP = &"TARGET_HP_GREATER_THAN_SELF_HP"

var _battle_instances: Dictionary = {}
var _containers: Dictionary = {}

const FixedArrayContainer = preload("res://scripts/FixedArrayContainer.gd")
const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")
const EncounterDefinition = preload("res://scripts/data/EncounterDefinition.gd")
var _gacha_tokens: int = 0
var _last_minigame_results: Dictionary = {}

func _ready():
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
	EventBus.results_acknowledged.connect(_on_results_acknowledged)

func _exit_tree():
	print("BattleManager: _exit_tree called")
	GameManager.unregister_battle_manager() # ADD THIS LINE
	GameManager.is_in_battle = false
	EventBus.emit_signal("battle_state_changed", false)
	if EventBus.is_connected("end_turn_requested", _on_end_turn_requested):
		EventBus.end_turn_requested.disconnect(_on_end_turn_requested)
	if EventBus.is_connected("draw_gacha_requested", _on_draw_gacha_requested):
		EventBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)
	if EventBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		EventBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if EventBus.is_connected("battle_inventory_changed", _check_and_trigger_reshuffles):
		EventBus.battle_inventory_changed.disconnect(_check_and_trigger_reshuffles)
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if EventBus.is_connected("results_acknowledged", _on_results_acknowledged):
		EventBus.results_acknowledged.disconnect(_on_results_acknowledged)

func _connect_signals():
	EventBus.end_turn_requested.connect(_on_end_turn_requested)
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	EventBus.battle_inventory_changed.connect(_check_and_trigger_reshuffles)



func start_battle(encounter_def: EncounterDefinition):
	print("BattleManager: Starting battle with encounter_def: ", encounter_def != null)
	# Clear any existing selection when entering battle
	EventBus.emit_signal("selection_clear_requested")
	_setup_battle(encounter_def)
	GameManager.is_in_battle = true
	EventBus.emit_signal("battle_state_changed", true)
	EventBus.emit_signal("battle_inventory_changed")
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	
	# Emit unit_stats_changed for all units that have equipped items after UI is populated
	call_deferred("_emit_stats_changed_for_equipped_units")
	
	# Start the first turn with the mini-game
	call_deferred("_change_phase", Phases.START_OF_TURN)

func _setup_battle(encounter_def: EncounterDefinition = null):
	_battle_instances.clear()
	_containers.clear()
	_effect_queue.clear()
	_gacha_tokens = 0
	print("BattleManager: Initial gacha_tokens set to: ", _gacha_tokens)
	
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()
	var permanent_to_battle_uuid_map: Dictionary = {}

	# First pass: Create all battle copies and map their new UUIDs, except for the hero (use persistent instance for hero)
	var hero_instance = null
	print("BattleManager: Processing ", run_state_instances.size(), " run state instances")
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		if is_hero:
			hero_instance = perm_inst
			print("BattleManager: Found hero instance: ", perm_inst.ball_uuid)
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
				var battle_item_uuid = permanent_to_battle_uuid_map[permanent_item_uuid]
				battle_inst.equipped_item_uuids[i] = battle_item_uuid
				# Also update the item's own state
				var item_instance = _battle_instances.get(battle_item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i

	# Third pass: Place all instances in their correct, stable locations.
	print("--- BATTLE SETUP: PASS 3 ---")
	print("BattleManager: Hero instance found: ", hero_instance != null)
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = String(def.id).to_lower() == "hero" or (def.tags and def.tags.has("hero"))
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc): continue
		if is_hero:
			# Place the persistent hero instance directly in the PlayerLineup
			print("BattleManager: Placing hero at index ", perm_loc.index)
			var container = get_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			container.set_uuid(perm_loc.index, perm_inst.ball_uuid)
			_update_instance_location(perm_inst.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, perm_loc.index)
			continue
		var battle_uuid = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid)
		if not battle_uuid: continue
		var battle_copy = _battle_instances[battle_uuid]
		print("Processing permanent instance: ", perm_inst.ball_uuid, " with location: ", perm_inst.location_container_tag, " [", perm_inst.location_slot_index, "]")
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

		var container = get_container(target_container_name)
		var index = perm_loc.index
		container.set_uuid(index, battle_copy.ball_uuid)
		_update_instance_location(battle_copy.ball_uuid, target_container_name, index)

	_setup_enemy_lineup(encounter_def)
	
	# Trigger on_battle_start for all units
	_trigger_battle_start_abilities()

func _setup_enemy_lineup(encounter_def: EncounterDefinition = null):
	print("BattleManager: Setting up enemy lineup with encounter_def: ", encounter_def != null)
	if encounter_def:
		# Use the provided encounter definition
		print("BattleManager: Encounter has ", encounter_def.enemy_placements.size(), " placements")
		var lineup_container = get_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		
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
			
			print("BattleManager: Created enemy unit at position ", placement.position, " with ", placement.get("items", []).size(), " items")
			
			# Note: unit_stats_changed will be emitted after UI is populated
			if placement.get("items", []).size() > 0:
				print("BattleManager: Enemy unit ", enemy_inst.ball_uuid, " has ", placement.get("items", []).size(), " equipped items")
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
				printerr("BattleManager: Unknown container type requested: ", container_name)
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

func _update_instance_location(uuid: String, container_name: StringName, index: int):
	var instance = get_instance(uuid)
	if not is_instance_valid(instance): return
	
	# Directly update the instance's properties, making it the source of truth.
	instance.location_container_tag = container_name
	instance.location_slot_index = index
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

func _change_phase(new_phase: Phases):
	_current_battle_phase = new_phase
	EventBus.emit_signal("battle_phase_changed", get_current_phase_name())
	match _current_battle_phase:
		Phases.START_OF_TURN:
			# Grant base 5 tokens for the turn
			_gacha_tokens += 5
			EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
			# The flashcard mini-game is the first event of the turn.
			# TDD Section 9.4: Battle Flow
			if is_instance_valid(GameManager.run_state):
				FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
			# Note: The combat phase will now be triggered by _on_flashcard_completed
		Phases.MANAGEMENT:
			# Re-enable draw buttons when entering management phase
			print("BattleManager: Entering MANAGEMENT phase, emitting battle_inventory_changed")
			EventBus.emit_signal("battle_inventory_changed")
		Phases.COMBAT:
			pass
		Phases.END_OF_TURN:
			pass

func _populate_effect_queue():
	_effect_queue.clear()
	
	# Process enemy attacks
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for attacker in enemy_lineup:
		var target = _get_frontmost_target(false)
		if is_instance_valid(target):
			# Trigger on_attack for the enemy unit
			var context = {"source_uuid": attacker.ball_uuid, "target_uuid": target.ball_uuid}
			AbilityResolver.process_trigger(&"on_attack", context)
			
			# If no abilities triggered, add default basic attack
			if _effect_queue.is_empty():
				var basic_attack_effect = Database.get_ability_definition(&"basic_attack").effects[0] if Database.get_ability_definition(&"basic_attack") else null
				if is_instance_valid(basic_attack_effect):
					var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", basic_attack_effect, [target.ball_uuid], context)
					_effect_queue.append(request)
	
	# Process player attacks
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for attacker in player_lineup:
		var target = _get_frontmost_target(true)
		if is_instance_valid(target):
			# Trigger on_attack for the player unit
			var context = {"source_uuid": attacker.ball_uuid, "target_uuid": target.ball_uuid}
			AbilityResolver.process_trigger(&"on_attack", context)
			
			# If no abilities triggered, add default basic attack
			if _effect_queue.is_empty():
				var basic_attack_effect = Database.get_ability_definition(&"basic_attack").effects[0] if Database.get_ability_definition(&"basic_attack") else null
				if is_instance_valid(basic_attack_effect):
					var request = EffectRequest.new(attacker.ball_uuid, &"basic_attack", basic_attack_effect, [target.ball_uuid], context)
					_effect_queue.append(request)

func _process_effect_queue() -> void:
	if _is_processing_effect: return
	if _effect_queue.is_empty(): _change_phase(Phases.MANAGEMENT); return
	_is_processing_effect = true
	while not _effect_queue.is_empty():
		var request: EffectRequest = _effect_queue.pop_back()
		
		# Check if source is still valid and alive
		var source = get_instance_by_uuid(request.source_uuid)
		if not is_instance_valid(source) or source.current_hp <= 0: 
			continue
		
		# Execute the effect using the new interface
		if is_instance_valid(request.effect_definition):
			request.effect_definition.execute(request.source_uuid, request.resolved_targets, self, request.trigger_context)
		
		_check_for_deaths()
		if _is_battle_over():
			return
		await get_tree().create_timer(0.8).timeout
	_is_processing_effect = false
	
	# Trigger on_turn_end for all units
	_trigger_turn_end_abilities()
	
	_change_phase(Phases.END_OF_TURN)
	await get_tree().create_timer(0.1).timeout
	_change_phase(Phases.START_OF_TURN)

func _move_instance_to_discard(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var discard_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var index = discard_container.find_first_empty_slot()
	if index == -1: index = discard_container.get_all_uuids().size()
	discard_container.set_uuid(index, instance.ball_uuid)
	_update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)

func _remove_instance_from_container(instance: GachaBallInstance):
	if not is_instance_valid(instance): return
	var loc = get_location_for_uuid(instance.ball_uuid)
	if not is_instance_valid(loc): return
	var container = get_container(loc.container)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx: int = uuids.find(instance.ball_uuid)
		if idx != -1: container.set_uuid(idx, "")

func _check_for_deaths():
	var something_changed = false
	var player_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			
			# Trigger on_death for the dying unit
			var death_context = {"source_uuid": unit.ball_uuid}
			AbilityResolver.process_trigger(&"on_death", death_context)
			
			# Trigger on_ally_death for all other units
			var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			for ally in all_units:
				if ally.ball_uuid != unit.ball_uuid:
					var ally_death_context = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
					AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
			
			_remove_instance_from_container(unit)
			for item_uuid in unit.equipped_item_uuids:
				if not item_uuid.is_empty():
					var item_instance = get_instance(item_uuid)
					if is_instance_valid(item_instance):
						item_instance.equipped_on_uuid = ""
						item_instance.equipped_slot_index = -1
						_move_instance_to_discard(item_instance)
			unit.equipped_item_uuids.fill("")
			_move_instance_to_discard(unit)
	
	var enemy_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			something_changed = true
			
			# Trigger on_death for the dying unit
			var death_context = {"source_uuid": unit.ball_uuid}
			AbilityResolver.process_trigger(&"on_death", death_context)
			
			# Trigger on_ally_death for all other units
			var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			for ally in all_units:
				if ally.ball_uuid != unit.ball_uuid:
					var ally_death_context = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
					AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
			
			_remove_instance_from_container(unit)
			if _battle_instances.has(unit.ball_uuid):
				_battle_instances.erase(unit.ball_uuid)
	
	if something_changed:
		EventBus.emit_signal("battle_inventory_changed")

func _is_battle_over() -> bool:
	var player_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	var enemy_lineup = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if player_lineup.is_empty() or enemy_lineup.is_empty():
		_current_battle_phase = Phases.BATTLE_OVER
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
		"SELF":
			return [source_uuid]
		"HOLDER":
			# For items, return the unit they're equipped to
			if source_instance.get_definition().category == &"ITEM" and not source_instance.equipped_on_uuid.is_empty():
				return [source_instance.equipped_on_uuid]
			# For units, return self
			return [source_uuid]
		"ATTACK_TARGET":
			# Return the target from the attack context
			var target_uuid = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				return [target_uuid]
			return []
		"TRIGGERING_ENTITY":
			# Return the entity that triggered the event
			var triggering_uuid = context.get("triggering_uuid", "")
			if not triggering_uuid.is_empty():
				return [triggering_uuid]
			return []
		"FRONTMOST_ENEMY":
			var is_source_player = _is_player_unit(source_instance)
			var target = _get_frontmost_target(!is_source_player)
			if is_instance_valid(target):
				return [target.ball_uuid]
			return []
		"RANDOM_ENEMY":
			var is_source_player = _is_player_unit(source_instance)
			var enemies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
			if not enemies.is_empty():
				var random_enemy = enemies[randi() % enemies.size()]
				return [random_enemy.ball_uuid]
			return []
		"RANDOM_ALLY":
			var is_source_player = _is_player_unit(source_instance)
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			if not allies.is_empty():
				var random_ally = allies[randi() % allies.size()]
				return [random_ally.ball_uuid]
			return []
		"ALLY_BEHIND":
			var ally_behind = _get_ally_behind(source_instance)
			if is_instance_valid(ally_behind):
				return [ally_behind.ball_uuid]
			return []
		"ALLY_SLOT_AHEAD":
			# Return empty array for summoning slots (not implemented yet)
			return []
		"ADJACENT_ALLIES":
			var adjacent = _get_adjacent_allies(source_instance)
			var uuids: Array[String] = []
			for ally in adjacent:
				uuids.append(ally.ball_uuid)
			return uuids
		"ALL_ALLIES":
			var is_source_player = _is_player_unit(source_instance)
			var allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
			var uuids: Array[String] = []
			for ally in allies:
				uuids.append(ally.ball_uuid)
			return uuids
		_:
			print("BattleManager: Unknown target type: ", target_type)
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
		"TEAM_SIZE_LESS_THAN_ENEMY":
			var is_source_player = _is_player_unit(source_instance)
			var ally_count = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).size()
			var enemy_count = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_source_player else BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).size()
			result = ally_count < enemy_count
		"SLOT_AHEAD_IS_EMPTY":
			var slot_ahead = _get_slot_ahead(source_instance)
			result = slot_ahead == null
		"TARGET_HP_GREATER_THAN_SELF_HP":
			var target_uuid = context.get("target_uuid", "")
			if not target_uuid.is_empty():
				var target_instance = get_instance_by_uuid(target_uuid)
				if is_instance_valid(target_instance):
					result = target_instance.current_hp > source_instance.current_hp
		_:
			print("BattleManager: Unknown condition type: ", condition_def.condition_type)
			result = false
	
	# Apply inversion if specified
	return !result if condition_def.invert_result else result

## Enqueue an effect request for processing.
## @param effect_request: EffectRequest - The effect request to enqueue
func enqueue_effect_request(effect_request: EffectRequest):
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
func trigger_on_hurt(target_uuid: String, damage_amount: int, attacker_uuid: String):
	var hurt_context = {
		"source_uuid": target_uuid,
		"damage_taken": damage_amount,
		"attacker_uuid": attacker_uuid
	}
	AbilityResolver.process_trigger(&"on_hurt", hurt_context)

## Trigger on_kill event for a unit that killed another unit.
## @param killer_uuid: String - The UUID of the unit that got the kill
## @param killed_uuid: String - The UUID of the unit that was killed
func trigger_on_kill(killer_uuid: String, killed_uuid: String):
	var kill_context = {
		"source_uuid": killer_uuid,
		"killed_uuid": killed_uuid
	}
	AbilityResolver.process_trigger(&"on_kill", kill_context)

## Trigger on_battle_start abilities for all units.
func _trigger_battle_start_abilities():
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in all_units:
		var battle_start_context = {"source_uuid": unit.ball_uuid}
		AbilityResolver.process_trigger(&"on_battle_start", battle_start_context)

## Trigger on_turn_end abilities for all units.
func _trigger_turn_end_abilities():
	var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in all_units:
		var turn_end_context = {"source_uuid": unit.ball_uuid}
		AbilityResolver.process_trigger(&"on_turn_end", turn_end_context)

func _reshuffle_discard_pile(tier_to_reshuffle: int):
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container): return
	var instances_to_move = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).filter(
		func(inst): return inst.get_definition().tier == tier_to_reshuffle
	)
	if instances_to_move.is_empty(): return
	EventBus.emit_signal("battle_log_event", "Reshuffling Tier %d discard pile..." % tier_to_reshuffle)
	for instance in instances_to_move:
		# Restore stats to base values before moving back to draw pool
		instance.reset_battle_stats()
		
		_remove_instance_from_container(instance)
		var new_index = dest_container.find_first_empty_slot()
		if new_index == -1: new_index = dest_container.get_all_uuids().size()
		dest_container.set_uuid(new_index, instance.ball_uuid)
		_update_instance_location(instance.ball_uuid, dest_container_tag, new_index)

func _check_and_trigger_reshuffles():
	for tier in [1, 2, 3]:
		var tier_pool = get_instances_in_container("BattleInventoryT%d" % tier)
		if tier_pool.is_empty():
			_reshuffle_discard_pile(tier)

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

func _on_end_turn_requested():
	if _current_battle_phase == Phases.MANAGEMENT:
		_populate_effect_queue()
		_change_phase(Phases.COMBAT)
		_process_effect_queue()

func _on_unit_inventory_changed(unit_uuid: String):
	# Only recalculate stats for the specific unit that changed
	var unit_instance = get_instance(unit_uuid)
	if is_instance_valid(unit_instance):
		unit_instance.recalculate_stats(_battle_instances)

func _on_draw_gacha_requested(tier: int):
	var cost = tier
	if _gacha_tokens < cost: return
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool = get_instances_in_container(container_tag)
	if tier_pool.is_empty(): return
	_gacha_tokens -= cost
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
	var drawn_instance = tier_pool.pick_random()
	var target_container_tag: StringName
	var target_container_capacity: int
	match drawn_instance.get_definition().category:
		&"UNIT":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_BENCH
			target_container_capacity = 3
		&"ITEM":
			target_container_tag = BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
			target_container_capacity = 3
		_:
			_move_instance_to_discard(drawn_instance)
			EventBus.emit_signal("battle_inventory_changed")
			return
	_remove_instance_from_container(drawn_instance)
	var target_container := get_container(target_container_tag)
	var empty_slot := target_container.find_first_empty_slot()
	if empty_slot != -1 and empty_slot < target_container_capacity:
			target_container.set_uuid(empty_slot, drawn_instance.ball_uuid)
			_update_instance_location(drawn_instance.ball_uuid, target_container_tag, empty_slot)
	else:
		_move_instance_to_discard(drawn_instance)
	EventBus.emit_signal("battle_inventory_changed")

# Helper function to equip an item on a unit
func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance):
	var empty_slot_idx: int = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
		item_instance.equipped_on_uuid = unit_instance.ball_uuid
		item_instance.equipped_slot_index = empty_slot_idx
		
		# Apply the item's stat bonuses to the unit
		unit_instance.equip_item_bonus(item_instance)

func _emit_stats_changed_for_equipped_units():
	print("BattleManager: _emit_stats_changed_for_equipped_units called")
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
				var def = instance.get_definition()
				print("BattleManager: Unit ", instance.ball_uuid, " has ", equipped_count, " equipped items")
				print("BattleManager: Base stats - HP: ", def.base_hp, ", PWR: ", def.base_pwr)
				print("BattleManager: Current stats - HP: ", instance.current_hp, ", PWR: ", instance.current_pwr)
				print("BattleManager: Emitting unit_stats_changed for unit: ", instance.ball_uuid)
				EventBus.emit_signal("unit_stats_changed", instance.ball_uuid)
			else:
				print("BattleManager: Unit ", instance.ball_uuid, " has no equipped items")

func _on_flashcard_completed(results: Dictionary):
	print("BattleManager: _on_flashcard_completed called with results: ", results)
	# TDD Section 9.4: Battle Flow
	# This handler is only for the battle context.
	if not is_instance_valid(get_node_or_null("/root/Main/VBoxContainer/ContentArea/SubViewport/Battle")):
		print("BattleManager: Early return from _on_flashcard_completed - no battle found")
		return

	_last_minigame_results = results

	var correct_answers = results.get("correct_answers", 0)
	var gacha_gain = 5 + correct_answers  # TDD: gacha_gain = 5 (base) + results.correct_answers
	
	# Display ResultsPopup
	var popup = WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Turn Start!", "You earned %d Gacha Tokens." % correct_answers, "Okay"]
	})

func _on_results_acknowledged():
	"""Called when player acknowledges the results popup"""
	_change_phase(Phases.MANAGEMENT)
	
	var correct_answers = _last_minigame_results.get("correct_answers", 0)
	var gacha_gain = correct_answers
	
	print("BattleManager: Adding ", gacha_gain, " tokens. Current tokens: ", _gacha_tokens)
	_gacha_tokens += gacha_gain
	print("BattleManager: New token count: ", _gacha_tokens)
	EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

	_last_minigame_results.clear()
	
	EventBus.emit_signal("close_modal_requested")
