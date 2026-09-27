# res://scripts/battle/CombatSimulator.gd
class_name CombatSimulator
extends RefCounted
const C = preload("res://scripts/Constants.gd")
const CausalReactionResolver = preload("res://scripts/battle/CausalReactionResolver.gd")

## CombatSimulator encapsulates the turn-based combat simulation data.
## This class is responsible for:
##   - Managing the actor queue (units that will act this turn)
##   - Managing pending effect reactions via CausalReactionResolver (CRR)
##   - Tracking inline events from on_before_attack processing
##
## NOTE: The actual combat logic remains in BattleManager for now due to
## tight coupling. This class provides the data structures and will be
## expanded in future refactoring phases.

# ============================================================================
# COMBAT DATA
# ============================================================================

## Dynamic list of units to act this turn
var _actor_queue: Array[GachaBallInstance] = []

## Authoritative Causal Reaction Resolver (CRR)
var _crr: CausalReactionResolver = CausalReactionResolver.new()

## Backward-compatible property forwarder for _pending_reactions
var _pending_reactions: Array[EffectRequest]:
	get: return _crr._pending_reactions
	set(value): _crr._pending_reactions = value

## Events from on_before_attack processing
var _inline_events: Array[CombatEvent] = []

## Ref-counted lock to prevent re-entrant effect processing.
## Multiple callers (MergeAnimator, _process_management_animation_queue, etc.) can each
## increment this counter; the lock is only fully released when ALL holders decrement.
var _processing_effect_count: int = 0

## Track the currently acting unit to prevent re-insertion complications
var _current_acting_unit: GachaBallInstance = null

## Robust Turn Tracking (Integer-based)
## Persists even if the acting unit dies and moves to discard
var _current_turn_slot_index: int = -1
var _current_turn_is_player: bool = false

# ============================================================================
# ACTOR QUEUE MANAGEMENT
# ============================================================================

func get_actor_queue() -> Array[GachaBallInstance]:
	return _actor_queue

func clear_actor_queue() -> void:
	_actor_queue.clear()

func pop_next_actor() -> GachaBallInstance:
	if _actor_queue.is_empty():
		return null
	return _actor_queue.pop_front()

func push_actor_front(unit: GachaBallInstance) -> void:
	_actor_queue.push_front(unit)

func append_actors(units: Array[GachaBallInstance]) -> void:
	_actor_queue.append_array(units)

func insert_actor(index: int, unit: GachaBallInstance) -> void:
	_actor_queue.insert(index, unit)

func has_pending_actors() -> bool:
	return not _actor_queue.is_empty()

func actor_queue_size() -> int:
	return _actor_queue.size()

## Populate the actor queue from battle state at start of combat.
## Players act right-to-left, enemies act left-to-right.
func populate_actor_queue(state: BattleState) -> void:
	_actor_queue.clear()
	state.clear_turn_data() # Reset turn-scoped tracking
	_current_turn_slot_index = -1 # Reset turn slot tracker
	
	var player_lineup := state.get_instances_in_container(&"PlayerLineup")
	var enemy_lineup := state.get_instances_in_container(&"EnemyLineup")
	
	# With FIFO (pop_front), first in = first out
	# Add players in reverse order (right-to-left execution)
	player_lineup.reverse()
	_actor_queue.append_array(player_lineup)
	# Add enemies in normal order (left-to-right execution)
	_actor_queue.append_array(enemy_lineup)

## Grant a unit an extra action by inserting them at the front of the actor queue.
## Called by EffectGrantExtraAction when a unit equipped with Bloodlust Edge gets a kill.
func grant_extra_action_to(unit: GachaBallInstance) -> void:
	if not is_instance_valid(unit):
		return
	if unit.current_hp <= 0:
		return
	_actor_queue.push_front(unit)
	
	# Prevent stacking: If the unit is already at the very front (from a previous trigger in the same chain),
	# don't add it again. This handles multiple Bloodlust items or multi-kill scenarios
	# granting excessive turns.
	if _actor_queue.size() > 1 and _actor_queue[0] == unit and _actor_queue[1] == unit:
		_actor_queue.pop_front()

