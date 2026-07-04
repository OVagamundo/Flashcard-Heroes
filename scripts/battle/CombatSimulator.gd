# res://scripts/battle/CombatSimulator.gd
class_name CombatSimulator
extends RefCounted
const C = preload("res://scripts/Constants.gd")

## CombatSimulator encapsulates the turn-based combat simulation data.
## This class is responsible for:
##   - Managing the actor queue (units that will act this turn)
##   - Managing pending effect reactions (priority queue)
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

## Priority-driven reaction queue for abilities
var _pending_reactions: Array[EffectRequest] = []

## Events from on_before_attack processing
var _inline_events: Array[CombatEvent] = []

## Flag to prevent re-entrant effect processing
var _is_processing_effect: bool = false

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

func get_pending_reactions() -> Array[EffectRequest]:
	return _pending_reactions

func clear_pending_reactions() -> void:
	_pending_reactions.clear()

func has_pending_reactions() -> bool:
	return not _pending_reactions.is_empty()

func enqueue_reaction(request: EffectRequest) -> void:
	if OS.is_debug_build():
		print("[CS] Enqueue reaction: ", request.ability_id, " Prio:", request.priority)
	_pending_reactions.append(request)

func sort_reactions_by_priority() -> void:
	_pending_reactions.sort_custom(func(a, b): return a.priority < b.priority)

func pop_next_reaction() -> EffectRequest:
	if _pending_reactions.is_empty():
		return null
	return _pending_reactions.pop_front()

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
	return _is_processing_effect

func set_processing(value: bool) -> void:
	_is_processing_effect = value

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
		
		# Enqueue attack for this actor
		battle_manager._enqueue_attack_for(current_actor)
		
		# Process all reactions (including on_kill triggers from the attack)
		turn_log.append_array(process_reaction_queue(battle_manager, death_tracking))
		
		# Check battle-over AFTER all reactions for this actor
		if battle_manager._is_battle_over():
			battle_manager._battle_over_deferred = true
			_actor_queue.clear()
			break
	
	# Final reaction drain - process remaining reactions after all actors
	turn_log.append_array(process_reaction_queue(battle_manager, death_tracking))
	
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
	
	while not _pending_reactions.is_empty():
		# Always re-sort as new reactions might have been added (e.g. on_death triggers)
		_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
		var current_reaction = _pending_reactions.pop_front()
		
		var reaction_events: Array[CombatEvent] = []
		resolve_effect_request(current_reaction, reaction_events, death_tracking, battle_manager)
		_tag_trinket_events(reaction_events, current_reaction, battle_manager)
		
		# Collect inline events (e.g. self-damage, heals, lethal saves triggered during resolution)
		var inline_evts = collect_and_clear_inline_events()
		events.append_array(inline_evts)
		
		events.append_array(reaction_events)
		
		# Process deferred deaths immediately to ensure correct ordering (e.g. before next reaction)
		var deferred_death_events: Array[CombatEvent] = []
		battle_manager._process_completed_counter_deaths(deferred_death_events, death_tracking)
		events.append_array(deferred_death_events)
		
	return events

