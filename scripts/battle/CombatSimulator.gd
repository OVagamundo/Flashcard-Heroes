# res://scripts/battle/CombatSimulator.gd
class_name CombatSimulator
extends RefCounted

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

## Insert a newly summoned unit into the actor queue.
## @param new_unit: The summoned unit
## @param is_player: Whether the unit is on the player team
## @param is_player_unit_callback: Callable to check if a queued unit is on player team
func insert_summoned_unit(new_unit: GachaBallInstance, is_player: bool, is_player_unit_callback: Callable) -> void:
	if not is_instance_valid(new_unit):
		return
	
	var slot_idx := new_unit.location_slot_index
	
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
		
		if not is_instance_valid(current_actor):
			continue
		
		if current_actor.current_hp <= 0:
			continue
		
		# Enqueue attack for this actor
		battle_manager._enqueue_attack_for(current_actor)
		
		# Process reaction loop - ALL reactions before checking battle-over
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var current_reaction = _pending_reactions.pop_front()
			
			var reaction_events: Array[CombatEvent] = []
			battle_manager._resolve_single_effect_request(current_reaction, reaction_events, death_tracking)
			
			# Collect inline events (on_before_attack heals etc.)
			var inline_evts = battle_manager.collect_inline_events()
			turn_log.append_array(inline_evts)
			
			turn_log.append_array(reaction_events)
			
			# Process deferred deaths
			var deferred_death_events: Array[CombatEvent] = []
			battle_manager._process_completed_counter_deaths(deferred_death_events, death_tracking)
			turn_log.append_array(deferred_death_events)
		
		# Process on_kill reactions (like Bloodlust granting extra action)
		while not _pending_reactions.is_empty():
			_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
			var kill_reaction = _pending_reactions.pop_front()
			var kill_reaction_events: Array[CombatEvent] = []
			battle_manager._resolve_single_effect_request(kill_reaction, kill_reaction_events, death_tracking)
			turn_log.append_array(kill_reaction_events)
		
		# Check battle-over AFTER all reactions for this actor
		if battle_manager._is_battle_over():
			battle_manager._battle_over_deferred = true
			_actor_queue.clear()
			break
	
	# Final reaction drain - process remaining reactions after all actors
	while not _pending_reactions.is_empty():
		_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
		var final_reaction = _pending_reactions.pop_front()
		
		var final_reaction_events: Array[CombatEvent] = []
		battle_manager._resolve_single_effect_request(final_reaction, final_reaction_events, death_tracking)
		
		var final_inline_evts = battle_manager.collect_inline_events()
		turn_log.append_array(final_inline_evts)
		
		turn_log.append_array(final_reaction_events)
		
		var final_death_events: Array[CombatEvent] = []
		battle_manager._process_completed_counter_deaths(final_death_events, death_tracking)
		turn_log.append_array(final_death_events)
	
	return turn_log

# ============================================================================
# CLEANUP
# ============================================================================

func clear() -> void:
	_actor_queue.clear()
	_pending_reactions.clear()
	_inline_events.clear()
	_is_processing_effect = false