## Insert a newly summoned unit into the actor queue.
## @param new_unit: The summoned unit
## @param is_player: Whether the unit is on the player team
## @param is_player_unit_callback: Callable to check if a queued unit is on player team
func insert_summoned_unit(new_unit: GachaBallInstance, is_player: bool, is_player_unit_callback: Callable) -> void:
	if not is_instance_valid(new_unit):
		return
	
	var slot_idx := new_unit.location_slot_index
	
	# CRITICAL CHECK: Prevent re-insertion if the slot has already acted or is currently acting
	# Uses persisted turn data because _current_acting_unit might be dead/moved to discard
	if _current_turn_slot_index != -1: # Actively processing a turn
		# Only block if we are inserting into the SAME team that is currently acting
		if _current_turn_is_player == is_player:
			if is_player:
				# Player acts 4 -> 0 (Descending)
				# If new_slot >= current_slot, it means we are replacing the current actor
				# or inserting into a slot that already finished acting.
				if slot_idx >= _current_turn_slot_index:
					return
			else:
				# Enemy acts 0 -> 4 (Ascending)
				# If new_slot <= current_slot, it means we are replacing the current actor
				# or inserting into a slot that already finished acting.
				if slot_idx <= _current_turn_slot_index:
					return
	
	# Find alive same-team units still in queue to determine insertion position
	var found_alive_same_team := false
	for i in range(_actor_queue.size()):
		var queued_unit = _actor_queue[i]
		# Skip dead units - their container tags are unreliable
		if queued_unit.current_hp <= 0:
			continue
		if is_player_unit_callback.call(queued_unit) == is_player:
			found_alive_same_team = true
			# Same team - check if our slot should act before this one
			if is_player:
				# Players: higher slots act first (4,3,2,1,0)
				if slot_idx > queued_unit.location_slot_index:
					_actor_queue.insert(i, new_unit)
					return
			else:
				# Enemies: lower slots act first (0,1,2,3,4)
				if slot_idx < queued_unit.location_slot_index:
					_actor_queue.insert(i, new_unit)
					return
	
	# If we found alive same-team units but didn't insert, add at end of same-team section
	if found_alive_same_team:
		for i in range(_actor_queue.size()):
			var queued_unit = _actor_queue[i]
			if queued_unit.current_hp <= 0:
				continue
			if is_player_unit_callback.call(queued_unit) != is_player:
				# Found where other team starts, insert before
				_actor_queue.insert(i, new_unit)
				return
		# All remaining alive units are same team, append at end
		_actor_queue.append(new_unit)
		return
	
	# No alive same-team units in queue - check if there are DEAD same-team units
	var found_dead_same_team := false
	for queued_unit in _actor_queue:
		if queued_unit.current_hp <= 0:
			found_dead_same_team = true
			break
	
	if found_dead_same_team:
		# Team hasn't finished - dead units are still waiting for their turn
		_actor_queue.append(new_unit)
		return
	
	# No same-team units (alive OR dead) in queue - team has FINISHED acting
	# The slot already had its turn, so the summon should NOT act this turn

# ============================================================================
# REACTION QUEUE MANAGEMENT
# ============================================================================

func get_crr() -> CausalReactionResolver:
	return _crr

func get_pending_reactions() -> Array[EffectRequest]:
	return _crr._pending_reactions

func clear_pending_reactions() -> void:
	_crr.clear()

func has_pending_reactions() -> bool:
	return not _crr.is_empty()

func enqueue_reaction(request: EffectRequest) -> void:
	_crr.enqueue(request)

func sort_reactions_by_priority() -> void:
	_crr.sort_pending()

func _compare_reactions(a: EffectRequest, b: EffectRequest) -> bool:
	return CausalReactionResolver.compare_reactions(a, b)

func _get_category_rank(cat: StringName) -> int:
	return CausalReactionResolver.get_category_rank(cat)

func pop_next_reaction() -> EffectRequest:
	return _crr.pop_front()

# ============================================================================
# INLINE EVENTS
# ============================================================================

func get_inline_events() -> Array[CombatEvent]:
	return _inline_events

func clear_inline_events() -> void:
	_inline_events.clear()

func add_inline_event(event: CombatEvent) -> void:
	_inline_events.append(event)

func has_inline_events() -> bool:
	return not _inline_events.is_empty()

