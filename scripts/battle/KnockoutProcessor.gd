# res://scripts/battle/KnockoutProcessor.gd
class_name KnockoutProcessor
extends RefCounted

## KnockoutProcessor handles all knockout-related logic for the battle system.
## Responsible for:
##   - Tracking which units have been knocked out this turn
##   - Cleaning up knocked out units (moving to discard, removing from containers)
##   - Processing deferred knockouts (counter-attack knockouts)
##   - Creating KNOCKOUT events

const C = preload("res://scripts/Constants.gd")
const BM = preload("res://scripts/BattleManager.gd")

# ============================================================================
# KNOCKOUT REGISTRY
# ============================================================================

## Register a unit's knockout for this turn. Returns false if already registered.
static func register_knockout(state: BattleState, unit: GachaBallInstance, phase: StringName) -> bool:
	assert(is_instance_valid(unit), "register_knockout: unit is null")
	
	var dead_this_turn: Dictionary = state.get_dead_this_turn()
	if dead_this_turn.has(unit.ball_uuid):
		return false # Already knocked out this turn
	
	var is_player := state.is_player_unit(unit)
	if not is_player and is_instance_valid(GameManager.run_state):
		GameManager.run_state.total_enemies_defeated += 1
		
	dead_this_turn[unit.ball_uuid] = {
		"team": "PLAYER" if is_player else "ENEMY",
		"died_in_phase": phase,
		"def_id": unit.definition_id
	}
	return true

## Check if a unit has already been knocked out this turn
static func is_knocked_out_this_turn(state: BattleState, unit_uuid: String) -> bool:
	return state.get_dead_this_turn().has(unit_uuid)

## Get knockout info for a unit (team, phase, def_id). Returns empty dict if not knocked out.
static func get_knockout_info(state: BattleState, unit_uuid: String) -> Dictionary:
	return state.get_dead_this_turn().get(unit_uuid, {})

# ============================================================================
# KNOCKOUT CLEANUP
# ============================================================================

## Perform cleanup for a knocked out unit - move to discard or remove from containers.
## NOTE: This modifies state directly. Caller handles signals/events.
static func perform_unit_knockout_cleanup(state: BattleState, unit: GachaBallInstance, deferred_erasures: Array) -> void:
	assert(is_instance_valid(unit), "perform_unit_knockout_cleanup: unit is null")

	# Guard against duplicate cleanup
	if unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE or unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD:
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
		# Enemy unit: transfer equipped items and unit atomically to EnemyGraveyard until deferred erasure
		for item_uuid in unit.equipped_item_uuids.duplicate():
			if not item_uuid.is_empty():
				var item_instance := state.get_instance(item_uuid)
				if is_instance_valid(item_instance):
					var item_slot := state.transfer_instance_to_container(item_instance, C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD, -1, false)
					assert(item_slot != -1, "perform_unit_knockout_cleanup: failed to move enemy item %s to EnemyGraveyard" % item_instance.ball_uuid)
					deferred_erasures.append(item_instance.ball_uuid)
		unit.equipped_item_uuids.fill("")
		var unit_slot := state.transfer_instance_to_container(unit, C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD, -1, false)
		assert(unit_slot != -1, "perform_unit_knockout_cleanup: failed to move enemy unit %s to EnemyGraveyard" % unit.ball_uuid)
		deferred_erasures.append(unit.ball_uuid)

# ============================================================================
# BEFORE-KNOCKOUT COUNTER ABILITIES
# ============================================================================

## Check if a unit has abilities that execute after receiving lethal damage
## Checks both unit abilities and equipped items
static func has_before_knockout_counter_abilities(unit: GachaBallInstance, battle_instances: Dictionary) -> bool:
	assert(is_instance_valid(unit), "has_before_knockout_counter_abilities: unit is null")
	
	for entry in unit.get_active_ability_entries(battle_instances):
		var ability: AbilityDefinition = entry.get("ability_def")
		if not is_instance_valid(ability):
			continue
		if ability.trigger == C.TRIGGER_WHEN_TAKING_DAMAGE and ability.execute_before_knockout:
			return true
	
	return false

## Returns true ONLY if the unit both possesses an execute_before_knockout ability
## AND still has an un-drained execute_before_knockout reaction waiting in bm._pending_reactions.
static func _has_pending_before_knockout_reactions(unit: GachaBallInstance, bm: Node) -> bool:
	if not has_before_knockout_counter_abilities(unit, bm._battle_instances):
		return false
	for req in bm._pending_reactions:
		if req.source_uuid == unit.ball_uuid:
			var ability_def: AbilityDefinition = bm._get_ability_definition(req.ability_id, unit)
			if is_instance_valid(ability_def) and ability_def.execute_before_knockout:
				return true
	return false