# ============================================================================
# EFFECT RESOLUTION (Moved from BattleManager)
# ============================================================================

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
				sim_ctx["source_category"] = source_def.category
				
				# For items, use the HOLDER's stats (not the item's stats which are 0)
				# Also include holder UUID so effects can identify the attacker
				if source_def.category == &"ITEM" and not source.equipped_on_uuid.is_empty():
					sim_ctx["source_holder_uuid"] = source.equipped_on_uuid
					var holder = bm.get_instance_by_uuid(source.equipped_on_uuid)
					if is_instance_valid(holder):
						stat_provider = holder
			
			# Snapshot stats from the appropriate provider (source for units, holder for items)
			# DEATH CONTEXT PRESERVATION: If the source is dead (on_death ability) and the
			# trigger_context already has a snapshotted source_pwr from DeathProcessor,
			# preserve that value instead of overwriting with the (potentially stale) live value.
			if stat_provider.current_hp <= 0 and request.trigger_context.has("source_pwr"):
				sim_ctx["source_pwr"] = request.trigger_context["source_pwr"]
			else:
				sim_ctx["source_pwr"] = stat_provider.current_pwr
			sim_ctx["source_hp"] = stat_provider.current_hp
		
		var _effect_script_path = request.effect_definition.get_script().resource_path if request.effect_definition.get_script() else "no_script"
		var res = request.effect_definition.execute(request.source_uuid, exec_targets, bm, sim_ctx)
		
		# CRITICAL: Collect on_before_attack inline events IMMEDIATELY after effect execution
		# These events (like Defensive Stance heal) must appear BEFORE any damage events
		# to maintain correct causal order: HEAL → DAMAGE (not DAMAGE → HEAL)
		var before_attack_inline_evts = collect_and_clear_inline_events()
		out_events.append_array(before_attack_inline_evts)
		
		# NEW: Handle EffectResult returns (migrated effects)
		# EffectResult is the new standardized return type that encapsulates events and trigger data
		if res is EffectResult:
			var effect_result: EffectResult = res
			
			# Handle delegated damage requests (from EffectModifyStat negative HP)
			# This routes through the proper damage pipeline with armor/burn/guardian handling
			if not effect_result.damage_request.is_empty():
				var dmg_data: Dictionary = effect_result.damage_request
				var stat: String = dmg_data.get("stat", "")
				var amount: int = dmg_data.get("amount", 0)
				var targets: Array = dmg_data.get("targets", [])
				
				if stat == "hp" and amount < 0 and not targets.is_empty():
					var dmg_source: GachaBallInstance = bm.get_instance_by_uuid(request.source_uuid)
					var resolved_targets: Array[String] = []
					var target_display_names: Array[String] = []
					for t in targets:
						var tgt = bm.get_instance_by_uuid(String(t))
						resolved_targets.append(String(t))
						target_display_names.append(BattleHelpers.get_instance_display_name(tgt))
					
					var source_name := ""
					if is_instance_valid(dmg_source):
						source_name = BattleHelpers.get_instance_display_name(dmg_source)
					if source_name == "":
						source_name = String(request.ability_id)
					
					# CRITICAL: Trigger on_before_damage for each target BEFORE damage
					# This allows defensive abilities like Guardian's Defensive Stance to proc
					# Capture queue size BEFORE triggering reactions to avoid draining unrelated events
					var on_before_damage_start_index = _pending_reactions.size()
					
					for tgt_uuid in resolved_targets:
						var tgt = bm.get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt) and tgt.current_hp > 0:
							var before_ctx := {
								"source_uuid": tgt_uuid, # The target is source of its own defensive ability
								"defender_uuid": tgt_uuid,
								"attacker_uuid": request.source_uuid,
								"target_initial_hp": tgt.current_hp,
								"is_simulation": true
							}
							AbilityResolver.process_trigger(&"on_before_damage", before_ctx)
					
					# Drain on_before_damage reactions before damage is applied
					drain_reactions_inline(on_before_damage_start_index, bm)
					var before_damage_evts = collect_and_clear_inline_events()
					out_events.append_array(before_damage_evts)
					
					var damage_result := EffectHandlers.handle_damage_effect(
						request, resolved_targets, dmg_source, source_name, target_display_names, amount, false, bm
					)
					out_events.append_array(damage_result.events)
					
					if damage_result.should_return:
						return
					
					# Trigger on_hurt for damaged units
					var on_hurt_start_index = _pending_reactions.size()
					for tgt_uuid in damage_result.damaged_uuids:
						bm.trigger_on_hurt(tgt_uuid, abs(amount), request.source_uuid)
					
					# Drain on_hurt reactions
					drain_reactions_inline(on_hurt_start_index, bm)
					var hurt_inline_evts = collect_and_clear_inline_events()
					out_events.append_array(hurt_inline_evts)
					
					# Trigger on_kill for killed units
					for tgt_uuid in damage_result.damaged_uuids:
						var tgt = bm.get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt) and tgt.current_hp <= 0:
							bm.trigger_on_kill(request.source_uuid, tgt_uuid)
					
					# Death check
					bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
					return
			
			# Handle summon request (from EffectSummonOnDeath, EffectSummonT2OnDeath, EffectResurrectFirstKilledUnit)
			if not effect_result.summon_request.is_empty():
				var summon_result := EffectHandlers.handle_summon_unit(request, effect_result.summon_request, bm)
				bm._apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
				# Trigger on_enemy_summon for each new unit
				_trigger_summon_reactions_for_result(summon_result, out_events, bm)
			
			# Handle transform request (Mimic)
			if not effect_result.transform_request.is_empty():
				var transform_result := EffectHandlers.handle_mirror_transform(request, effect_result.transform_request, bm)
				bm._apply_summon_result(transform_result) # Contains the new unit summoning
				out_events.append_array(transform_result.events)
				# Trigger on_enemy_summon for the new unit (it counts as summon?)
				# Yes, a new unit appeared.
				_trigger_summon_reactions_for_result(transform_result, out_events, bm)
			
			# Handle multiple summon request for boss effects (from EffectBossSummon)
			if not effect_result.summon_units_request.is_empty():
				var effect_data := {
					"summon_units": effect_result.summon_units_request,
					"team": effect_result.summon_team
				}
				var summon_result := EffectHandlers.handle_summon_units(request, effect_data, bm)
				bm._apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
				# Trigger on_enemy_summon for each new unit
				_trigger_summon_reactions_for_result(summon_result, out_events, bm)
			
			# Handle cascade damage request (from EffectCascadeAOE)
			# TWO-PHASE PROCESSING for visual "wave" effect:
			# Phase 1: Apply all damage + DAMAGE events in sequence
			# Phase 2: Process all reactions (counter-attacks, on_kill) one target at a time
			if not effect_result.cascade_request.is_empty():
				var cascade_list = effect_result.cascade_request
				
				# Phase 1: Apply all damage via EffectHandlers
				var cascade_result := EffectHandlers.handle_cascade_damage(request, cascade_list, source, bm)
				out_events.append_array(cascade_result.events)
				
				# Phase 2: Process reactions one target at a time (after all damage shown)
				for hit_data in cascade_result.hit_targets:
					var target_uuid: String = hit_data.uuid
					var damage_amount: int = hit_data.amount
					var was_killed: bool = hit_data.was_killed
					
					# Trigger on_hurt for counter-attacks
					var cascade_hurt_start = _pending_reactions.size()
					bm.trigger_on_hurt(target_uuid, damage_amount, request.source_uuid)
					
					# Drain on_hurt reactions for THIS target
					drain_reactions_inline(cascade_hurt_start, bm)
					var cascade_hurt_inline_evts = collect_and_clear_inline_events()
					out_events.append_array(cascade_hurt_inline_evts)
					
					# Trigger on_kill if killed
					if was_killed:
						bm.trigger_on_kill(request.source_uuid, target_uuid)
				
				# Check for deaths after cascade
				bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
				return
			
			# Handle kamikaze attack request (from EffectDeathDamageHighestEnemy)
			# Creates KAMIKAZE_ATTACK event for animation + applies damage
			if not effect_result.kamikaze_request.is_empty():
				var kamikaze_data = effect_result.kamikaze_request
				var source_uuid: String = kamikaze_data.get("source_uuid", "")
				var target_uuid: String = kamikaze_data.get("target_uuid", "")
				var damage: int = kamikaze_data.get("damage", 0)
				
				if not target_uuid.is_empty() and damage > 0:
					var target_inst = bm.get_instance_by_uuid(target_uuid)
					if is_instance_valid(target_inst) and target_inst.current_hp > 0:
						var old_hp = target_inst.current_hp
						var old_armor = target_inst.get_status_effect_amount(&"armor")
						var _old_spikes = target_inst.get_status_effect_amount(&"spikes")
						
						# Use apply_stat_delta to trigger Spikes (even though attacker is dead)
						# The Spikes damage won't affect dead attacker, but stacks will decay properly
						var damage_result = bm.apply_stat_delta(target_inst, "hp", -damage, false, source_uuid)
						
						var new_hp: int = damage_result.get("new_hp", target_inst.current_hp) if damage_result is Dictionary else target_inst.current_hp
						var armor_consumed: int = damage_result.get("armor_consumed", 0) if damage_result is Dictionary else 0
						var new_armor: int = damage_result.get("new_armor", old_armor) if damage_result is Dictionary else old_armor
						
						# Extract Spikes data for animation (will be shown at impact)
						var spikes_data_list: Array[Dictionary] = []
						if damage_result is Dictionary and damage_result.has("spikes_data"):
							var spikes = damage_result["spikes_data"]
							spikes_data_list.append({
								"attacker_uuid": spikes["attacker_uuid"],
								"defender_uuid": spikes["defender_uuid"],
								"spikes_damage": spikes["spikes_damage"],
								"attacker_old_hp": spikes["attacker_old_hp"],
								"attacker_new_hp": spikes["attacker_new_hp"],
								"attacker_max_hp": 0, # Attacker is dead anyway
								"old_spikes": spikes["old_spikes"],
								"new_spikes": spikes["new_spikes"]
							})
						
						# CRITICAL: Remove the DEATH event for the source since KAMIKAZE_ATTACK
						# handles the death animation at the target position
						for i in range(out_events.size() - 1, -1, -1):
							var evt = out_events[i]
							if evt.type == CombatEvent.Type.DEATH and evt.target_uuids.has(source_uuid):
								out_events.remove_at(i)
								break
						
						# Create KAMIKAZE_ATTACK event for animation
						out_events.append(CombatEvent.new(CombatEvent.Type.KAMIKAZE_ATTACK, {
							"source_uuid": source_uuid,
							"target_uuids": [target_uuid],
							"visual_payload": {
								"source_uuid": source_uuid,
								"amount": damage,
								"targets_old_hp": [old_hp],
								"targets_new_hp": [new_hp],
								"targets_old_armor": [old_armor],
								"targets_new_armor": [new_armor],
								"armor_consumed": [armor_consumed],
								"spikes_data_list": spikes_data_list
							}
						}))
						
						# Fire on_hurt trigger
						bm.trigger_on_hurt(target_uuid, damage, source_uuid)
						
						# Check for kills
						if new_hp <= 0:
							bm.trigger_on_kill(source_uuid, target_uuid)
				
				bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
				return
			
			out_events.append_array(effect_result.events)
			
			# Fire triggers based on result data and drain reactions
			if not effect_result.damaged_uuids.is_empty():
				var result_hurt_start = _pending_reactions.size()
				for damaged_uuid in effect_result.damaged_uuids:
					var damage_amount: int = effect_result.events[0].visual_payload.get("amount", 0) if not effect_result.events.is_empty() else 0
					bm.trigger_on_hurt(damaged_uuid, abs(damage_amount), request.source_uuid)
				
				drain_reactions_inline(result_hurt_start, bm)
				var hurt_inline_evts = collect_and_clear_inline_events()
				out_events.append_array(hurt_inline_evts)
			
			# Fire on_kill triggers
			for killed_uuid in effect_result.killed_uuids:
				bm.trigger_on_kill(request.source_uuid, killed_uuid)
			
			# DEPRECATED: on_healed is now triggered systemically in BattleManager.apply_stat_delta
			# So we don't need to trigger it from EffectResult.healed_events anymore.
			# Keeping drained reactions logic if needed for other reasons, but for healed_events it's redundant.
			if not effect_result.healed_events.is_empty():
				# We still need to drain reactions if any were pending? 
				# No, only reactions FROM on_healed would be pending here.
				# Since we don't trigger it, no reactions to drain.
				pass
			
			# Death check (unless skipped by effect)
			if not effect_result.skip_death_check:
				bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
			return
		
		# LEGACY: Normalize integer returns to dictionary format
		# This must happen before the TYPE_DICTIONARY check so the normalized value gets processed
		if typeof(res) == TYPE_INT:
			var legacy_damage_amount = res
			res = {
				"stat": "hp",
				"amount": - legacy_damage_amount,
				"targets": exec_targets
			}
		
		# LEGACY: Structured stat change results (Dictionary)
		if typeof(res) == TYPE_DICTIONARY:
			var effect_data: Dictionary = res
			
				# Handle cascading damage (special case for AOE shockwave)
			# TWO-PHASE PROCESSING for visual "wave" effect:
			# Phase 1: Apply all damage + DAMAGE events in sequence
			# Phase 2: Process all reactions (counter-attacks, on_kill) one target at a time
			if effect_data.has("cascade_damage"):
				if OS.is_debug_build():
					print("[CS] Processing cascade_damage from ability:", request.ability_id, "source:", request.source_uuid)
				var cascade_list = effect_data.get("cascade_damage", [])
				
				# Phase 1: Apply all damage via EffectHandlers
				var cascade_result := EffectHandlers.handle_cascade_damage(request, cascade_list, source, bm)
				out_events.append_array(cascade_result.events)
				
				# Phase 2: Process reactions one target at a time (after all damage shown)
				for hit_data in cascade_result.hit_targets:
					var target_uuid: String = hit_data.uuid
					var damage_amount: int = hit_data.amount
					var was_killed: bool = hit_data.was_killed
					
					# Trigger on_hurt for counter-attacks
					var cascade_hurt_start = _pending_reactions.size()
					bm.trigger_on_hurt(target_uuid, damage_amount, request.source_uuid)
					
					# Drain on_hurt reactions for THIS target
					drain_reactions_inline(cascade_hurt_start, bm)
					var cascade_hurt_inline_evts = collect_and_clear_inline_events()
					out_events.append_array(cascade_hurt_inline_evts)
					
					# Trigger on_kill if killed
					if was_killed:
						bm.trigger_on_kill(request.source_uuid, target_uuid)
				
				# Check for deaths after cascade
				bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)
				return

			# Handle extra action effects (e.g., Bloodlust Edge on kill)
			# NOTE: extra_action handled via EffectResult (Bloodlust Edge)

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
				var target_inst = bm.get_instance_by_uuid(target_uuid)
				var target_label: String = bm._get_instance_display_name(target_inst)
				if target_label == "":
					target_label = target_uuid
				target_names.append(target_label)
			var source_name := ""
			if not String(request.source_uuid).is_empty():
				var src_inst = bm.get_instance_by_uuid(request.source_uuid)
				source_name = bm._get_instance_display_name(src_inst)
			if source_name == "":
				source_name = String(request.ability_id)
		
			if stat == "hp" and not resolved_targets.is_empty():
				# NOTE: prevented_lethal (Aegis Charm) handled via EffectResult
				# Damage (amount < 0) - Shared with BasicAttack logic
				# NOTE: All healing effects (amount >= 0) now return EffectResult and use that path.
				if amount < 0:
					var dmg_source: GachaBallInstance = bm.get_instance_by_uuid(request.source_uuid)
					var target_display_names: Array[String] = []
					for t in resolved_targets:
						var tgt = bm.get_instance_by_uuid(t)
						target_display_names.append(BattleHelpers.get_instance_display_name(tgt))
					
					var damage_result := EffectHandlers.handle_damage_effect(
						request, resolved_targets, dmg_source, source_name, target_display_names, amount, skip_bump, bm
					)
					out_events.append_array(damage_result.events)
					
					if damage_result.should_return:
						return
					
					# CRITICAL: Trigger on_hurt AFTER apply_stat_delta so condition checks see post-damage HP
					var single_hurt_start = _pending_reactions.size()
					for tgt_uuid in damage_result.damaged_uuids:
						bm.trigger_on_hurt(tgt_uuid, abs(amount), request.source_uuid)
					
					# AEGIS FIX: Drain on_hurt effects BEFORE death check
					drain_reactions_inline(single_hurt_start, bm)
					
					# CRITICAL: Collect inline events (like LETHAL_SAVE) immediately
					var hurt_inline_evts = collect_and_clear_inline_events()
					out_events.append_array(hurt_inline_evts)
					
					# DETERMINISTIC ON_KILL: If this damage killed the target, trigger on_kill immediately
					for tgt_uuid in damage_result.damaged_uuids:
						var tgt = bm.get_instance_by_uuid(tgt_uuid)
						if is_instance_valid(tgt) and tgt.current_hp <= 0:
							bm.trigger_on_kill(request.source_uuid, tgt_uuid)
			# NOTE: stat == "pwr" handled via EffectResult (EffectModifyStat, EffectBuffTwoRandomAllies)
				
			elif stat == "burn_stacks" and not resolved_targets.is_empty():
				out_events.append(EffectHandlers.handle_burn_stacks(request, resolved_targets, amount, bm))
			elif stat == "armor_stacks" and not resolved_targets.is_empty():
				out_events.append(bm.handle_armor_stacks(request, resolved_targets, amount))
			# Handle summon effects (e.g., item_t2_c02)
			elif effect_data.has("summon_unit_id"):
				var summon_result := EffectHandlers.handle_summon_unit(request, effect_data, bm)
				bm._apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
				# Trigger on_enemy_summon for each new unit
				_trigger_summon_reactions_for_result(summon_result, out_events, bm)
			# Handle boss summon effects (array of units to summon)
			elif effect_data.has("summon_units"):
				var summon_result := EffectHandlers.handle_summon_units(request, effect_data, bm)
				bm._apply_summon_result(summon_result)
				out_events.append_array(summon_result.events)
				# Trigger on_enemy_summon for each new unit
				_trigger_summon_reactions_for_result(summon_result, out_events, bm)
			# NOTE: multi_heal and multi_buff branches removed - those effects now return EffectResult directly
	# CRITICAL FIX: Death check MUST run unconditionally after any effect execution
	# This was previously inside the TYPE_DICTIONARY block, causing deaths from the
	# last attack of a turn to miss on_ally_death triggers when effect returned null
	bm._check_for_deaths_with_counter_delay(true, out_events, death_tracking)