# ============================================================================
# PROCESSING STATE
# ============================================================================

func is_processing() -> bool:
	return _processing_effect_count > 0

func set_processing(value: bool) -> void:
	if value:
		_processing_effect_count += 1
	else:
		_processing_effect_count = maxi(0, _processing_effect_count - 1)

# ============================================================================
# COMBAT TURN EXECUTION
# ============================================================================

## Execute a full combat turn. Orchestrates actor queue and reaction loops.
## Calls back to battle_manager for effect resolution and attack enqueuing.
## Returns the complete turn log as Array[CombatEvent].
func execute_combat_turn(battle_manager, death_tracking: Dictionary) -> Array[CombatEvent]:
	var turn_log: Array[CombatEvent] = []
	
	while not _actor_queue.is_empty():
		var current_actor: GachaBallInstance = _actor_queue.pop_front()
		_current_acting_unit = current_actor
		
		if not is_instance_valid(current_actor):
			continue
		
		if current_actor.current_hp <= 0:
			continue
		
		# Robust Turn Tracking: Snapshot slot/team BEFORE execution (in case unit dies/moves)
		_current_turn_slot_index = current_actor.location_slot_index
		_current_turn_is_player = battle_manager._is_player_unit(current_actor)
		
		# 1. Fire on_before_turn_action trigger (e.g. for Mimic transformation)
		AbilityResolver.process_trigger(&"on_before_turn_action", {"actor_uuid": current_actor.ball_uuid})
		CombatCommand.append_unified_events(turn_log, process_reaction_queue(battle_manager, death_tracking))
		
		# 2. In case the unit was replaced (e.g. by Mimic), update current_actor
		var container_tag: StringName = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if _current_turn_is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		var slot_index: int = _current_turn_slot_index
		var container = battle_manager.get_container(container_tag)
		if is_instance_valid(container) and slot_index >= 0:
			var new_uuid = container.get_uuid(slot_index)
			if not new_uuid.is_empty():
				var new_actor = battle_manager.get_instance_by_uuid(new_uuid)
				if is_instance_valid(new_actor) and new_actor != current_actor:
					current_actor = new_actor
					_current_acting_unit = current_actor
					
		if not is_instance_valid(current_actor) or current_actor.current_hp <= 0:
			continue
			
		# Enqueue attack for this actor
		battle_manager._enqueue_attack_for(current_actor)
		
		# Process all reactions (including on_kill triggers from the attack)
		CombatCommand.append_unified_events(turn_log, process_reaction_queue(battle_manager, death_tracking))
		
		# Check battle-over AFTER all reactions for this actor
		if battle_manager._is_battle_over():
			battle_manager._battle_over_deferred = true
			_actor_queue.clear()
			break
	
	# Final reaction drain - process remaining reactions after all actors
	CombatCommand.append_unified_events(turn_log, process_reaction_queue(battle_manager, death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns on last action)
	# are caught and released immediately.
	battle_manager._check_for_deaths_with_counter_delay(true, turn_log, death_tracking)
	battle_manager._process_completed_counter_deaths(turn_log, death_tracking)
	
	return turn_log

## Process the pending reaction queue until empty.
## Handles priority sorting, effect resolution, inline events, and deferred deaths.
## This ensures consistent behavior across all battle phases (Combat, Management, Start of Turn).
func process_reaction_queue(battle_manager, death_tracking: Dictionary) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	
	while not _crr.is_empty():
		var current_reaction = _crr.pop_front()
		
		var reaction_events: Array[CombatEvent] = []
		resolve_effect_request(current_reaction, reaction_events, death_tracking, battle_manager)
		_tag_trinket_events(reaction_events, current_reaction, battle_manager)
		
		# Collect inline events (e.g. self-damage, heals, lethal saves triggered during resolution)
		var inline_evts = collect_and_clear_inline_events()
		CombatCommand.append_unified_events(events, inline_evts)
		
		CombatCommand.append_unified_events(events, reaction_events)
		
		# Process deferred deaths immediately to ensure correct ordering (e.g. before next reaction)
		var deferred_death_events: Array[CombatEvent] = []
		battle_manager._process_completed_counter_deaths(deferred_death_events, death_tracking)
		CombatCommand.append_unified_events(events, deferred_death_events)
		
	return events

# ============================================================================
# EFFECT RESOLUTION (Moved from BattleManager)
# ============================================================================

func build_commands(
	effect_result: EffectResult,
	request: EffectRequest,
	combat_sim: CombatSimulator,
	bm: Node
) -> Array[CombatCommand]:
	var commands: Array[CombatCommand] = []
	
	if effect_result.damage_request != null:
		commands.append(DamageCommand.new(request, combat_sim, bm, effect_result.damage_request))
	
	if effect_result.cascade_request != null:
		commands.append(CascadeCommand.new(request, combat_sim, bm, effect_result.cascade_request))
	
	if effect_result.kamikaze_request != null:
		commands.append(KamikazeCommand.new(request, combat_sim, bm, effect_result.kamikaze_request))
	
	if not effect_result.summon_request.is_empty():
		commands.append(SummonCommand.new(request, combat_sim, bm, effect_result.summon_request))
	
	if not effect_result.summon_units_request.is_empty():
		commands.append(SummonUnitsCommand.new(request, combat_sim, bm, effect_result))
	
	if not effect_result.transform_request.is_empty():
		commands.append(TransformCommand.new(request, combat_sim, bm, effect_result.transform_request))
	
	if commands.is_empty() or not effect_result.events.is_empty():
		commands.append(EventsOnlyCommand.new(request, combat_sim, bm, effect_result))
	
	return commands

## Resolve a single effect request. This is the core effect execution logic.
## @param request: The effect request to resolve
## @param out_events: Array to append generated events to
## @param death_tracking: Dictionary for death deduplication
## @param bm: BattleManager reference for state access
func resolve_effect_request(request: EffectRequest, out_events: Array[CombatEvent], death_tracking: Dictionary, bm) -> void:
	# SYSTEM TRAP: Handle delayed trait effects
	if request.ability_id == "trait_start_effects":
		out_events.append_array(bm._apply_trait_start_of_turn_effects())
		return
	
	# Validate source is still alive (allow empty source UUID for trinket effects)
	var source = null
	if not request.source_uuid.is_empty():
		source = bm.get_instance_by_uuid(request.source_uuid)
		if not is_instance_valid(source):
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
			
			# Check if ability has execute_on_lethal flag via AbilitiesRegistry or source instance
			var is_reactive_ability: bool = false
			var ability_def = bm._get_ability_definition(request.ability_id, source)
			if is_instance_valid(ability_def) and ability_def.execute_on_lethal:
				is_reactive_ability = true
			
			if not is_own_death_trigger and not is_reactive_ability:
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
		var target_inst = bm.get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_inst) and target_inst.current_hp > 0:
			# Also verify the target is still in an active battle container (not discard/removed)
			var loc_tag: StringName = target_inst.location_container_tag
			var is_in_battle: bool = (loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
								 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
								 loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH or
								 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH)
			if is_in_battle:
				valid_targets.append(target_uuid)
	
	# Allow targetless effects (e.g., summons) to proceed
	# They will provide their own targets in the return data
	# Only abort if we EXPECTED targets but they're all invalid
	if valid_targets.is_empty() and not exec_targets.is_empty():
		# LAZY RETARGETING: If all targets died/vanished, try to find new ones
		# This fixes chains where multiple reactions targeting the same unit fail after the first kills it
		if is_instance_valid(request.effect_definition):
			var new_targets = bm.resolve_target(request.source_uuid, request.effect_definition.target_type, request.trigger_context)
			# Validate the new targets
			for nt in new_targets:
				var nt_inst = bm.get_instance_by_uuid(nt)
				if is_instance_valid(nt_inst) and nt_inst.current_hp > 0:
					var loc_tag = nt_inst.location_container_tag
					var is_in_battle = (loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
										loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
					if is_in_battle:
						valid_targets.append(nt)

		# If STILL empty after retargeting attempts, then we abort
		if valid_targets.is_empty():
			return
	
	exec_targets = valid_targets
	
	# For basic attacks only, apply retargeting to frontmost if needed
	if is_basic_attack and exec_targets.size() > 0:
		var first_target = bm.get_instance_by_uuid(exec_targets[0])
		if not is_instance_valid(first_target) or first_target.current_hp <= 0:
			var attacker_is_player: bool = false
			if is_instance_valid(source):
				attacker_is_player = bm._is_player_unit(source)
			var new_target_inst = bm._get_frontmost_target(attacker_is_player)
			if is_instance_valid(new_target_inst):
				exec_targets[0] = new_target_inst.ball_uuid
			else:
				return
	# Execute without emitting UI; capture results for events
	var _damage := 0
	if is_instance_valid(request.effect_definition):
		var sim_ctx = request.trigger_context.duplicate(true)
		sim_ctx["is_simulation"] = true
		sim_ctx["ability_id"] = request.ability_id
		
		# Zero-Instance-Query Compliance: Pre-populate source data
		# This allows effects to use context data instead of querying instances
		# Data is snapshotted at the EXACT moment before execute(), reflecting current simulation state
		if is_instance_valid(source):
			var source_def = source.get_definition()
			var stat_provider = source # Default: use source's own stats
			
			if is_instance_valid(source_def):
				if not sim_ctx.has("source_category") or sim_ctx["source_category"] == &"":
					sim_ctx["source_category"] = source_def.category
				
				# For items, use the HOLDER's stats (not the item's stats which are 0)
				# Also include holder UUID so effects can identify the attacker
				if source_def.category == &"ITEM" and not source.equipped_on_uuid.is_empty():
					sim_ctx["source_holder_uuid"] = source.equipped_on_uuid
		# Context enrichment
		var stat_provider = bm.get_instance_by_uuid(request.source_uuid)
		if is_instance_valid(stat_provider):
			if not sim_ctx.has("source_category") or sim_ctx["source_category"] == &"":
				sim_ctx["source_category"] = stat_provider.get_definition().category if is_instance_valid(stat_provider.get_definition()) else &""
			sim_ctx["source_holder_uuid"] = stat_provider.equipped_on_uuid if sim_ctx["source_category"] == &"ITEM" else ""
			if stat_provider.current_hp <= 0 and request.trigger_context.has("source_pwr"):
				sim_ctx["source_pwr"] = request.trigger_context["source_pwr"]
			else:
				sim_ctx["source_pwr"] = stat_provider.current_pwr
			sim_ctx["source_hp"] = stat_provider.current_hp
		
		var _effect_script_path = request.effect_definition.get_script().resource_path if request.effect_definition.get_script() else "no_script"
		var res = request.effect_definition.execute(request.source_uuid, exec_targets, bm, sim_ctx)
		
		var before_attack_inline_evts = collect_and_clear_inline_events()
		CombatCommand.append_unified_events(out_events, before_attack_inline_evts)
		
		# --- NEW: COMMAND PATTERN ---
		var effect_result: EffectResult = res as EffectResult
		if effect_result == null:
			effect_result = EffectResult.empty()
		
		var commands = build_commands(effect_result, request, self, bm)
		for cmd in commands:
			cmd.execute(out_events, death_tracking)
		
		if not effect_result.skip_death_check and commands.is_empty():
			bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)