## Collects all un-registered dying units (current_hp <= 0) across both lineups,
## sorted in strict causal order:
##   1. Chronological Lethal Sequence (_lethal_sequence_by_uuid ascending)
##   2. Team Precedence (Player before Enemy)
##   3. Mirror Rule Front-to-Back (Player 4 -> 0, Enemy 0 -> 4)
static func _collect_knockout_candidates(bm: Node) -> Array[GachaBallInstance]:
	var candidates: Array[GachaBallInstance] = []
	var player_units: Array[GachaBallInstance] = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
	for unit in player_units:
		var def = unit.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT":
			continue
		if unit.current_hp <= 0 and not is_knocked_out_this_turn(bm._state, unit.ball_uuid):
			candidates.append(unit)

	var enemy_units: Array[GachaBallInstance] = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for unit in enemy_units:
		var def = unit.get_definition()
		if not is_instance_valid(def) or def.category != &"UNIT":
			continue
		if unit.current_hp <= 0 and not is_knocked_out_this_turn(bm._state, unit.ball_uuid):
			candidates.append(unit)

	if candidates.size() > 1:
		candidates.sort_custom(func(a: GachaBallInstance, b: GachaBallInstance) -> bool:
			var seq_a: int = bm._state.get_lethal_sequence(a.ball_uuid)
			var seq_b: int = bm._state.get_lethal_sequence(b.ball_uuid)
			if seq_a != seq_b:
				return seq_a < seq_b
			var a_is_player: bool = bm._state.is_player_unit(a)
			var b_is_player: bool = bm._state.is_player_unit(b)
			if a_is_player != b_is_player:
				return a_is_player
			if a_is_player:
				return a.location_slot_index > b.location_slot_index
			return a.location_slot_index < b.location_slot_index
		)
	return candidates

# ============================================================================
# KNOCKOUT EVENT CREATION
# ============================================================================

## Create a KNOCKOUT event if not already created for this unit
## @param unit_uuid: UUID of the dying unit
## @param death_tracking: Dictionary to track which deaths/knockouts were already processed
## @param container_tag: Optional container tag to include in payload (for tutorial detection)
## @param is_player: Whether the dying unit is player-owned
## @param unit_snapshot: Optional dictionary containing unit visual data
## @param equipped_items: Optional array of item snapshots held by the unit
static func create_knockout_event_if_needed(
	unit_uuid: String,
	death_tracking: Dictionary,
	container_tag: StringName = &"",
	is_player: bool = false,
	unit_snapshot: Dictionary = {},
	equipped_items: Array[Dictionary] = []
) -> CombatEvent:
	if death_tracking.has(unit_uuid):
		return null # Already created
	
	death_tracking[unit_uuid] = true
	var payload := CombatPayload.container_payload(container_tag)
	payload.is_player = is_player or (container_tag == &"PlayerLineup" or container_tag == &"PlayerShelf")
	payload.unit_snapshot = unit_snapshot
	payload.equipped_items = equipped_items
	return CombatEvent.new(CombatEvent.Type.KNOCKOUT, {
		"target_uuids": [unit_uuid],
		"visual_payload": payload
	})

# ============================================================================
# CONTEXT ENRICHMENT
# ============================================================================

## Snapshot unit definition data for visual knockout animation presentation
static func snapshot_unit(unit: GachaBallInstance) -> Dictionary:
	if not is_instance_valid(unit):
		return {}
	var def = unit.get_definition()
	return {
		"uuid": unit.ball_uuid,
		"def_id": unit.definition_id,
		"definition_id": unit.definition_id,
		"category": def.category if is_instance_valid(def) else &"UNIT",
		"tier": def.tier if (is_instance_valid(def) and "tier" in def) else 0,
		"icon": def.icon if (is_instance_valid(def) and "icon" in def) else null
	}

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
					"category": item_def.category if is_instance_valid(item_def) else &"ITEM",
					"icon": item_def.icon if (is_instance_valid(item_def) and "icon" in item_def) else null,
					"tier": item_def.tier if (is_instance_valid(item_def) and "tier" in item_def) else 0
				})
	return items

# ============================================================================
# DEFERRED KNOCKOUT PROCESSING
# ============================================================================

## Process deferred on_ally_death triggers after counter-attacks resolve
## @param ko_uuid: UUID of the knocked out unit
## @param team: "PLAYER" or "ENEMY"
## @param bm: BattleManager reference for state access
static func process_deferred_ally_knockout(ko_uuid: String, team: String, bm: Node) -> void:
	var target_list: Array[TriggerContext] = bm._state.deferred_ally_knockouts_player if team == "PLAYER" else bm._state.deferred_ally_knockouts_enemy
	var remaining_list: Array[TriggerContext] = []
	
	for ctx in target_list:
		if ctx.ally_knocked_out_uuid != ko_uuid:
			remaining_list.append(ctx)
			continue
		
		# This dying unit's on_ally_death triggers can now fire
		AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ctx)
	
	if team == "PLAYER":
		bm._state.deferred_ally_knockouts_player = remaining_list
	else:
		bm._state.deferred_ally_knockouts_enemy = remaining_list

