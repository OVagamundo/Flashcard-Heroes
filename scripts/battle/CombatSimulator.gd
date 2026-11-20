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
var _current_turn_step: int = -1

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

## Returns the absolute step in the alternating combat sequence for a given slot and team.
## Alternates rank by rank starting with the enemy:
##   Enemy Slot 0 (Rank 0) -> 0
##   Player Slot 4 (Rank 0) -> 1
##   Enemy Slot 1 (Rank 1) -> 2
##   Player Slot 3 (Rank 1) -> 3
##   Enemy Slot 2 (Rank 2) -> 4
##   Player Slot 2 (Rank 2) -> 5
##   Enemy Slot 3 (Rank 3) -> 6
##   Player Slot 1 (Rank 3) -> 7
##   Enemy Slot 4 (Rank 4) -> 8
##   Player Slot 0 (Rank 4) -> 9
static func get_unit_action_step(slot_index: int, is_player: bool, max_slots: int = C.LINEUP_CAP) -> int:
	var rank: int = (max_slots - 1 - slot_index) if is_player else slot_index
	return (rank * 2) + (1 if is_player else 0)

## Populate the actor queue from battle state at start of combat.
## Alternates rank by rank starting with the enemy:
##   Rank 0: Enemy Slot 0 -> Player Slot 4
##   Rank 1: Enemy Slot 1 -> Player Slot 3
##   Rank 2: Enemy Slot 2 -> Player Slot 2
##   Rank 3: Enemy Slot 3 -> Player Slot 1
##   Rank 4: Enemy Slot 4 -> Player Slot 0
## Empty slots are naturally skipped so frontloaded formations act before backloaded units.
func populate_actor_queue(state: BattleState) -> void:
	_actor_queue.clear()
	state.clear_turn_data() # Reset turn-scoped tracking
	_current_turn_slot_index = -1 # Reset turn slot tracker
	_current_turn_is_player = false
	_current_turn_step = -1
	
	_actor_queue.assign(starting_actors(state))

static func starting_actors(state: BattleState) -> Array[GachaBallInstance]:
	var actors: Array[GachaBallInstance] = []
	var player_container = state.get_container(&"PlayerLineup")
	var enemy_container = state.get_container(&"EnemyLineup")
	
	for rank in range(C.LINEUP_CAP):
		# 1. Enemy slot for this rank (0 -> 4)
		var enemy_slot: int = rank
		if is_instance_valid(enemy_container):
			var enemy_uuid: String = enemy_container.get_uuid(enemy_slot)
			if not enemy_uuid.is_empty():
				var enemy_inst: GachaBallInstance = state.get_instance(enemy_uuid)
				if is_instance_valid(enemy_inst) and enemy_inst.current_hp > 0:
					actors.append(enemy_inst)
		
		# 2. Player slot for this rank (4 -> 0)
		var player_slot: int = (C.LINEUP_CAP - 1) - rank
		if is_instance_valid(player_container):
			var player_uuid: String = player_container.get_uuid(player_slot)
			if not player_uuid.is_empty():
				var player_inst: GachaBallInstance = state.get_instance(player_uuid)
				if is_instance_valid(player_inst) and player_inst.current_hp > 0:
					actors.append(player_inst)
	return actors

static func actor_order(actors: Array[GachaBallInstance]) -> Array[String]:
	var order: Array[String] = []
	for actor: GachaBallInstance in actors:
		if actor != null and actor.current_hp > 0 and not order.has(actor.ball_uuid):
			order.append(actor.ball_uuid)
	return order

func _record_actor_order(events: Array[CombatEvent]) -> void:
	var event := CombatEvent.new(CombatEvent.Type.ACTOR_ORDER)
	event.target_uuids = actor_order(_actor_queue)
	events.append(event)

