# res://scripts/battle/CausalReactionResolver.gd
class_name CausalReactionResolver
extends RefCounted

const C = preload("res://scripts/Constants.gd")

## CausalReactionResolver (CRR)
##
## Centralized, deterministic state machine for managing combat reactions,
## sub-phase resolution, priority tie-breaking, and causal event tracking.
##
## Replaces ad-hoc queue slicing and index manipulation with an explicit,
## priority-tiered reaction lifecycle:
##   1. INTERCEPTION: Priority >= 300 (Guardian, Aegis Charm)
##   2. PRIMARY_MUTATION: Primary attack, stat change, or trigger effect
##   3. REACTION_COLLECT: Gathers on_hurt, on_damage_dealt, on_stat_increased
##   4. LETHAL_COUNTER: Retaliation reactions execute WHILE unit death is deferred
##   5. KNOCKOUT: Finalizes knockouts, creates KNOCKOUT events, on_death/on_ally_death
##   6. CASCADE: Drains remaining reactions in strict 3-Layer priority order

enum Phase {
	IDLE,
	INTERCEPTION,
	PRIMARY_MUTATION,
	REACTION_COLLECT,
	LETHAL_COUNTER,
	KNOCKOUT,
	CASCADE
}

## Internal priority queue of pending reactions
var _pending_reactions: Array[EffectRequest] = []

## Current lifecycle phase
var _current_phase: Phase = Phase.IDLE

## Scoped reaction tracking:
## Allows a caller to open a scope, trigger abilities, and then drain strictly
## the reactions enqueued during that scope, without index slicing or resizing.
var _next_scope_id: int = 1
var _active_scopes: Dictionary = {} # scope_id: int -> Array[EffectRequest]

# ==============================================================================
# QUEUE MANAGEMENT & SCOPES
# ==============================================================================

## Begin a reaction scope. Returns a unique scope ID.
func begin_scope() -> int:
	var scope_id := _next_scope_id
	_next_scope_id += 1
	var initial_items := {}
	for req in _pending_reactions:
		initial_items[req] = true
	_active_scopes[scope_id] = {
		"initial_items": initial_items,
		"explicit_requests": []
	}
	return scope_id

## Enqueue a single reaction request.
func enqueue(request: EffectRequest) -> void:
	assert(request != null, "CRR: Cannot enqueue null EffectRequest")
	_pending_reactions.append(request)
	for scope_id in _active_scopes:
		_active_scopes[scope_id]["explicit_requests"].append(request)

## Enqueue multiple reaction requests.
func enqueue_many(requests: Array[EffectRequest]) -> void:
	for req in requests:
		enqueue(req)

## Drain only reactions that were enqueued within the specified scope.
## Removes them from _pending_reactions and returns them sorted by 3-Layer priority.
func drain_scope(scope_id: int) -> Array[EffectRequest]:
	assert(_active_scopes.has(scope_id), "CRR: Invalid or already drained scope_id: %d" % scope_id)
	var scope_info: Dictionary = _active_scopes[scope_id]
	_active_scopes.erase(scope_id)
	
	var initial_items: Dictionary = scope_info.get("initial_items", {})
	var explicit_requests: Array = scope_info.get("explicit_requests", [])
	
	var explicit_set := {}
	for req in explicit_requests:
		explicit_set[req] = true
	
	var remaining: Array[EffectRequest] = []
	var matched: Array[EffectRequest] = []
	for req in _pending_reactions:
		if explicit_set.has(req) or not initial_items.has(req):
			matched.append(req)
		else:
			remaining.append(req)
	_pending_reactions = remaining
	
	matched.sort_custom(compare_reactions)
	return matched