## Check if any deferred counter-attack units have completed their abilities and should now die
## @param out_events: Array to append KNOCKOUT events to (can be null)
## @param death_tracking: Dictionary to track which deaths were already processed (can be null)
## @param bm: BattleManager reference
static func process_completed_counter_knockouts(out_events, death_tracking, bm: Node) -> void:
	if bm._state.deferred_knockouts.is_empty():
		return
	
	var pending_kos: Array[String] = bm._state.deferred_knockouts.duplicate()
	var remaining_deferred: Array[String] = []
	
	for uuid in pending_kos:
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
				var is_player = bm._is_player_unit(unit)
				var unit_snap = snapshot_unit(unit)
				var equipped = snapshot_equipped_items(unit, bm._battle_instances)
				var death_event = create_knockout_event_if_needed(uuid, death_tracking, container_tag, is_player, unit_snap, equipped)
				if death_event != null:
					out_events.append(death_event)
			
			var death_location = bm.get_location_for_uuid(uuid)
			var team = "PLAYER" if bm._is_player_unit(unit) else "ENEMY"
			
			var death_ctx := TriggerContext.new()
			death_ctx.knocked_out_uuid = uuid
			death_ctx.knocked_out_team = team
			death_ctx.knocked_out_location = death_location
			death_ctx.equipped_items = snapshot_equipped_items(unit, bm._battle_instances)
			death_ctx.source_pwr = unit.current_pwr
			AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_ctx)
			AbilityResolver.process_trigger(C.TRIGGER_WHEN_KNOCKED_OUT, death_ctx)
			
			# Process deferred on_ally_death triggers for this unit
			process_deferred_ally_knockout(uuid, "PLAYER", bm)
			process_deferred_ally_knockout(uuid, "ENEMY", bm)
			
			var ko_tier: int = 0
			var dying_def = unit.get_definition()
			if is_instance_valid(dying_def):
				ko_tier = dying_def.tier
			var unit_death_ctx := TriggerContext.new()
			unit_death_ctx.knocked_out_uuid = uuid
			unit_death_ctx.knocked_out_team = team
			unit_death_ctx.knocked_out_location = death_location
			unit_death_ctx.knocked_out_tier = ko_tier
			unit_death_ctx.knocked_out_definition_id = String(unit.definition_id)
			AbilityResolver.process_trigger(C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT, unit_death_ctx)
			
			_process_food_death_pass(bm, unit, death_location, team, out_events)
			_process_static_collateral_damage(bm, unit, death_location, team, out_events)
			_process_toy_death_detonation(bm, unit, team, out_events, death_location)
			_process_mecha_ally_death(bm, unit, team, out_events)
			_process_bounty_death(bm, unit, out_events, death_location)
			
			# CRITICAL FIX: Actually clean up the unit from the game state
			bm._perform_unit_death_cleanup(unit)
			
			# Trigger on_board_state_changed for passive scaling abilities (like Twin Charm) mid-combat
			var board_ctx := TriggerContext.new()
			board_ctx.is_simulation = true
			AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)
		else:
			# Still has pending counter-attacks, keep deferred
			remaining_deferred.append(uuid)
	
	# Update the deferred knockouts list
	bm._state.deferred_knockouts = remaining_deferred

# ============================================================================
# KNOCKOUT CHECKING
# ============================================================================

## Check for knocked out units in both lineups and process their knockouts.
## @param is_simulation: If true, only create KNOCKOUT events, don't run triggers
## @param out_events: Array to append events to (used during simulation)
## @param bm: BattleManager reference
## @return: True if something changed
static func check_for_knockouts(is_simulation: bool, out_events, bm: Node) -> bool:
	var something_changed = false
	var player_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP).duplicate()
	for unit in player_units:
		if unit.current_hp <= 0:
			# Use unified knockout registry to prevent duplicate processing
			if not register_knockout(bm._state, unit, &"COMBAT"):
				continue # Already knocked out earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add KNOCKOUT event - do not process actual death yet
				var p_payload := CombatPayload.container_payload(unit.location_container_tag)
				p_payload.is_player = true
				p_payload.unit_snapshot = snapshot_unit(unit)
				p_payload.equipped_items = snapshot_equipped_items(unit, bm._battle_instances)
				out_events.append(CombatEvent.new(CombatEvent.Type.KNOCKOUT, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": p_payload
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: knocked_out_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context := TriggerContext.new()
				death_context.knocked_out_uuid = unit.ball_uuid
				death_context.knocked_out_team = "PLAYER"
				death_context.knocked_out_location = death_location
				death_context.equipped_items = snapshot_equipped_items(unit, bm._battle_instances)
				death_context.source_pwr = unit.current_pwr
				AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_context)
				AbilityResolver.process_trigger(C.TRIGGER_WHEN_KNOCKED_OUT, death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context := TriggerContext.new()
				ally_death_context.ally_knocked_out_uuid = unit.ball_uuid
				ally_death_context.ally_knocked_out_location = death_location
				ally_death_context.ally_knocked_out_team = "PLAYER"
				ally_death_context.ally_knocked_out_pwr = unit.current_pwr
				AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
	
	var enemy_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP).duplicate()
	for unit in enemy_units:
		if unit.current_hp <= 0:
			# Use unified knockout registry to prevent duplicate processing
			if not register_knockout(bm._state, unit, &"COMBAT"):
				continue # Already knocked out earlier this turn
			something_changed = true
			if is_simulation and out_events != null:
				# During simulation, ONLY add KNOCKOUT event - do not process actual death yet
				var e_payload := CombatPayload.container_payload(unit.location_container_tag)
				e_payload.is_player = false
				out_events.append(CombatEvent.new(CombatEvent.Type.KNOCKOUT, {
					"target_uuids": [unit.ball_uuid],
					"visual_payload": e_payload
				}))
			elif not is_simulation:
				# Trigger on_death for the dying unit (semantic key: knocked_out_uuid)
				var death_location = bm.get_location_for_uuid(unit.ball_uuid)
				var death_context := TriggerContext.new()
				death_context.knocked_out_uuid = unit.ball_uuid
				death_context.knocked_out_team = "ENEMY"
				death_context.knocked_out_location = death_location
				death_context.equipped_items = snapshot_equipped_items(unit, bm._battle_instances)
				death_context.source_pwr = unit.current_pwr
				AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_context)
				AbilityResolver.process_trigger(C.TRIGGER_WHEN_KNOCKED_OUT, death_context)
				
				# UNIFIED BROADCAST: Single call, AbilityResolver self-filters
				var ally_death_context := TriggerContext.new()
				ally_death_context.ally_knocked_out_uuid = unit.ball_uuid
				ally_death_context.ally_knocked_out_location = death_location
				ally_death_context.ally_knocked_out_team = "ENEMY"
				ally_death_context.ally_knocked_out_pwr = unit.current_pwr
				AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ally_death_context)
				
				# DEFER cleanup - unit must stay in original container
	
	return something_changed