## Drain pending reactions inline during effect execution.
## Used to process on_before_attack defensive abilities BEFORE damage is calculated.
## @param start_index: Only process reactions at index >= start_index
## @param bm: BattleManager reference
func drain_reactions_inline(start_index: int, bm) -> void:
	# Only process reactions that were added AFTER start_index
	if start_index >= _pending_reactions.size():
		return # No new reactions to process
	
	# Extract only the new reactions (from start_index to end)
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	# Remove them from the main queue to process them locally
	_pending_reactions.resize(start_index)
	
	# Sort by priority before processing
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	for request in reactions_to_process:
		# DEBUG: Trace priority execution
		if OS.is_debug_build():
			print("[CS] Draining reaction: ", request.ability_id, " Prio:", request.priority, " Src:", request.source_uuid)
			
		# Capture events to _inline_events so they can be collected by the outer loop
		# IMPORTANT: Pass a special death_tracking that disables death checking
		var inline_start_index := _inline_events.size()
		resolve_effect_request(request, _inline_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(_inline_events, request, bm, inline_start_index)
		
		# RECURSIVE PROCESSING: If this effect triggered new reactions, process them immediately
		if not _pending_reactions.is_empty():
			# Recursively drain reactions starting from the CURRENT local start_index
			# This is correct because we resized the global queue to start_index, so any newly
			# appended reactions start at start_index.
			drain_reactions_inline(start_index, bm)

func drain_and_capture_reactions_inline(start_index: int, bm) -> Array[CombatEvent]:
	var captured_events: Array[CombatEvent] = []
	if start_index >= _pending_reactions.size():
		return captured_events
	
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	_pending_reactions.resize(start_index)
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	for request in reactions_to_process:
		var inline_start_index := captured_events.size()
		resolve_effect_request(request, captured_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(captured_events, request, bm, inline_start_index)
		
		if not _pending_reactions.is_empty():
			captured_events.append_array(drain_and_capture_reactions_inline(start_index, bm))
			
	return captured_events

## Drain ONLY execute_on_lethal reactions WITHOUT recursive cascade processing.
## @param start_index: Only process reactions at index >= start_index
## @param bm: BattleManager reference
func drain_lethal_reactions(start_index: int, bm) -> void:
	if start_index >= _pending_reactions.size():
		return # No reactions to process
	
	# Extract reactions from start_index to end
	var reactions_to_process: Array[EffectRequest] = []
	for i in range(start_index, _pending_reactions.size()):
		reactions_to_process.append(_pending_reactions[i])
	
	# Clear the processed range
	_pending_reactions.resize(start_index)
	
	# Sort by priority
	reactions_to_process.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Process ONLY these reactions - do NOT recursively drain new ones
	for request in reactions_to_process:
		var inline_start_index := _inline_events.size()
		resolve_effect_request(request, _inline_events, {"__skip_death_triggers__": true}, bm)
		_tag_trinket_events(_inline_events, request, bm, inline_start_index)
		# NOTE: We intentionally do NOT call drain_reactions_inline(0, bm) here

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
		
		# Trigger on_enemy_summon ONLY during combat phase (for abilities like Ambush Predator)
		if is_combat_phase:
			TurnAbilities.trigger_on_enemy_summon(new_inst.ball_uuid, summoned_team, summoned_location)
		
		# Trigger on_ally_summon in ALL phases (for abilities like Summon Blessing)
		TurnAbilities.trigger_on_ally_summon(new_inst.ball_uuid, summoned_team, summoned_location)
		
		# Drain reactions immediately so summon abilities execute before the summoned unit acts
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var reaction = _pending_reactions.pop_front()
			
			var reaction_events: Array[CombatEvent] = []
			resolve_effect_request(reaction, reaction_events, {}, bm)
			_tag_trinket_events(reaction_events, reaction, bm)
			
			# Collect inline events
			var inline_evts = collect_and_clear_inline_events()
			out_events.append_array(inline_evts)
			out_events.append_array(reaction_events)

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
			
		event.trinket_activations.append({
			"visual_uuid": visual_uuid,
			"definition_id": source.definition_id,
			"is_enemy": is_enemy_trinket
		})

# ============================================================================
# CLEANUP
# ============================================================================

func clear() -> void:
	_actor_queue.clear()
	_pending_reactions.clear()
	_inline_events.clear()
	_is_processing_effect = false