## Grant a unit an extra action by inserting them at the front of the actor queue.
## Called by EffectGrantExtraAction when a unit equipped with Scythe gets a knockout.
func grant_extra_action_to(unit: GachaBallInstance) -> void:
	if not is_instance_valid(unit):
		return
	if unit.current_hp <= 0:
		return
	_actor_queue.push_front(unit)
	
	# Prevent stacking: If the unit is already at the very front (from a previous trigger in the same chain),
	# don't add it again. This handles multiple Scythes or multi-kill scenarios
	# granting excessive turns.
	if _actor_queue.size() > 1 and _actor_queue[0] == unit and _actor_queue[1] == unit:
		_actor_queue.pop_front()

## Insert a newly summoned unit into the actor queue.
## A summoned unit acts in the current combat turn ONLY if its slot rank has not yet acted
## in the alternating sequence. If eligible, it is inserted into the queue at its proper sequence step.
## @param new_unit: The summoned unit
## @param is_player: Whether the unit is on the player team
## @param is_player_unit_callback: Callable to check if a queued unit is on player team
func insert_summoned_unit(new_unit: GachaBallInstance, is_player: bool, is_player_unit_callback: Callable) -> void:
	if not is_instance_valid(new_unit) or new_unit.current_hp <= 0:
		return
	
	var container_tag: StringName = new_unit.location_container_tag
	if container_tag != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return
		
	var slot_idx: int = new_unit.location_slot_index
	if slot_idx < 0 or slot_idx >= C.LINEUP_CAP:
		return
		
	if _actor_queue.has(new_unit):
		return
		
	var new_step: int = get_unit_action_step(slot_idx, is_player)
	
	# Only act this round if this slot's step in the alternating sequence has not yet occurred
	if _current_turn_step != -1 and new_step <= _current_turn_step:
		return
		
	var inserted := false
	for i in range(_actor_queue.size()):
		var queued_unit: GachaBallInstance = _actor_queue[i]
		if not is_instance_valid(queued_unit):
			continue
		var queued_is_player: bool = is_player_unit_callback.call(queued_unit)
		var queued_step: int = get_unit_action_step(queued_unit.location_slot_index, queued_is_player)
		
		# If a queued unit has step <= _current_turn_step, it was pushed to the front for an extra action (e.g. Scythe).
		# Extra actions take immediate priority, so do not insert before them.
		if _current_turn_step != -1 and queued_step <= _current_turn_step:
			continue
			
		if new_step < queued_step:
			_actor_queue.insert(i, new_unit)
			inserted = true
			break
			
	if not inserted:
		_actor_queue.append(new_unit)

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