## Finalize knockouts - called after VCR playback to synchronize logical state with visual state.
## Removes units with <= 0 HP WITHOUT triggering abilities.
## @param bm: BattleManager reference
## @return: True if something changed
static func finalize_knockouts(bm: Node) -> bool:
	var all_units = bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + bm.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var something_changed = false
	
	for unit in all_units:
		if unit.current_hp <= 0 and is_knocked_out_this_turn(bm._state, unit.ball_uuid):
			something_changed = true
			bm._perform_unit_death_cleanup(unit)
	
	return something_changed

## Enhanced knockout checking that defers knockout events for units with counter-attacks.
## @param is_simulation: If true, generate events for VCR playback
## @param out_events: Array to append events to (used during simulation)
## @param death_tracking: Dictionary to track which knockouts were already processed
## @param bm: BattleManager reference
static func check_for_knockouts_with_counter_delay(is_simulation: bool, out_events, death_tracking, bm: Node) -> void:
	var something_changed := false
	
	# SKIP death trigger processing if called from drain_pending_reactions_inline
	if death_tracking != null and death_tracking.get("__skip_death_triggers__", false):
		return
	
	# Re-entrancy guard: if an outer knockout loop is already resolving a casualty,
	# let the current casualty finish atomically; the outer loop will pick up new casualties next.
	if bm._state.is_resolving_knockouts:
		return
	
	bm._state.is_resolving_knockouts = true
	
	# SINGLE-CASUALTY ATOMIC DRAIN LOOP
	# Resolves one casualty at a time in chronological lethal sequence order (FIFO),
	# with Team + Mirror Rule (Player 4->0, Enemy 0->4) as tie-breaker.
	# Every reaction and summon chain for Casualty #1 resolves completely before Casualty #2 begins.
	var cascade_safety_limit := 40
	while cascade_safety_limit > 0:
		cascade_safety_limit -= 1
		
		# Drain any pending execute_before_knockout reactions before selecting the next casualty
		if is_simulation and out_events != null and not bm._pending_reactions.is_empty():
			var lethal_evts: Array[CombatEvent] = bm.drain_lethal_counters()
			for evt in lethal_evts:
				out_events.append(evt)
		
		var candidates: Array[GachaBallInstance] = _collect_knockout_candidates(bm)
		if candidates.is_empty():
			break
		
		var unit: GachaBallInstance = candidates[0]
		var team: String = "PLAYER" if bm._state.is_player_unit(unit) else "ENEMY"
		
		if not is_simulation or out_events == null or death_tracking == null:
			if register_knockout(bm._state, unit, &"COMBAT"):
				something_changed = true
				bm._perform_unit_death_cleanup(unit)
			continue
		
		if not register_knockout(bm._state, unit, &"COMBAT"):
			continue
		
		something_changed = true
		track_first_knocked_out(bm, unit, team)
		
		var death_location: LocationIdentifier = bm.get_location_for_uuid(unit.ball_uuid)
		var equipped_items: Array[Dictionary] = snapshot_equipped_items(unit, bm._battle_instances)
		var has_pending_lethal: bool = _has_pending_before_knockout_reactions(unit, bm)
		
		if has_pending_lethal:
			_defer_ally_knockout(bm, unit, death_location, team.to_lower())
			bm._state.deferred_knockouts.append(unit.ball_uuid)
			continue
		
		_resolve_single_casualty_knockout(bm, unit, death_location, team, equipped_items, out_events, death_tracking)
	
	bm._state.is_resolving_knockouts = false
	
	if something_changed and not is_simulation:
		bm._emit_battle_inventory_changed()