# ============================================================================
# CRR PHASE-AWARE & SCOPED REACTION DRAINING
# ============================================================================

## Begin a reaction scope. Any reactions enqueued after this call will belong
## to this scope until drained via drain_reaction_scope().
func begin_reaction_scope() -> int:
	return _crr.begin_scope()

## Drain and resolve all reactions enqueued within the specified scope.
## Handles cascades recursively and returns the captured CombatEvents.
func drain_reaction_scope(scope_id: int, bm) -> Array[CombatEvent]:
	var requests = _crr.drain_scope(scope_id)
	if requests.is_empty():
		return []
	
	var captured_events: Array[CombatEvent] = []
	for request in requests:
		var inline_start_index := captured_events.size()
		var nested_scope = _crr.begin_scope()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		var nested_events = drain_reaction_scope(nested_scope, bm)
		if not nested_events.is_empty():
			CombatCommand.append_unified_events(captured_events, nested_events)
			
	return captured_events

## Drain all Interception reactions (Priority >= 300) using CRR.
## Returns generated CombatEvents.
func drain_interceptions(bm) -> Array[CombatEvent]:
	var intercept_requests = _crr.drain_interceptions()
	if intercept_requests.is_empty():
		return []
	
	var captured_events: Array[CombatEvent] = []
	for request in intercept_requests:
		var inline_start_index := captured_events.size()
		var nested_scope = _crr.begin_scope()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		var nested_events = drain_reaction_scope(nested_scope, bm)
		if not nested_events.is_empty():
			CombatCommand.append_unified_events(captured_events, nested_events)
			
	return captured_events

