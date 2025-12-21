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
const BM = preload("res://scripts/BattleManager.gd")

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
					InventoryOperations.move_instance_to_discard(state, item_instance)
		unit.equipped_item_uuids.fill("")
		
		# Reset unit state before moving to discard
		unit.reset_battle_stats_silent()
		
		InventoryOperations.move_instance_to_discard(state, unit)
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
		InventoryOperations.remove_instance_from_container(state, unit)
		deferred_erasures.append(unit.ball_uuid)

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

# ============================================================================
# CONTEXT ENRICHMENT
# ============================================================================

## Snapshot equipped items for context enrichment (effects should use context, not query instances)
## @param unit: The unit whose items to snapshot
## @param battle_instances: Dictionary of all battle instances for item lookup
static func snapshot_equipped_items(unit: GachaBallInstance, battle_instances: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item_uuid in unit.equipped_item_uuids:
		if not item_uuid.is_empty():
			var item = battle_instances.get(item_uuid, null)
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

# ============================================================================
# DEFERRED DEATH PROCESSING
# ============================================================================

## Process deferred on_ally_death triggers after counter-attacks resolve
## @param dying_uuid: UUID of the dying unit
## @param team: "PLAYER" or "ENEMY"
## @param bm: BattleManager reference for meta access
static func process_deferred_ally_death(dying_uuid: String, team: String, bm) -> void:
	var meta_key = "deferred_ally_deaths_player" if team == "PLAYER" else "deferred_ally_deaths_enemy"
	if not bm.has_meta(meta_key):
		return
	
	var deferred_list: Array = bm.get_meta(meta_key)
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
		bm.remove_meta(meta_key)
	else:
		bm.set_meta(meta_key, remaining_list)

## Check if any deferred counter-attack units have completed their abilities and should now die
## @param out_events: Array to append DEATH events to (can be null)
## @param death_tracking: Dictionary to track which deaths were already processed (can be null)
## @param bm: BattleManager reference
static func process_completed_counter_deaths(out_events, death_tracking, bm) -> void:
	if not bm.has_meta("deferred_deaths"):
		return
	
	var deferred_deaths: Array = bm.get_meta("deferred_deaths")
	var remaining_deferred: Array = []
	
	for uuid in deferred_deaths:
		var unit = bm.get_instance_by_uuid(uuid)
		if not is_instance_valid(unit):
			continue
		
		# Check if this unit still has ANY pending reactions (counters, on_death, etc.)
		var has_pending_counters = false
		for request in bm._pending_reactions:
			if request.source_uuid == uuid:
				has_pending_counters = true
				break
		
		# If no pending counter-attacks, this unit can die now
		if not has_pending_counters:
			if out_events != null and death_tracking != null:
				var death_event = create_death_event_if_needed(uuid, death_tracking)
				if death_event != null:
					out_events.append(death_event)
			
			# Process deferred on_ally_death triggers for this unit
			process_deferred_ally_death(uuid, "PLAYER", bm)
			process_deferred_ally_death(uuid, "ENEMY", bm)
			
			# CRITICAL FIX: Actually clean up the unit from the game state
			bm._perform_unit_death_cleanup(unit)
		else:
			# Still has pending counter-attacks, keep deferred
			remaining_deferred.append(uuid)
	
	# Update the deferred deaths list
	if remaining_deferred.is_empty():
		bm.remove_meta("deferred_deaths")
	else:
		bm.set_meta("deferred_deaths", remaining_deferred)

# ============================================================================
# DEATH CHECKING
# ============================================================================

## Check for dead units in both lineups and process their deaths.
## @param is_simulation: If true, only create DEATH events, don't run triggers
## @param out_events: Array to append events to (used during simulation)
## @param bm: BattleManager reference
## @return: True if something changed
static func check_for_deaths(is_simulation: bool, out_events, bm) -> bool:
	var something_changed = false
	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not register_death(bm._state, unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "PLAYER",
					"dying_location": death_location,
					"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
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
	
	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			# Use unified death registry to prevent duplicate processing
			if not register_death(bm._state, unit, &"COMBAT"):
				continue # Already died earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add DEATH event - do not process actual death yet
				out_events.append(CombatEvent.new(CombatEvent.Type.DEATH, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": {}
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "ENEMY",
					"dying_location": death_location,
					"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
				}
				AbilityResolver.process_trigger(&"on_death", death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context: Dictionary = {
					"fainting_ally_uuid": unit.ball_uuid,
					"fainting_ally_location": death_location,
					"fainting_ally_team": "ENEMY"
				}
				AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
	
	return something_changed

## Finalize deaths - called after VCR playback to synchronize logical state with visual state.
## Removes units with <= 0 HP WITHOUT triggering abilities.
## @param bm: BattleManager reference
## @return: True if something changed
static func finalize_deaths(bm) -> bool:
	var all_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var something_changed = false
	
	for unit in all_units:
		if unit.current_hp <= 0 and is_dead_this_turn(bm._state, unit.ball_uuid):
			something_changed = true
			bm._perform_unit_death_cleanup(unit)
	
	return something_changed

## Enhanced death checking that defers death events for units with counter-attacks.
## This is the most complex death processing function.
## @param is_simulation: If true, generate events for VCR playback
## @param out_events: Array to append events to (used during simulation)
## @param death_tracking: Dictionary to track which deaths were already processed
## @param bm: BattleManager reference
static func check_for_deaths_with_counter_delay(is_simulation: bool, out_events, death_tracking, bm) -> void:
	var something_changed = false
	var deferred_deaths: Array[String] = [] # Units whose deaths should be deferred
	
	# SKIP death trigger processing if called from drain_pending_reactions_inline
	if death_tracking != null and death_tracking.get("__skip_death_triggers__", false):
		return
	
	# CAUSALITY FIX: Drain ONLY execute_on_lethal reactions BEFORE processing death
	if is_simulation and out_events != null and not bm._pending_reactions.is_empty():
		bm.drain_lethal_reactions_only(0)
		var lethal_evts: Array[CombatEvent] = bm.collect_inline_events()
		for evt in lethal_evts:
			out_events.append(evt)

	
	# Check player units (LINEUP and BENCH)
	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	player_units.append_array(bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH).duplicate())
	for unit in player_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				if death_tracking != null:
					if register_death(bm._state, unit, &"COMBAT"):
						# Track first-killed for resurrection
						_track_first_killed(bm, unit, "PLAYER")
						
						var death_location = bm.get_location_for_uuid(unit.ball_uuid)
						var death_ctx := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "PLAYER",
							"dying_location": death_location,
							"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx)
						
						if has_lethal_counter_abilities(unit, bm._battle_instances):
							_defer_ally_death(bm, unit, death_location, "player")
						else:
							_emit_immediate_death(bm, unit, death_location, "PLAYER", out_events, death_tracking)
				
				deferred_deaths.append(unit.ball_uuid)
			elif not is_simulation:
				bm._perform_unit_death_cleanup(unit)
	
	# Check enemy units (same logic)
	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	enemy_units.append_array(bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH).duplicate())
	for unit in enemy_units:
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				if death_tracking != null:
					if register_death(bm._state, unit, &"COMBAT"):
						# Track first-killed for resurrection
						_track_first_killed(bm, unit, "ENEMY")
						
						var death_location = bm.get_location_for_uuid(unit.ball_uuid)
						var death_ctx := {
							"dying_uuid": unit.ball_uuid,
							"dying_team": "ENEMY",
							"dying_location": death_location,
							"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
						}
						AbilityResolver.process_trigger(&"on_death", death_ctx)
						
						if has_lethal_counter_abilities(unit, bm._battle_instances):
							_defer_ally_death(bm, unit, death_location, "enemy")
						else:
							_emit_immediate_death(bm, unit, death_location, "ENEMY", out_events, death_tracking)
				
				deferred_deaths.append(unit.ball_uuid)
			elif not is_simulation:
				bm._perform_unit_death_cleanup(unit)
	
	# Store deferred deaths for processing after counter-attacks complete
	if not deferred_deaths.is_empty():
		var existing_deferred: Array = bm.get_meta("deferred_deaths", [])
		existing_deferred.append_array(deferred_deaths)
		bm.set_meta("deferred_deaths", existing_deferred)
	
	# DEATH PRIORITY: Drain remaining cascading reactions
	if is_simulation and out_events != null and not bm._pending_reactions.is_empty():
		bm.drain_pending_reactions_inline(0)
		var cascade_evts: Array[CombatEvent] = bm.collect_inline_events()
		for evt in cascade_evts:
			out_events.append(evt)
	
	if something_changed and not is_simulation:
		bm._emit_battle_inventory_changed()

# ============================================================================
# PRIVATE HELPERS FOR DEATH WITH COUNTER DELAY
# ============================================================================

static func _track_first_killed(bm, unit: GachaBallInstance, team: String) -> void:
	var key := "first_killed_player_unit" if team == "PLAYER" else "first_killed_enemy_unit"
	if bm._turn_metadata.has(key):
		return
	var unit_def = unit.get_definition()
	if is_instance_valid(unit_def) and not unit_def.is_hero:
		var loc_snapshot = bm.get_location_for_uuid(unit.ball_uuid)
		if is_instance_valid(loc_snapshot):
			bm._turn_metadata[key] = {
				"def_id": unit.definition_id,
				"team": team,
				"location_snapshot": loc_snapshot
			}

static func _defer_ally_death(bm, unit: GachaBallInstance, death_location, team_key: String) -> void:
	var meta_key := "deferred_ally_deaths_" + team_key
	if not bm.has_meta(meta_key):
		bm.set_meta(meta_key, [])
	var deferred_list: Array = bm.get_meta(meta_key)
	deferred_list.append({
		"uuid": unit.ball_uuid,
		"location": death_location,
		"slot": unit.location_slot_index,
		"def_id": unit.definition_id
	})
	bm.set_meta(meta_key, deferred_list)

static func _emit_immediate_death(_bm, unit: GachaBallInstance, death_location, team: String, out_events: Array, death_tracking: Dictionary) -> void:
	var death_event = create_death_event_if_needed(unit.ball_uuid, death_tracking)
	if death_event != null:
		out_events.append(death_event)
	
	var ally_death_ctx := {
		"fainting_ally_uuid": unit.ball_uuid,
		"fainting_ally_location": death_location,
		"fainting_ally_team": team
	}
	AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