## Resolves the complete knockout lifecycle of a single casualty atomically across 3 chronological stages:
##   Stage 1 (Pre-Departure, SubPhase <= 25): Food death pass, Empathic Link (12), Item Transfer (20), Pre-Knockout Attack (25)
##   Stage 2 (Departure & Detonations): KNOCKOUT visual fade event, Static discharge, Toy detonation, Mecha death proc, Bounty claim
##   Stage 3 (Post-Departure Cascade, SubPhase >= 30): Soul Echo (30), Matryodust (35), Anvil/Slime Cell (40), Summon chains (50..80), Standard (200), Extra Action (300)
static func _resolve_single_casualty_knockout(
	bm: Node,
	unit: GachaBallInstance,
	death_location: LocationIdentifier,
	team: String,
	initial_equipped_items: Array[Dictionary],
	out_events: Array,
	death_tracking: Dictionary
) -> void:
	var ko_tier: int = 0
	var dying_def = unit.get_definition()
	if is_instance_valid(dying_def):
		ko_tier = dying_def.tier
	var unit_pwr_at_death: int = unit.current_pwr
	var unit_def_id_str: String = String(unit.definition_id)
	var is_player: bool = (team == "PLAYER")
	var death_container_tag: StringName = death_location.container if is_instance_valid(death_location) else &""
	var unit_snap: Dictionary = snapshot_unit(unit)

	# -------------------------------------------------------------------------
	# STAGE 1: Pre-Departure Inheritance & Final Act (SubPhase <= 25)
	# -------------------------------------------------------------------------
	var stage1_events: Array[CombatEvent] = []
	_process_food_death_pass(bm, unit, death_location, team, stage1_events)

	var ko_scope: int = bm.begin_reaction_scope()

	var death_ctx := TriggerContext.new()
	death_ctx.knocked_out_uuid = unit.ball_uuid
	death_ctx.knocked_out_team = team
	death_ctx.knocked_out_location = death_location
	death_ctx.knocked_out_tier = ko_tier
	death_ctx.knocked_out_definition_id = unit_def_id_str
	death_ctx.equipped_items = initial_equipped_items
	death_ctx.source_pwr = unit_pwr_at_death
	death_ctx.source_level = unit.level
	AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_ctx)
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_KNOCKED_OUT, death_ctx)

	var pre_departure_evts: Array[CombatEvent] = bm.drain_reaction_scope_matching(
		ko_scope,
		func(req: EffectRequest) -> bool:
			return req.sub_phase <= C.SubPhase.PRE_KNOCKOUT
	)
	var stage1_inline: Array[CombatEvent] = bm.collect_inline_events()
	stage1_events.append_array(stage1_inline)
	stage1_events.append_array(pre_departure_evts)

	for evt in stage1_events:
		if evt.type == CombatEvent.Type.PRE_KNOCKOUT_ATTACK and evt.visual_payload != null:
			var kamikaze_src: String = evt.visual_payload.source_uuid
			if not kamikaze_src.is_empty():
				death_tracking[kamikaze_src] = true

	# -------------------------------------------------------------------------
	# STAGE 2: Departure (KNOCKOUT Event) & Environmental Detonations
	# -------------------------------------------------------------------------
	# Re-snapshot equipped items so items already transferred/discarded in Stage 1 (Passing Trick)
	# are not duplicate-animated to the Discard on unit departure.
	var remaining_equipped_items: Array[Dictionary] = snapshot_equipped_items(unit, bm._battle_instances)
	var death_event: CombatEvent = create_knockout_event_if_needed(
		unit.ball_uuid,
		death_tracking,
		death_container_tag,
		is_player,
		unit_snap,
		remaining_equipped_items
	)

	var trait_events: Array[CombatEvent] = []
	_process_static_collateral_damage(bm, unit, death_location, team, trait_events)
	_process_toy_death_detonation(bm, unit, team, trait_events, death_location)
	_process_mecha_ally_death(bm, unit, team, trait_events)
	_process_bounty_death(bm, unit, trait_events, death_location)
	var stage2_inline: Array[CombatEvent] = bm.collect_inline_events()
	trait_events.append_array(stage2_inline)

	# -------------------------------------------------------------------------
	# STAGE 3: Post-Departure Reactions & Summon Cascades (SubPhase >= 30)
	# -------------------------------------------------------------------------
	var ally_death_ctx := TriggerContext.new()
	ally_death_ctx.ally_knocked_out_uuid = unit.ball_uuid
	ally_death_ctx.ally_knocked_out_location = death_location
	ally_death_ctx.ally_knocked_out_team = team
	ally_death_ctx.ally_knocked_out_pwr = unit_pwr_at_death
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ally_death_ctx)

	var unit_death_ctx := TriggerContext.new()
	unit_death_ctx.knocked_out_uuid = unit.ball_uuid
	unit_death_ctx.knocked_out_team = team
	unit_death_ctx.knocked_out_location = death_location
	unit_death_ctx.knocked_out_tier = ko_tier
	unit_death_ctx.knocked_out_definition_id = unit_def_id_str
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT, unit_death_ctx)

	# Adopt any pending ON_KNOCKOUT_BLOW reactions that were enqueued for this casualty
	bm.adopt_into_reaction_scope(
		ko_scope,
		func(req: EffectRequest) -> bool:
			return req.trigger_context.trigger_type == C.TRIGGER_ON_KNOCKOUT_BLOW and req.trigger_context.knocked_out_uuid == unit.ball_uuid
	)

	var stage3_events: Array[CombatEvent] = bm.drain_reaction_scope(ko_scope)
	var stage3_inline: Array[CombatEvent] = bm.collect_inline_events()
	stage3_events.append_array(stage3_inline)

	var pre_death_slice: Array[CombatEvent] = []
	var post_death_slice: Array[CombatEvent] = []
	for evt in stage3_events:
		var is_gacha_summon: bool = (
			evt.type == CombatEvent.Type.SUMMON
			and evt.visual_payload != null
			and evt.visual_payload.old_unit_location != null
			and String(evt.visual_payload.old_unit_location.container).begins_with("BattleInventoryT")
		)
		if is_gacha_summon:
			pre_death_slice.append(evt)
		else:
			post_death_slice.append(evt)

	out_events.append_array(pre_death_slice)
	out_events.append_array(stage1_events)
	if death_event != null:
		out_events.append(death_event)
	out_events.append_array(trait_events)
	out_events.append_array(post_death_slice)

# ============================================================================
# CONSOLIDATED REGISTERED KNOCKOUT PROCESSING
# ============================================================================