func sort_reactions_by_sub_phase() -> void:
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
	_record_actor_order(turn_log)
	
	while not _actor_queue.is_empty():
		# STABILITY GATE: Flush all deaths from previous reaction cascades before popping the next actor
		battle_manager._check_for_deaths_with_counter_delay(true, turn_log, death_tracking)
		battle_manager._process_completed_counter_deaths(turn_log, death_tracking)
		
		var current_actor: GachaBallInstance = _actor_queue.pop_front()
		_current_acting_unit = current_actor
		
		if not is_instance_valid(current_actor):
			continue
		
		if current_actor.current_hp <= 0:
			continue
		
		# Robust Turn Tracking: Snapshot slot/team BEFORE execution (in case unit dies/moves)
		_current_turn_slot_index = current_actor.location_slot_index
		_current_turn_is_player = battle_manager._is_player_unit(current_actor)
		if _current_turn_slot_index >= 0:
			var step: int = get_unit_action_step(_current_turn_slot_index, _current_turn_is_player)
			_current_turn_step = maxi(_current_turn_step, step)
		
		# 1. Fire on_before_turn_action trigger (e.g. for Mimic transformation)
		var before_turn_ctx := TriggerContext.new()
		before_turn_ctx.actor_uuid = current_actor.ball_uuid
		AbilityResolver.process_trigger(C.TRIGGER_BEFORE_TURN_ACTION, before_turn_ctx)
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
		_record_actor_order(turn_log)
	
	# Final reaction drain - process remaining reactions after all actors
	CombatCommand.append_unified_events(turn_log, process_reaction_queue(battle_manager, death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns on last action)
	# are caught and released immediately.
	battle_manager._check_for_deaths_with_counter_delay(true, turn_log, death_tracking)
	battle_manager._process_completed_counter_deaths(turn_log, death_tracking)
	if not _crr.is_empty():
		CombatCommand.append_unified_events(turn_log, process_reaction_queue(battle_manager, death_tracking))
	var final_inline := collect_and_clear_inline_events()
	if not final_inline.is_empty():
		CombatCommand.append_unified_events(turn_log, final_inline)
	
	turn_log.append_array(battle_manager.take_inventory_events())
	_record_actor_order(turn_log)
	return turn_log

## Process the pending reaction queue until empty.
## Handles priority sorting, effect resolution, inline events, and deferred deaths.
## This ensures consistent behavior across all battle phases (Combat, Management, Start of Turn).
func process_reaction_queue(battle_manager, death_tracking: Dictionary) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = battle_manager.take_inventory_events()
	
	while not _crr.is_empty():
		var current_reaction = _crr.pop_front()
		
		var reaction_events: Array[CombatEvent] = []
		resolve_effect_request(current_reaction, reaction_events, death_tracking, battle_manager)
		_tag_trinket_events(reaction_events, current_reaction, battle_manager)
		
		# Collect inline events (e.g. self-damage, heals, lethal saves triggered during resolution)
		var inline_evts = collect_and_clear_inline_events()
		CombatCommand.append_unified_events(events, inline_evts)
		
		events.append_array(battle_manager.take_inventory_events())
		CombatCommand.append_unified_events(events, reaction_events)
		
		# Process deferred deaths immediately to ensure correct ordering (e.g. before next reaction)
		var deferred_death_events: Array[CombatEvent] = []
		battle_manager._process_completed_counter_deaths(deferred_death_events, death_tracking)
		CombatCommand.append_unified_events(events, deferred_death_events)
		
		# Immediately resolve any cascading deaths triggered by completed counter-attacks
		battle_manager._check_for_deaths_with_counter_delay(true, events, death_tracking)
		
	events.append_array(battle_manager.take_inventory_events())
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
	
	if effect_result.pre_knockout_attack_request != null:
		commands.append(PreKnockoutAttackCommand.new(request, combat_sim, bm, effect_result.pre_knockout_attack_request))
	
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
			var ko_uuid: String = request.trigger_context.knocked_out_uuid
			var is_own_death_trigger: bool = (ko_uuid == request.source_uuid)
			
			# Check if ability has execute_before_knockout flag via AbilitiesRegistry or source instance
			var is_reactive_ability: bool = false
			var ability_def = bm._get_ability_definition(request.ability_id, source)
			if is_instance_valid(ability_def) and ability_def.execute_before_knockout:
				is_reactive_ability = true
			
			if not is_own_death_trigger and not is_reactive_ability:
				return

	# Prepare execution targets from resolved targets. Only basic attacks may dynamically retarget.
	var exec_targets: Array[String] = []
	exec_targets.append_array(request.resolved_targets)
	var is_basic_attack := (request.ability_id == &"basic_attack" or String(request.ability_id).begins_with("basic_attack"))
	
	# For ALL abilities (basic or triggered), validate targets are still alive AND in battle
	# Filter out dead targets to prevent ghost attacks
	# NOTE: Must check location_container_tag because reset_battle_stats_silent() restores HP before discard
	var valid_targets: Array[String] = []
	var is_knockout_trigger: bool = (
		request.trigger_context.trigger_type == C.TRIGGER_WHEN_KNOCKED_OUT
		or request.trigger_context.trigger_type == C.TRIGGER_BEFORE_BEING_KNOCKED_OUT
	)
	var allow_dying_target: bool = is_knockout_trigger and is_instance_valid(request.effect_definition) and request.effect_definition.get("target_type") == &"ALLY_BEHIND"
	for target_uuid in exec_targets:
		var target_inst = bm.get_instance_by_uuid(target_uuid)
		if is_instance_valid(target_inst):
			var t_def = target_inst.get_definition()
			var is_trinket: bool = is_instance_valid(t_def) and t_def.category == &"TRINKET"
			var is_dying_subject: bool = is_knockout_trigger and (target_uuid == request.trigger_context.knocked_out_uuid or target_uuid == request.source_uuid)
			var is_target_alive_or_chaining: bool = is_trinket or (target_inst.current_hp > 0 or is_dying_subject or (allow_dying_target and target_inst.location_container_tag != C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE and target_inst.location_container_tag != C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD and target_inst.location_container_tag != &""))
			if is_target_alive_or_chaining:
				# Also verify the target is still in an active battle container (not discard/removed)
				var loc_tag: StringName = target_inst.location_container_tag
				var is_in_battle: bool = (loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS or
									 loc_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER)
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
	
	# For basic attacks only, apply retargeting if needed
	if is_basic_attack and exec_targets.size() > 0:
		var first_target = bm.get_instance_by_uuid(exec_targets[0])
		if not is_instance_valid(first_target) or first_target.current_hp <= 0:
			var target_type = C.TARGET_FRONTMOST_ENEMY
			if is_instance_valid(request.effect_definition) and request.effect_definition.target_type != &"":
				target_type = request.effect_definition.target_type
			var new_targets = bm.resolve_target(request.source_uuid, target_type, request.trigger_context)
			if not new_targets.is_empty():
				exec_targets[0] = new_targets[0]
			else:
				return
	# Execute without emitting UI; capture results for events
	var _damage := 0
	if is_instance_valid(request.effect_definition):
		var sim_ctx: TriggerContext = request.trigger_context.duplicate_context()
		sim_ctx.is_simulation = true
		sim_ctx.ability_id = request.ability_id
		
		# Zero-Instance-Query Compliance: Pre-populate source data
		# This allows effects to use context data instead of querying instances
		# Data is snapshotted at the EXACT moment before execute(), reflecting current simulation state
		if is_instance_valid(source):
			var source_def = source.get_definition()
			
			if is_instance_valid(source_def):
				if sim_ctx.source_category == &"":
					sim_ctx.source_category = source_def.category
				
				# For items, use the HOLDER's stats (not the item's stats which are 0)
				# Also include holder UUID so effects can identify the attacker
				if source_def.category == &"ITEM" and not source.equipped_on_uuid.is_empty():
					sim_ctx.source_holder_uuid = source.equipped_on_uuid
		# Context enrichment
		var stat_provider = bm.get_instance_by_uuid(request.source_uuid)
		if is_instance_valid(stat_provider):
			if sim_ctx.source_category == &"":
				sim_ctx.source_category = stat_provider.get_definition().category if is_instance_valid(stat_provider.get_definition()) else &""
			sim_ctx.source_holder_uuid = stat_provider.equipped_on_uuid if sim_ctx.source_category == &"ITEM" else ""
			if sim_ctx.source_category == &"ITEM" and not stat_provider.equipped_on_uuid.is_empty():
				var item_holder: GachaBallInstance = bm.get_instance_by_uuid(stat_provider.equipped_on_uuid)
				assert(item_holder != null, "CombatSimulator: equipped item holder is not registered")
				sim_ctx.source_pwr = item_holder.current_pwr
				sim_ctx.source_hp = item_holder.current_hp
			elif sim_ctx.source_category == &"ITEM" and not request.trigger_context.knocked_out_uuid.is_empty():
				sim_ctx.source_holder_uuid = request.trigger_context.knocked_out_uuid
				if request.trigger_context.source_pwr >= 0:
					sim_ctx.source_pwr = request.trigger_context.source_pwr
					sim_ctx.source_hp = request.trigger_context.source_hp
			elif stat_provider.current_hp <= 0 and request.trigger_context.source_pwr >= 0:
				sim_ctx.source_pwr = request.trigger_context.source_pwr
				sim_ctx.source_hp = request.trigger_context.source_hp
			elif sim_ctx.source_category != &"ITEM":
				sim_ctx.source_pwr = stat_provider.current_pwr
				sim_ctx.source_hp = stat_provider.current_hp
		
		var _effect_script_path = request.effect_definition.get_script().resource_path if request.effect_definition.get_script() else "no_script"
		var res: EffectResult = request.effect_definition.execute(request.source_uuid, exec_targets, bm, sim_ctx)
		if sim_ctx.double_strike_executed:
			request.trigger_context.double_strike_executed = true
		
		var before_attack_inline_evts = collect_and_clear_inline_events()
		CombatCommand.append_unified_events(out_events, before_attack_inline_evts)
		
		# --- NEW: COMMAND PATTERN ---
		var effect_result: EffectResult = res as EffectResult
		if effect_result == null:
			effect_result = EffectResult.empty()
		
		var commands = build_commands(effect_result, request, self, bm)
		for cmd in commands:
			cmd.execute(out_events, death_tracking)
		
		var after_cmd_inline_evts = collect_and_clear_inline_events()
		if not after_cmd_inline_evts.is_empty():
			CombatCommand.append_unified_events(out_events, after_cmd_inline_evts)
		
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

## Drain and resolve only reactions in scope_id matching predicate, leaving scope_id open.
func drain_reaction_scope_matching(scope_id: int, predicate: Callable, bm) -> Array[CombatEvent]:
	var requests = _crr.drain_scope_matching(scope_id, predicate)
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

## Adopt existing pending reactions matching predicate into an active scope.
func adopt_into_reaction_scope(scope_id: int, predicate: Callable) -> void:
	_crr.adopt_into_scope(scope_id, predicate)

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

## Drain ONLY execute_before_knockout reactions using CRR.
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
func _trigger_summon_reactions_for_result(summon_result: EffectHandlers.SummonResult, out_events: Array[CombatEvent], bm, summon_scope: int = -1) -> void:
	var is_combat_phase: bool = bm.get_current_phase_name() == &"COMBAT"
	var outer_scope: int = summon_scope if summon_scope != -1 else begin_reaction_scope()
	
	# For each new instance, trigger summon reactions in a dedicated sub-scope
	for i in range(summon_result.new_instances.size()):
		var new_inst: GachaBallInstance = summon_result.new_instances[i]
		
		# Determine team from container tag
		var summoned_team := ""
		if i < summon_result.container_updates.size():
			var container_tag: StringName = summon_result.container_updates[i].container_tag
			if container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF:
				summoned_team = "PLAYER"
			elif container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_SHELF:
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
		
		var unit_summon_scope: int = begin_reaction_scope()
		
		# Trigger on_ally_summon in ALL phases (for abilities like Summon Blessing, Royal/Veteran Insignia)
		TurnAbilities.trigger_on_ally_summon(new_inst.ball_uuid, summoned_team, summoned_location)

		# Trigger on_board_state_changed for passive scaling abilities (like Twin Charm) mid-combat
		var board_ctx := TriggerContext.new()
		board_ctx.is_simulation = true
		AbilityResolver.process_trigger(C.TRIGGER_ON_BOARD_STATE_CHANGED, board_ctx)

		# Trigger on_enemy_summon ONLY during combat phase (for abilities like Ambush Predator)
		if is_combat_phase:
			TurnAbilities.trigger_on_enemy_summon(new_inst.ball_uuid, summoned_team, summoned_location)
		
		# Drain strictly the reactions from this summoned unit's scope
		var unit_reaction_events: Array[CombatEvent] = drain_reaction_scope(unit_summon_scope, bm)
		var inline_evts = collect_and_clear_inline_events()
		CombatCommand.append_unified_events(out_events, inline_evts)
		CombatCommand.append_unified_events(out_events, unit_reaction_events)

	# Drain any remaining reactions captured in outer_scope (e.g. ON_ENTER_BOARD from _apply_summon_result)
	var outer_reaction_events: Array[CombatEvent] = drain_reaction_scope(outer_scope, bm)
	var outer_inline_evts = collect_and_clear_inline_events()
	CombatCommand.append_unified_events(out_events, outer_inline_evts)
	CombatCommand.append_unified_events(out_events, outer_reaction_events)

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
	var is_enemy_trinket: bool = source.location_container_tag in [C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER]
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