## Drain ONLY execute_on_lethal reactions using CRR.
## Returns the generated CombatEvents directly.
func drain_lethal_counters(bm) -> Array[CombatEvent]:
	var lethal_requests = _crr.drain_lethal_counters(bm)
	if lethal_requests.is_empty():
		return []
	
	var captured_events: Array[CombatEvent] = []
	for request in lethal_requests:
		var inline_start_index := captured_events.size()
		var nested_scope = _crr.begin_scope()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		var nested_events = drain_reaction_scope(nested_scope, bm)
		if not nested_events.is_empty():
			CombatCommand.append_unified_events(captured_events, nested_events)
			
	return captured_events

## Drain all remaining reactions in the queue in strict 3-Layer priority order.
## Returns generated CombatEvents.
func drain_cascade(bm) -> Array[CombatEvent]:
	var captured_events: Array[CombatEvent] = []
	while not _crr.is_empty():
		var request = _crr.pop_front()
		if request == null:
			break
		var inline_start_index := captured_events.size()
		var nested_scope = _crr.begin_scope()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		var nested_events = drain_reaction_scope(nested_scope, bm)
		if not nested_events.is_empty():
			CombatCommand.append_unified_events(captured_events, nested_events)
			
	return captured_events

# ============================================================================
# LEGACY DRAIN BRIDGES (Deprecated: preserved for backward-compatibility)
# ============================================================================