## Consolidated handler for registered knockouts caused by status effects such as Burn.
static func process_registered_knockout(
	unit: GachaBallInstance,
	phase: StringName,
	knockout_team: String,
	all_events: Array[CombatEvent],
	knockout_tracking: Dictionary,
	bm: Node
) -> void:
	if not register_knockout(bm._state, unit, phase):
		return
	
	if not knockout_tracking.has(unit.ball_uuid):
		knockout_tracking[unit.ball_uuid] = true
		all_events.append(CombatEvent.new(CombatEvent.Type.KNOCKOUT, {
			"target_uuids": [unit.ball_uuid],
			"visual_payload": CombatPayload.new()
		}))
	
	track_first_knocked_out(bm, unit, knockout_team)
	
	var death_location = bm.get_location_for_uuid(unit.ball_uuid)
	_process_food_death_pass(bm, unit, death_location, knockout_team, all_events)
	_process_static_collateral_damage(bm, unit, death_location, knockout_team, all_events)
	_process_toy_death_detonation(bm, unit, knockout_team, all_events, death_location)
	_process_mecha_ally_death(bm, unit, knockout_team, all_events)
	_process_bounty_death(bm, unit, all_events, death_location)

	var ko_tier: int = 0
	var unit_def = unit.get_definition()
	if is_instance_valid(unit_def):
		ko_tier = unit_def.tier
	
	var death_ctx := TriggerContext.new()
	death_ctx.knocked_out_uuid = unit.ball_uuid
	death_ctx.knocked_out_team = knockout_team
	death_ctx.knocked_out_location = death_location
	death_ctx.knocked_out_tier = ko_tier
	death_ctx.knocked_out_definition_id = String(unit.definition_id)
	death_ctx.equipped_items = snapshot_equipped_items(unit, bm._battle_instances)
	death_ctx.source_pwr = unit.current_pwr
	AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_ctx)
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_KNOCKED_OUT, death_ctx)

	var ally_death_ctx := TriggerContext.new()
	ally_death_ctx.ally_knocked_out_uuid = unit.ball_uuid
	ally_death_ctx.ally_knocked_out_location = death_location
	ally_death_ctx.ally_knocked_out_team = knockout_team
	ally_death_ctx.ally_knocked_out_pwr = unit.current_pwr
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ally_death_ctx)

	var unit_death_ctx := TriggerContext.new()
	unit_death_ctx.knocked_out_uuid = unit.ball_uuid
	unit_death_ctx.knocked_out_team = knockout_team
	unit_death_ctx.knocked_out_location = death_location
	unit_death_ctx.knocked_out_tier = ko_tier
	unit_death_ctx.knocked_out_definition_id = String(unit.definition_id)
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT, unit_death_ctx)
	
	while not bm._pending_reactions.is_empty():
		bm._combat.sort_reactions_by_sub_phase()
		var death_reaction = bm._pending_reactions.pop_front()
		var death_reaction_events: Array[CombatEvent] = []
		bm._resolve_single_effect_request(death_reaction, death_reaction_events, knockout_tracking)
		all_events.append_array(death_reaction_events)

# ============================================================================
# HELPERS FOR KNOCKOUT PROCESSING
# ============================================================================

static func track_first_knocked_out(bm: Node, unit: GachaBallInstance, team: String) -> void:
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

static func _defer_ally_knockout(bm: Node, unit: GachaBallInstance, death_location, team_key: String) -> void:
	var ally_death_ctx := TriggerContext.new()
	ally_death_ctx.ally_knocked_out_uuid = unit.ball_uuid
	ally_death_ctx.ally_knocked_out_location = death_location
	ally_death_ctx.ally_knocked_out_team = "PLAYER" if team_key.to_upper() == "PLAYER" else "ENEMY"
	ally_death_ctx.ally_knocked_out_pwr = unit.current_pwr
	if ally_death_ctx.ally_knocked_out_team == "PLAYER":
		bm._state.deferred_ally_knockouts_player.append(ally_death_ctx)
	else:
		bm._state.deferred_ally_knockouts_enemy.append(ally_death_ctx)

static func _emit_immediate_knockout(bm: Node, unit: GachaBallInstance, death_location, team: String, out_events: Array, death_tracking: Dictionary) -> void:
	var container_tag: StringName = death_location.container if is_instance_valid(death_location) else &""
	var is_player = (team == "PLAYER")
	var unit_snap = snapshot_unit(unit)
	var equipped = snapshot_equipped_items(unit, bm._battle_instances)
	var death_event = create_knockout_event_if_needed(unit.ball_uuid, death_tracking, container_tag, is_player, unit_snap, equipped)
	if death_event != null:
		out_events.append(death_event)
	
	var ally_death_ctx := TriggerContext.new()
	ally_death_ctx.ally_knocked_out_uuid = unit.ball_uuid
	ally_death_ctx.ally_knocked_out_location = death_location
	ally_death_ctx.ally_knocked_out_team = team
	ally_death_ctx.ally_knocked_out_pwr = unit.current_pwr
	AbilityResolver.process_trigger(C.TRIGGER_WHEN_ALLY_KNOCKED_OUT, ally_death_ctx)

static func _process_bounty_death(bm: Node, unit: GachaBallInstance, out_events: Array[CombatEvent], death_location: LocationIdentifier) -> void:
	assert(death_location != null, "Bounty: knockout location is required")
	if not bm._is_lineup_container(death_location.container):
		return
	var bounty_stacks: int = unit.get_status_effect_amount(&"bounty")
	if bounty_stacks <= 0:
		return
	unit.clear_status_effect_silent(&"bounty")
	bm.earn_gold(bounty_stacks, unit.ball_uuid)
	var bounty_inline: Array[CombatEvent] = bm.collect_inline_events()
	out_events.append_array(bounty_inline)

	var bounty_ctx := TriggerContext.new()
	bounty_ctx.unit_uuid = unit.ball_uuid
	bounty_ctx.triggering_uuid = unit.ball_uuid
	bounty_ctx.amount = bounty_stacks
	bounty_ctx.bounty_stacks = bounty_stacks
	AbilityResolver.process_trigger(C.TRIGGER_ON_BOUNTY_CLAIMED, bounty_ctx)

