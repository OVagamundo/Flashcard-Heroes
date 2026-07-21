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
	if not is_player and is_instance_valid(GameManager.run_state):
		GameManager.run_state.total_enemies_defeated += 1
		
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
		# CRITICAL: Iterate over a COPY because move_instance_to_discard modifies the original array
		for item_uuid in unit.equipped_item_uuids.duplicate():
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
		# CRITICAL: Iterate over a COPY because update_instance_location might indirectly affect iteration (though less likely here, safe is better)
		for item_uuid in unit.equipped_item_uuids.duplicate():
			if not item_uuid.is_empty():
				var item_instance := state.get_instance(item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = ""
					item_instance.equipped_slot_index = -1
					state.update_instance_location(item_instance.ball_uuid, &"", -1)
					deferred_erasures.append(item_instance.ball_uuid)
		unit.equipped_item_uuids.fill("")
		deferred_erasures.append(unit.ball_uuid)

# ============================================================================
# LETHAL COUNTER ABILITIES
# ============================================================================

## Check if a unit has abilities that execute after receiving lethal damage
## Checks both unit abilities and equipped items
static func has_lethal_counter_abilities(unit: GachaBallInstance, battle_instances: Dictionary) -> bool:
	assert(is_instance_valid(unit), "has_lethal_counter_abilities: unit is null")
	
	for entry in unit.get_active_ability_entries(battle_instances):
		var ability: AbilityDefinition = entry.get("ability_def")
		if not is_instance_valid(ability):
			continue
		if ability.trigger == &"on_hurt" and ability.execute_on_lethal:
			return true
	
	return false

# ============================================================================
# DEATH EVENT CREATION
# ============================================================================

## Create a DEATH event if not already created for this unit
## @param unit_uuid: UUID of the dying unit
## @param death_tracking: Dictionary to track which deaths were already processed
## @param container_tag: Optional container tag to include in payload (for tutorial detection)
static func create_death_event_if_needed(unit_uuid: String, death_tracking: Dictionary, container_tag: StringName = &"") -> CombatEvent:
	if death_tracking.has(unit_uuid):
		return null # Already created
	
	death_tracking[unit_uuid] = true
	return CombatEvent.new(CombatEvent.Type.DEATH, {
		"target_uuids": [unit_uuid],
		"visual_payload": CombatPayload.container_payload(container_tag)
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
				var death_location = bm.get_location_for_uuid(uuid)
				var container_tag: StringName = death_location.container if is_instance_valid(death_location) else &""
				var death_event = create_death_event_if_needed(uuid, death_tracking, container_tag)
				if death_event != null:
					out_events.append(death_event)
			
			var death_location = bm.get_location_for_uuid(uuid)
			var team = "PLAYER" if bm._is_player_unit(unit) else "ENEMY"
			
			var death_ctx := {
				"dying_uuid": uuid,
				"dying_team": team,
				"dying_location": death_location,
				"equipped_items": snapshot_equipped_items(unit, bm._battle_instances),
				"source_pwr": unit.current_pwr
			}
			AbilityResolver.process_trigger(&"on_death", death_ctx)
			
			# Process deferred on_ally_death triggers for this unit
			process_deferred_ally_death(uuid, "PLAYER", bm)
			process_deferred_ally_death(uuid, "ENEMY", bm)
			
			var dying_tier: int = 0
			var dying_def = unit.get_definition()
			if is_instance_valid(dying_def):
				dying_tier = dying_def.tier
			var unit_death_ctx := {
				"dying_uuid": uuid,
				"dying_team": team,
				"dying_location": death_location,
				"dying_tier": dying_tier,
				"dying_definition_id": String(unit.definition_id)
			}
			AbilityResolver.process_trigger(&"on_unit_death", unit_death_ctx)
			
			# CRITICAL FIX: Actually clean up the unit from the game state
			bm._perform_unit_death_cleanup(unit)
			
			# Trigger on_board_changed for passive scaling abilities (like Twin Charm) mid-combat
			AbilityResolver.process_trigger(&"on_board_changed", {"is_simulation": true})
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
					"visual_payload": CombatPayload.container_payload(unit.location_container_tag)
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "PLAYER",
					"dying_location": death_location,
					"equipped_items": snapshot_equipped_items(unit, bm._battle_instances),
					"source_pwr": unit.current_pwr
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
					"visual_payload": CombatPayload.container_payload(unit.location_container_tag)
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: dying_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context: Dictionary = {
					"dying_uuid": unit.ball_uuid,
					"dying_team": "ENEMY",
					"dying_location": death_location,
					"equipped_items": snapshot_equipped_items(unit, bm._battle_instances),
					"source_pwr": unit.current_pwr
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

	# PRIORITY FIX: Collect all dying units and their data FIRST, then fire triggers in batches
	# This ensures priority sorting works across BOTH on_death (item, priority 200) AND 
	# on_ally_death (trinket, priority 210) triggers.
	var dying_units_data: Array[Dictionary] = [] # [{unit, death_location, team}]
	
	# Check player units (LINEUP only - bench items are not combatants)
	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		# Only process UNIT category (not items/trinkets)
		var def = unit.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT":
			continue
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				if death_tracking != null:
					if register_death(bm._state, unit, &"COMBAT"):
						# Track first-killed for resurrection
						_track_first_killed(bm, unit, "PLAYER")
						
						var death_location = bm.get_location_for_uuid(unit.ball_uuid)
						var has_lethal = has_lethal_counter_abilities(unit, bm._battle_instances)
						dying_units_data.append({
							"unit": unit,
							"death_location": death_location,
							"team": "PLAYER",
							"has_lethal_counter": has_lethal,
							"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
						})
						if has_lethal:
							deferred_deaths.append(unit.ball_uuid)
			elif not is_simulation:
				if register_death(bm._state, unit, &"COMBAT"):
					bm._perform_unit_death_cleanup(unit)
	
	# Check enemy units (LINEUP only - bench items are not combatants)
	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		# Only process UNIT category (not items/trinkets)
		var def = unit.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT":
			continue
		if unit.current_hp <= 0:
			something_changed = true
			if is_simulation and out_events != null:
				if death_tracking != null:
					if register_death(bm._state, unit, &"COMBAT"):
						# Track first-killed for resurrection
						_track_first_killed(bm, unit, "ENEMY")
						
						var death_location = bm.get_location_for_uuid(unit.ball_uuid)
						var has_lethal = has_lethal_counter_abilities(unit, bm._battle_instances)
						dying_units_data.append({
							"unit": unit,
							"death_location": death_location,
							"team": "ENEMY",
							"has_lethal_counter": has_lethal,
							"equipped_items": snapshot_equipped_items(unit, bm._battle_instances)
						})
						if has_lethal:
							deferred_deaths.append(unit.ball_uuid)
			elif not is_simulation:
				if register_death(bm._state, unit, &"COMBAT"):
					bm._perform_unit_death_cleanup(unit)
	
	# -------------------------------------------------------------------------
	# UNIFIED PRIORITY BATCHING
	# We must collect ALL triggers (on_death and on_ally_death) BEFORE draining.
	# If we drain early, lower priority items from Phase 1 might execute before
	# higher priority trinkets from Phase 2.
	# -------------------------------------------------------------------------

	# PHASE 1: Fire ALL on_death triggers (queues item summons, priority 200)
	for data in dying_units_data:
		if not data.has_lethal_counter:
			var death_ctx := {
				"dying_uuid": data.unit.ball_uuid,
				"dying_team": data.team,
				"dying_location": data.death_location,
				"equipped_items": data.equipped_items,
				"source_pwr": data.unit.current_pwr
			}
			AbilityResolver.process_trigger(&"on_death", death_ctx)
	
	if OS.is_debug_build() and is_simulation:
		pass
		# print("[DeathProcessor] Phase 1 (on_death) done. Pending: ", bm._pending_reactions.size())


	# PHASE 2: Fire ALL on_ally_death triggers (queues trinket resurrection, priority 210)
	# and emit DEATH events
	var pending_death_events: Array[CombatEvent] = []
	for data in dying_units_data:
		if data.has_lethal_counter:
			_defer_ally_death(bm, data.unit, data.death_location, data.team.to_lower())
		else:
			# Emit DEATH event with container_tag for player unit detection (deferred until after cascade)
			var death_container_tag: StringName = data.death_location.container if is_instance_valid(data.death_location) else &""
			var death_event = create_death_event_if_needed(data.unit.ball_uuid, death_tracking, death_container_tag)
			if death_event != null:
				pending_death_events.append(death_event)
			
			# Fire on_ally_death trigger
			var ally_death_ctx := {
				"fainting_ally_uuid": data.unit.ball_uuid,
				"fainting_ally_location": data.death_location,
				"fainting_ally_team": data.team
			}
			AbilityResolver.process_trigger(&"on_ally_death", ally_death_ctx)
			
			# Fire on_unit_death trigger (World trigger, all teams)
			var dying_tier: int = 0
			var dying_def = data.unit.get_definition()
			if is_instance_valid(dying_def):
				dying_tier = dying_def.tier
				
			var unit_death_ctx := {
				"dying_uuid": data.unit.ball_uuid,
				"dying_team": data.team,
				"dying_location": data.death_location,
				"dying_tier": dying_tier,
				"dying_definition_id": String(data.unit.definition_id)
			}
			AbilityResolver.process_trigger(&"on_unit_death", unit_death_ctx)

	if OS.is_debug_build() and is_simulation:
		pass
		# print("[DeathProcessor] Phase 2 (on_ally_death) done. Pending: ", bm._pending_reactions.size())
	
	# Store deferred deaths for processing after counter-attacks complete
	if not deferred_deaths.is_empty():
		var existing_deferred: Array = bm.get_meta("deferred_deaths", [])
		existing_deferred.append_array(deferred_deaths)
		bm.set_meta("deferred_deaths", existing_deferred)
	
	# PHASE 3: Drain ALL reactions AFTER both trigger types have queued
	# Priority sorting now correctly orders trinket (210) before item (200)
	if is_simulation and out_events != null:
		var cascade_evts: Array[CombatEvent] = []
		if not bm._pending_reactions.is_empty():
			if OS.is_debug_build():
				pass
				# print("[DeathProcessor] Draining batch of ", bm._pending_reactions.size())
			bm.drain_pending_reactions_inline(0)
			cascade_evts = bm.collect_inline_events()
			
		var insert_index = cascade_evts.size()
		for i in range(cascade_evts.size()):
			var type = cascade_evts[i].type
			if type == CombatEvent.Type.SUMMON or type == CombatEvent.Type.TRANSFORM:
				insert_index = i
				break
				
		# Insert DEATH events between VFX reactions (like BUFF/HEAL) and physical replacements (SUMMON/TRANSFORM)
		# This ensures the Animator plays the dying unit's buffs BEFORE the fade-out, but plays summons AFTER the fade-out.
		out_events.append_array(cascade_evts.slice(0, insert_index))
		out_events.append_array(pending_death_events)
		out_events.append_array(cascade_evts.slice(insert_index, cascade_evts.size()))
		pending_death_events.clear()
		
		# KAMIKAZE FIX: Remove DEATH events for units with KAMIKAZE_ATTACK events
		# The kamikaze animation handles the death at the target position
		var kamikaze_sources: Array[String] = []
		for evt in out_events:
			if evt.type == CombatEvent.Type.KAMIKAZE_ATTACK:
				var src = evt.visual_payload.source_uuid
				if not src.is_empty():
					kamikaze_sources.append(src)
		
		if not kamikaze_sources.is_empty():
			for i in range(out_events.size() - 1, -1, -1):
				var evt = out_events[i]
				if evt.type == CombatEvent.Type.DEATH:
					for target_uuid in evt.target_uuids:
						if kamikaze_sources.has(target_uuid):
							out_events.remove_at(i)
							break
	
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
				"uuid": unit.ball_uuid,
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
