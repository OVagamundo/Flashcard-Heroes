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
##   1. INTERCEPTION: Priority >= 300 (Guardian Sentinel, Aegis Charm)
##   2. PRIMARY_MUTATION: Primary attack, stat change, or trigger effect
##   3. REACTION_COLLECT: Gathers on_hurt, on_damage_dealt, on_stat_increased
##   4. LETHAL_COUNTER: Retaliation reactions execute WHILE unit death is deferred
##   5. MORTALITY: Finalizes deaths, creates DEATH events, on_death/on_ally_death
##   6. CASCADE: Drains remaining reactions in strict 3-Layer priority order

enum Phase {
	IDLE,
	INTERCEPTION,
	PRIMARY_MUTATION,
	REACTION_COLLECT,
	LETHAL_COUNTER,
	MORTALITY,
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
## Layer 1: Integer Execution Priority (Descending: 300+ down to <0)
## Layer 2: Category Rank (UNIT -> ITEM -> TRINKET)
## Layer 3: Visual Direction (The Mirror Rule: Player 4->0, Enemy 0->4)
static func compare_reactions(a: EffectRequest, b: EffectRequest) -> bool:
	# Layer 1: Execution Priority (Descending integer priority)
	if a.priority != b.priority:
		return a.priority > b.priority

	# Layer 2: Category Tie-Breaker (UNIT -> ITEM -> TRINKET)
	var rank_a := get_category_rank(a.category)
	var rank_b := get_category_rank(b.category)
	if rank_a != rank_b:
		return rank_a < rank_b

	# Layer 3: Visual Direction / The Mirror Rule (Left-to-Right)
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
		return req.priority >= C.PRIORITY_GUARDIAN_INTERCEPT
	)

## Drain all Lethal Counter reactions.
## A lethal counter is a reaction from a unit that received lethal damage (HP <= 0)
## whose ability definition has execute_on_lethal == true.
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
		# Check if ability has execute_on_lethal flag
		var ability_def = bm._get_ability_definition(req.ability_id, source)
		return is_instance_valid(ability_def) and ability_def.execute_on_lethal
	)

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