static func _process_static_collateral_damage(bm: Node, unit: GachaBallInstance, death_location, team: String, out_events) -> void:
	if not is_instance_valid(unit):
		return
	assert(death_location != null, "Static collateral: knockout location is required")
	if death_location.container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and death_location.container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return
	var static_stacks = unit.get_status_effect_amount(&"static")
	if static_stacks <= 0:
		return
	
	unit.clear_status_effect_silent(&"static")
	
	var death_slot: int = death_location.index
	var lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var lineup = bm.get_instances_in_container(lineup_tag)
	
	for candidate in lineup:
		if not is_instance_valid(candidate) or candidate.current_hp <= 0:
			continue
		if candidate.ball_uuid == unit.ball_uuid:
			continue
		if candidate.location_slot_index == death_slot - 1 or candidate.location_slot_index == death_slot + 1:
			var old_hp = candidate.current_hp
			var old_armor = candidate.get_status_effect_amount(&"armor")
			var dmg_result = bm.apply_damage(candidate, static_stacks, C.DamageType.STATIC, unit.ball_uuid)
			var new_hp = candidate.current_hp
			var armor_consumed = 0
			var new_armor = old_armor
			if dmg_result is Dictionary and not dmg_result.is_empty():
				new_hp = dmg_result.get("new_hp", new_hp)
				armor_consumed = dmg_result.get("armor_consumed", 0)
				new_armor = dmg_result.get("new_armor", new_armor)
			
			if out_events != null:
				var target_name = BattleHelpers.get_instance_display_name(candidate)
				var source_name = BattleHelpers.get_instance_display_name(unit)
				out_events.append(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s suffers %d static collateral damage from %s" % [target_name, static_stacks, source_name]
				}))
				
				var max_hp = 0
				var candidate_def = candidate.get_definition()
				if is_instance_valid(candidate_def):
					max_hp = candidate_def.base_hp
					
				var payload := CombatPayload.damage(unit.ball_uuid, -static_stacks, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
				payload.skip_bump = true
				payload.is_status_damage = true
				payload.status_color = Color(1, 0.85, 0.1, 1)
				payload.targets_max_hp = [max_hp] as Array[int]
				out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
					"source_uuid": unit.ball_uuid,
					"target_uuids": [candidate.ball_uuid],
					"visual_payload": payload
				}))

static func _process_food_death_pass(bm: Node, unit: GachaBallInstance, death_location: LocationIdentifier, team: String, out_events) -> void:
	if not is_instance_valid(unit):
		return
	assert(death_location != null, "Food death pass: knockout location is required")
	if not bm._is_lineup_container(death_location.container):
		return
	var traits = bm.get_active_traits(team)
	if not TraitRulesEngine.has_tier(traits, "FOOD", 4) or not bm.has_trait(unit, "FOOD"):
		return

	var ally_behind = bm._get_ally_behind(unit, true)
	if not is_instance_valid(ally_behind) and is_instance_valid(death_location):
		var death_slot: int = death_location.index
		var behind_slot: int = death_slot - 1 if team == "PLAYER" else death_slot + 1
		var lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		var container = bm._state.get_container(lineup_tag)
		if is_instance_valid(container) and behind_slot >= 0 and behind_slot < container.get_size():
			var behind_uuid = container.get_uuid(behind_slot)
			if not behind_uuid.is_empty():
				ally_behind = bm.get_instance_by_uuid(behind_uuid)

	if is_instance_valid(ally_behind) and (ally_behind.current_hp > 0 or (ally_behind.location_container_tag != C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE and ally_behind.location_container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD and ally_behind.location_container_tag != &"")):
		var pwr_to_pass = max(1, unit.current_pwr)
		var old_p = ally_behind.current_pwr
		var new_p = bm.apply_stat_delta(ally_behind, "pwr", pwr_to_pass, unit.ball_uuid, C.ACTION_BUFF)
		if out_events != null:
			out_events.append(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": unit.ball_uuid,
				"target_uuids": [ally_behind.ball_uuid],
				"action_type": C.ACTION_BUFF,
				"visual_payload": CombatPayload.pwr_change(unit.ball_uuid, pwr_to_pass, [old_p], [new_p])
			}))

