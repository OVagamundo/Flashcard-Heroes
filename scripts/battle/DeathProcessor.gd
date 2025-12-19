# res://scripts/battle/DeathProcessor.gd
class_name DeathProcessor
extends RefCounted

## DeathProcessor handles all death-related logic for the battle system.
## Responsible for:
##   - Tracking which units have died this turn
##   - Cleaning up dead units (moving to discard, removing from containers)
##   - Processing deferred deaths (counter-attack deaths)
##   - Creating DEATH events

const C = preload("res://scripts/Constants.gd")

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

# ============================================================================
# DEATH REGISTRY
# ============================================================================

## Register a unit's death for this turn. Returns false if already registered.
static func register_death(state: BattleState, unit: GachaBallInstance, phase: StringName) -> bool:
	assert(is_instance_valid(unit), "register_death: unit is null")
	
	var dead_this_turn: Dictionary = state.get_dead_this_turn()
	if dead_this_turn.has(unit.ball_uuid):
		return false # Already dead this turn
	
	var is_player := state.is_player_unit(unit)
	dead_this_turn[unit.ball_uuid] = {
		"team": "PLAYER" if is_player else "ENEMY",
		"died_in_phase": phase,
		"def_id": unit.definition_id
	}
	return true

## Check if a unit has already died this turn
static func is_dead_this_turn(state: BattleState, unit_uuid: String) -> bool:
	return state.get_dead_this_turn().has(unit_uuid)

## Get death info for a unit (team, phase, def_id). Returns empty dict if not dead.
static func get_death_info(state: BattleState, unit_uuid: String) -> Dictionary:
	return state.get_dead_this_turn().get(unit_uuid, {})

# ============================================================================
# DEATH CLEANUP
# ============================================================================

## Perform cleanup for a dead unit - move to discard or remove from containers.
## NOTE: This modifies state directly. Caller handles signals/events.
static func perform_unit_death_cleanup(state: BattleState, unit: GachaBallInstance, deferred_erasures: Array) -> void:
	assert(is_instance_valid(unit), "perform_unit_death_cleanup: unit is null")
	
	# Guard against duplicate cleanup
	if unit.location_container_tag == &"" or unit.location_container_tag == &"DiscardPile":
		return
	
	if state.is_player_owned(unit):
		# Player unit: move equipped items to discard then move unit to discard
		for item_uuid in unit.equipped_item_uuids:
			if not item_uuid.is_empty():
				var item_instance := state.get_instance(item_uuid)
				if is_instance_valid(item_instance):
					_move_instance_to_discard(state, item_instance)
		unit.equipped_item_uuids.fill("")
		
		# Reset unit state before moving to discard
		unit.reset_battle_stats_silent()
		
		_move_instance_to_discard(state, unit)
	else:
		# Enemy unit: clear equipped linkage and defer erasure
		for item_uuid in unit.equipped_item_uuids:
			if not item_uuid.is_empty():
				var item_instance := state.get_instance(item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = ""
					item_instance.equipped_slot_index = -1
					state.update_instance_location(item_instance.ball_uuid, &"", -1)
					deferred_erasures.append(item_instance.ball_uuid)
		unit.equipped_item_uuids.fill("")
		_remove_instance_from_container(state, unit)
		deferred_erasures.append(unit.ball_uuid)

## Move a player instance to discard pile
static func _move_instance_to_discard(state: BattleState, instance: GachaBallInstance) -> void:
	var loc := instance.get_location()
	if is_instance_valid(loc):
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent := state.get_instance(loc.unit_uuid)
			if is_instance_valid(parent):
				if loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
					parent.equipped_item_uuids[loc.index] = ""
			instance.equipped_on_uuid = ""
			instance.equipped_slot_index = -1
		else:
			var src := state.get_container(loc.container)
			if is_instance_valid(src):
				var uuids := src.get_all_uuids()
				var si := uuids.find(instance.ball_uuid)
				if si != -1:
					src.set_uuid(si, "")
	
	var discard := state.get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard):
		return
	var index := discard.find_first_empty_slot()
	if index == -1:
		return
	discard.set_uuid(index, instance.ball_uuid)
	state.update_instance_location(instance.ball_uuid, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)

## Remove instance from its container (for enemy units)
static func _remove_instance_from_container(state: BattleState, instance: GachaBallInstance) -> void:
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return
	var container := state.get_container(loc.container)
	if is_instance_valid(container):
		var uuids := container.get_all_uuids()
		var idx: int = uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			state.update_instance_location(instance.ball_uuid, &"", -1)

# ============================================================================
# LETHAL COUNTER ABILITIES
# ============================================================================

## Check if a unit has abilities that execute after receiving lethal damage
## Checks both unit abilities and equipped items
static func has_lethal_counter_abilities(unit: GachaBallInstance, battle_instances: Dictionary) -> bool:
	assert(is_instance_valid(unit), "has_lethal_counter_abilities: unit is null")
	
	var definition := unit.get_definition()
	if not is_instance_valid(definition):
		return false
	
	# Check unit's own abilities for execute_on_lethal flag
	for ability in definition.ability_definitions:
		if not is_instance_valid(ability):
			continue
		# Only check on_hurt abilities (damage reactions)
		if ability.trigger == &"on_hurt" and ability.execute_on_lethal:
			return true
	
	# Check equipped items for on_hurt abilities with execute_on_lethal
	for item_uuid in unit.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		var item_instance: GachaBallInstance = battle_instances.get(item_uuid, null)
		if not is_instance_valid(item_instance):
			continue
		var item_def = item_instance.get_definition()
		if not is_instance_valid(item_def):
			continue
		for ability in item_def.ability_definitions:
			if not is_instance_valid(ability):
				continue
			if ability.trigger == &"on_hurt" and ability.execute_on_lethal:
				return true
	
	return false

# ============================================================================
# DEATH EVENT CREATION
# ============================================================================

## Create a DEATH event if not already created for this unit
static func create_death_event_if_needed(unit_uuid: String, death_tracking: Dictionary) -> CombatEvent:
	if death_tracking.has(unit_uuid):
		return null # Already created
	
	death_tracking[unit_uuid] = true
	return CombatEvent.new(CombatEvent.Type.DEATH, {
		"target_uuids": [unit_uuid],
		"visual_payload": {}
	})