## Extract and remove only reactions within the specified scope that match predicate.
## The scope remains open in _active_scopes for subsequent draining.
func drain_scope_matching(scope_id: int, predicate: Callable) -> Array[EffectRequest]:
	assert(_active_scopes.has(scope_id), "CRR: Invalid or already drained scope_id: %d" % scope_id)
	var scope_info: Dictionary = _active_scopes[scope_id]
	var initial_items: Dictionary = scope_info.get("initial_items", {})
	var explicit_requests: Array = scope_info.get("explicit_requests", [])

	var explicit_set := {}
	for req in explicit_requests:
		explicit_set[req] = true

	var remaining: Array[EffectRequest] = []
	var matched: Array[EffectRequest] = []
	for req in _pending_reactions:
		var in_scope: bool = explicit_set.has(req) or not initial_items.has(req)
		if in_scope and predicate.call(req):
			matched.append(req)
		else:
			remaining.append(req)
	_pending_reactions = remaining

	matched.sort_custom(compare_reactions)
	return matched

## Adopt existing pending reactions matching predicate into an active scope
## so they will be drained when that scope is drained.
func adopt_into_scope(scope_id: int, predicate: Callable) -> void:
	assert(_active_scopes.has(scope_id), "CRR: Invalid scope_id for adopt_into_scope: %d" % scope_id)
	var scope_info: Dictionary = _active_scopes[scope_id]
	var initial_items: Dictionary = scope_info["initial_items"]
	var explicit_requests: Array = scope_info["explicit_requests"]
	for req in _pending_reactions:
		if predicate.call(req):
			initial_items.erase(req)
			if not explicit_requests.has(req):
				explicit_requests.append(req)

## Drain all remaining reactions in strict 3-Layer priority order.
func drain_all() -> Array[EffectRequest]:
	_current_phase = Phase.CASCADE
	var requests = _pending_reactions.duplicate()
	_pending_reactions.clear()
	requests.sort_custom(compare_reactions)
	return requests

## Check if any reactions are pending.
func is_empty() -> bool:
	return _pending_reactions.is_empty()

## Get the count of pending reactions.
func size() -> int:
	return _pending_reactions.size()

## Clear all pending reactions.
func clear() -> void:
	_pending_reactions.clear()
	_active_scopes.clear()
	_current_phase = Phase.IDLE

## Get a read-only copy of pending reactions.
func get_pending_reactions() -> Array[EffectRequest]:
	return _pending_reactions.duplicate()

## Current lifecycle phase
func get_current_phase() -> Phase:
	return _current_phase

func set_current_phase(new_phase: Phase) -> void:
	_current_phase = new_phase

# ==============================================================================
# 3-LAYER DETERMINISTIC PRIORITY HIERARCHY
# ==============================================================================

## Sort pending reactions in-place using the 3-Layer Priority Hierarchy.
func sort_pending() -> void:
	_pending_reactions.sort_custom(compare_reactions)

## Deterministic 3-Layer Priority Comparator
## Layer 1: SubPhase Execution Order (Ascending: 5 up to 300)
## Layer 2: Category Rank (UNIT -> ITEM -> TRINKET)
## Layer 3: Visual Direction (The Mirror Rule: Player 4->0, Enemy 0->4)
static func compare_reactions(a: EffectRequest, b: EffectRequest) -> bool:
	# Layer 1: SubPhase Execution Order (Ascending enum value)
	if a.sub_phase != b.sub_phase:
		return a.sub_phase < b.sub_phase

	# Layer 2: Category Tie-Breaker (UNIT -> ITEM -> TRINKET)
	var rank_a := get_category_rank(a.category)
	var rank_b := get_category_rank(b.category)
	if rank_a != rank_b:
		return rank_a < rank_b

	# Layer 3: Visual Direction / Pre-Combat & Mirror Rules
	var is_pre_combat_a: bool = a.trigger_context.get("trigger_type") == C.TRIGGER_PRE_COMBAT
	var is_pre_combat_b: bool = b.trigger_context.get("trigger_type") == C.TRIGGER_PRE_COMBAT
	if is_pre_combat_a and is_pre_combat_b:
		# Team Order: Player team first, then Enemy team
		if a.is_player != b.is_player:
			return a.is_player

		# Trinket Order: Player 0 to max, Enemy max down to 0
		if a.category == &"TRINKET" and b.category == &"TRINKET":
			if a.is_player:
				if a.slot_index != b.slot_index:
					return a.slot_index < b.slot_index
			else:
				if a.slot_index != b.slot_index:
					return a.slot_index > b.slot_index
		else:
			# Unit & Item Order: Back to front (highest slot down to slot 0) for BOTH teams
			if a.slot_index != b.slot_index:
				return a.slot_index > b.slot_index
	else:
		# Standard In-Combat Mirror Rule (Left-to-Right)
		if a.is_player != b.is_player:
			return a.is_player # Player (left side) before Enemy (right side)

		if a.is_player:
			# Player team: Left-to-Right is slot 4 down to slot 0
			if a.slot_index != b.slot_index:
				return a.slot_index > b.slot_index
		else:
			# Enemy team: Left-to-Right is slot 0 up to slot 4
			if a.slot_index != b.slot_index:
				return a.slot_index < b.slot_index

	# Intra-unit item tie-breaker (slot index 0 -> N)
	if a.sub_index != b.sub_index:
		return a.sub_index < b.sub_index

	# Absolute tie-breaker: Lexical sort by ability_id
	return String(a.ability_id) < String(b.ability_id)