## Drain pending reactions inline during effect execution (legacy wrapper).
func drain_reactions_inline(start_index: int, bm) -> void:
	var evts = drain_and_capture_reactions_inline(start_index, bm)
	_inline_events.append_array(evts)

func drain_and_capture_reactions_inline(start_index: int, bm) -> Array[CombatEvent]:
	if start_index >= _crr.size():
		return []
	
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _crr.size()):
		reactions_to_process.append(_crr._pending_reactions[i])
	
	_crr._pending_reactions.resize(start_index)
	reactions_to_process.sort_custom(CausalReactionResolver.compare_reactions)
	
	var captured_events: Array[CombatEvent] = []
	for request in reactions_to_process:
		var inline_start_index := captured_events.size()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		if not _crr.is_empty():
			captured_events.append_array(drain_and_capture_reactions_inline(start_index, bm))
			
	return captured_events

## Drain ONLY execute_on_lethal reactions (legacy wrapper).
func drain_lethal_reactions(start_index: int, bm) -> void:
	var evts = drain_lethal_counters(bm)
	_inline_events.append_array(evts)

## Collect and clear inline events. Returns the collected events.
func collect_and_clear_inline_events() -> Array[CombatEvent]:
	var events = _inline_events.duplicate()
	_inline_events.clear()
	return events

# ============================================================================
# SUMMON TRIGGER HELPER
# ============================================================================