static func _process_toy_death_detonation(bm: Node, unit: GachaBallInstance, team: String, out_events, death_location: LocationIdentifier) -> void:
	if not is_instance_valid(unit):
		return
	assert(death_location != null, "Toy detonation: knockout location is required")
	if not bm._is_lineup_container(death_location.container):
		return
	var traits = bm.get_active_traits(team)
	if not TraitRulesEngine.has_tier(traits, "TOY", 4) or not bm.has_trait(unit, "TOY"):
		return

	var opp_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var enemies = bm.get_instances_in_container(opp_tag).filter(func(e): return is_instance_valid(e) and e.current_hp > 0 and e.get_status_effect_amount(&"static") > 0)
	if enemies.is_empty():
		return

	enemies.sort_custom(func(a, b):
		var st_a = a.get_status_effect_amount(&"static")
		var st_b = b.get_status_effect_amount(&"static")
		if st_a != st_b:
			return st_a > st_b
		if team == "PLAYER":
			return a.location_slot_index < b.location_slot_index
		else:
			return a.location_slot_index > b.location_slot_index
	)
	var target_enemy = enemies[0]
	var static_amt = target_enemy.get_status_effect_amount(&"static")
	target_enemy.clear_status_effect_silent(&"static")
	var old_h = target_enemy.current_hp
	var old_a = target_enemy.get_status_effect_amount(&"armor")
	var dmg_res = bm.apply_damage(target_enemy, static_amt, C.DamageType.STATIC, unit.ball_uuid)
	var new_h = dmg_res.get("new_hp", target_enemy.current_hp)
	var a_cons = dmg_res.get("armor_consumed", 0)
	var new_a = dmg_res.get("new_armor", old_a)
	var max_h = 0
	var te_def = target_enemy.get_definition()
	if is_instance_valid(te_def):
		max_h = te_def.base_hp

	if out_events != null:
		var st_p := CombatPayload.status_change(unit.ball_uuid, -static_amt, "static_stacks", [static_amt], [0])
		out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": unit.ball_uuid,
			"target_uuids": [target_enemy.ball_uuid],
			"visual_payload": st_p
		}))
		var dmg_p := CombatPayload.damage(unit.ball_uuid, -static_amt, [old_h], [new_h], [old_a], [new_a], [a_cons])
		dmg_p.skip_bump = true
		dmg_p.is_status_damage = true
		dmg_p.status_color = Color(1, 0.85, 0.1, 1)
		dmg_p.targets_max_hp = [max_h] as Array[int]
		out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
			"source_uuid": unit.ball_uuid,
			"target_uuids": [target_enemy.ball_uuid],
			"visual_payload": dmg_p
		}))

	if new_h <= 0:
		bm.trigger_on_kill(unit.ball_uuid, target_enemy.ball_uuid)

static func _process_mecha_ally_death(bm: Node, dying_unit: GachaBallInstance, team: String, out_events) -> void:
	if not is_instance_valid(dying_unit):
		return
	var traits = bm.get_active_traits(team)
	if not TraitRulesEngine.has_tier(traits, "MECHA", 4) or not bm.has_trait(dying_unit, "MECHA"):
		return

	var lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var mechas = bm.get_instances_in_container(lineup_tag).filter(func(u): return is_instance_valid(u) and u.current_hp > 0 and u.ball_uuid != dying_unit.ball_uuid and bm.has_trait(u, "MECHA"))
	if mechas.is_empty():
		return

	var opp_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if team == "PLAYER" else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var opp_lineup = bm.get_instances_in_container(opp_tag)

	for mecha in mechas:
		var old_arm = mecha.get_status_effect_amount(&"armor")
		var new_arm = bm.apply_stat_delta(mecha, "armor_stacks", 2, dying_unit.ball_uuid, C.ACTION_BUFF)
		var old_spk = mecha.get_status_effect_amount(&"spikes")
		var new_spk = bm.apply_stat_delta(mecha, "spikes_stacks", 2, dying_unit.ball_uuid, C.ACTION_BUFF)
		if out_events != null:
			out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": dying_unit.ball_uuid,
				"target_uuids": [mecha.ball_uuid],
				"visual_payload": CombatPayload.status_change(dying_unit.ball_uuid, 2, "armor_stacks", [old_arm], [new_arm])
			}))
			out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": dying_unit.ball_uuid,
				"target_uuids": [mecha.ball_uuid],
				"visual_payload": CombatPayload.status_change(dying_unit.ball_uuid, 2, "spikes_stacks", [old_spk], [new_spk])
			}))

		var living_enemies = opp_lineup.filter(func(e): return is_instance_valid(e) and e.current_hp > 0)
		if not living_enemies.is_empty():
			var enemy = RNGManager.combat_rng.pick_random(living_enemies)
			var old_h = enemy.current_hp
			var old_a = enemy.get_status_effect_amount(&"armor")
			var dmg_res = bm.apply_damage(enemy, 2, C.DamageType.RANGED, mecha.ball_uuid)
			var new_h = dmg_res.get("new_hp", enemy.current_hp)
			var a_cons = dmg_res.get("armor_consumed", 0)
			var new_a = dmg_res.get("new_armor", old_a)
			var max_h = 0
			var e_def = enemy.get_definition()
			if is_instance_valid(e_def):
				max_h = e_def.base_hp

			if out_events != null:
				var p := CombatPayload.damage(mecha.ball_uuid, 2, [old_h], [new_h], [old_a], [new_a], [a_cons])
				p.attack_type = "ranged"
				p.skip_bump = true
				p.projectile = CombatProjectile.new("hp", 2, "yellow")
				p.targets_max_hp = [max_h] as Array[int]
				out_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
					"source_uuid": mecha.ball_uuid,
					"target_uuids": [enemy.ball_uuid],
					"visual_payload": p
				}))
				var old_st = enemy.get_status_effect_amount(&"static")
				var new_st = bm.apply_stat_delta(enemy, "static_stacks", 2)
				var st_p := CombatPayload.status_change(mecha.ball_uuid, 2, "static_stacks", [old_st], [new_st])
				out_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": mecha.ball_uuid,
					"target_uuids": [enemy.ball_uuid],
					"visual_payload": st_p
				}))

			if new_h <= 0:
				bm.trigger_on_kill(mecha.ball_uuid, enemy.ball_uuid)