## Returns integer rank for category tie-breaking (Layer 2).
static func get_category_rank(cat: StringName) -> int:
	match cat:
		&"UNIT": return 1
		&"ITEM": return 2
		&"TRINKET": return 3
		_: return 4

# ==============================================================================
# PHASE-SPECIFIC EXTRACTION (Replaces Index Slicing)
# ==============================================================================

## Extract and remove all pending reactions that match a predicate.
## The extracted reactions are sorted by priority before returning.
func drain_matching(predicate: Callable) -> Array[EffectRequest]:
	var matched: Array[EffectRequest] = []
	var remaining: Array[EffectRequest] = []
	
	for req in _pending_reactions:
		if predicate.call(req):
			matched.append(req)
		else:
			remaining.append(req)
	
	_pending_reactions = remaining
	matched.sort_custom(compare_reactions)
	return matched

## Drain all Interception reactions (Priority >= 300).
## Used by basic attacks and damage commands to populate pre_impact_events.
func drain_interceptions() -> Array[EffectRequest]:
	_current_phase = Phase.INTERCEPTION
	return drain_matching(func(req: EffectRequest) -> bool:
		return req.sub_phase <= C.SubPhase.PRE_DAMAGE_INTERCEPT
	)

## Drain all Knockout Counter reactions.
## A knockout counter is a reaction from a unit that received knockout damage (HP <= 0)
## whose ability definition has execute_before_knockout == true.
func drain_lethal_counters(bm: Node) -> Array[EffectRequest]:
	_current_phase = Phase.LETHAL_COUNTER
	return drain_matching(func(req: EffectRequest) -> bool:
		if req.source_uuid.is_empty():
			return false
		var source = bm.get_instance_by_uuid(req.source_uuid)
		if not is_instance_valid(source):
			return false
		var src_def = source.get_definition()
		if not is_instance_valid(src_def) or src_def.category != &"UNIT":
			return false
		if source.current_hp > 0:
			return false
		# Check if ability has execute_before_knockout flag
		var ability_def = bm._get_ability_definition(req.ability_id, source)
		return is_instance_valid(ability_def) and ability_def.execute_before_knockout
	)

func extract_before_knockout_reactions(bm: Node) -> Array[EffectRequest]:
	return drain_lethal_counters(bm)

## Pop the highest priority reaction from the queue.
func pop_front() -> EffectRequest:
	if _pending_reactions.is_empty():
		return null
	sort_pending()
	return _pending_reactions.pop_front()

# ==============================================================================
# CAUSAL EVENT LINEAGE
# ==============================================================================

## Stamps cause_event_id onto any events that do not already have one set.
static func stamp_cause_id(events: Array[CombatEvent], cause_id: int) -> void:
	if cause_id < 0:
		return
	for event in events:
		if is_instance_valid(event) and event.cause_event_id == -1:
			event.cause_event_id = cause_id