## Trigger on_enemy_summon for each new unit in a summon result.
## Drains reactions immediately to ensure ambush abilities execute before the summoned unit acts.
## NOTE: Only triggers during COMBAT phase - summons during START_OF_TURN or END_OF_TURN are ignored.
## @param summon_result: The SummonResult from EffectHandlers
## @param out_events: Array to append generated events to
## @param bm: BattleManager reference
func _trigger_summon_reactions_for_result(summon_result: EffectHandlers.SummonResult, out_events: Array[CombatEvent], bm) -> void:
	var is_combat_phase: bool = bm.get_current_phase_name() == &"COMBAT"
	
	# For each new instance, trigger summon reactions
	for i in range(summon_result.new_instances.size()):
		var new_inst: GachaBallInstance = summon_result.new_instances[i]
		
		# Determine team from container tag
		var summoned_team := ""
		if i < summon_result.container_updates.size():
			var container_tag: StringName = summon_result.container_updates[i].container_tag
			if container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
				summoned_team = "PLAYER"
			elif container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
				summoned_team = "ENEMY"
		
		# Skip if we can't determine team
		if summoned_team.is_empty():
			continue
		
		# Create location for context
		var summoned_location: LocationIdentifier = null
		if i < summon_result.container_updates.size():
			summoned_location = LocationIdentifier.new()
			summoned_location.container = summon_result.container_updates[i].container_tag
			summoned_location.index = summon_result.container_updates[i].slot
		
		# Trigger on_ally_summon in ALL phases (for abilities like Summon Blessing, Royal/Veteran Insignia)
		TurnAbilities.trigger_on_ally_summon(new_inst.ball_uuid, summoned_team, summoned_location)

		# Trigger on_board_changed for passive scaling abilities (like Twin Charm) mid-combat
		AbilityResolver.process_trigger(&"on_board_changed", {"is_simulation": true})

		# Trigger on_enemy_summon ONLY during combat phase (for abilities like Ambush Predator)
		if is_combat_phase:
			TurnAbilities.trigger_on_enemy_summon(new_inst.ball_uuid, summoned_team, summoned_location)
		
		# Drain reactions immediately so summon abilities execute before the summoned unit acts
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(_compare_reactions)
			var reaction = _pending_reactions.pop_front()
			
			var reaction_events: Array[CombatEvent] = []
			resolve_effect_request(reaction, reaction_events, {}, bm)
			_tag_trinket_events(reaction_events, reaction, bm)
			
			# Collect inline events
			var inline_evts = collect_and_clear_inline_events()
			CombatCommand.append_unified_events(out_events, inline_evts)
			CombatCommand.append_unified_events(out_events, reaction_events)

func _tag_trinket_events(events: Array[CombatEvent], request: EffectRequest, bm, start_index: int = 0) -> void:
	if request.source_uuid.is_empty():
		return
	var source: GachaBallInstance = bm.get_instance_by_uuid(request.source_uuid)
	if not is_instance_valid(source):
		return
	var definition := source.get_definition()
	if not is_instance_valid(definition) or not ("category" in definition) or definition.category != &"TRINKET":
		return
	var visual_uuid := source.origin_uuid if not source.origin_uuid.is_empty() else source.ball_uuid
	var is_enemy_trinket := source.location_container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS
	var has_visual_event := false
	for i in range(start_index, events.size()):
		var candidate := events[i]
		if is_instance_valid(candidate) and candidate.type != CombatEvent.Type.LOG_MESSAGE:
			has_visual_event = true
			break
			
	for i in range(start_index, events.size()):
		var event := events[i]
		if not is_instance_valid(event):
			continue
		if event.type == CombatEvent.Type.LOG_MESSAGE and has_visual_event:
			continue
		# FIX: Only tag events that actually originated from this trinket!
		if event.ability_holder_uuid != request.source_uuid:
			continue
			
		event.trinket_activations.append(CombatTrinketActivation.new(source.definition_id, is_enemy_trinket, visual_uuid))

# ============================================================================
# CLEANUP
# ============================================================================

func _make_spikes_payloads(raw_spikes_data: Array[Dictionary]) -> Array[CombatSpikesData]:
	var result: Array[CombatSpikesData] = []
	for raw_data in raw_spikes_data:
		var spikes_data := CombatSpikesData.new()
		spikes_data.attacker_uuid = String(raw_data.get("attacker_uuid", ""))
		spikes_data.defender_uuid = String(raw_data.get("defender_uuid", ""))
		spikes_data.spikes_damage = int(raw_data.get("spikes_damage", 0))
		spikes_data.attacker_old_hp = int(raw_data.get("attacker_old_hp", 0))
		spikes_data.attacker_new_hp = int(raw_data.get("attacker_new_hp", 0))
		spikes_data.attacker_max_hp = int(raw_data.get("attacker_max_hp", 0))
		spikes_data.old_spikes = int(raw_data.get("old_spikes", 0))
		spikes_data.new_spikes = int(raw_data.get("new_spikes", 0))
		spikes_data.armor_consumed = int(raw_data.get("armor_consumed", 0))
		spikes_data.new_armor = int(raw_data.get("new_armor", 0))
		result.append(spikes_data)
	return result

func clear() -> void:
	_actor_queue.clear()
	_crr.clear()
	_inline_events.clear()
	_processing_effect_count = 0
