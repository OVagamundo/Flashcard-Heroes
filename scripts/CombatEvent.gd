# scripts/CombatEvent.gd
@tool
class_name CombatEvent
extends Resource

enum Type {
	DAMAGE,
	HEAL,
	DEATH,
	DAMAGE_BURN, # End of turn burn damage
	SUMMON, # Payload must contain snapshot of new unit
	BUFF, # Payload: { "stat": "hp" or "pwr", "amount": int } - Core stats only
	DEBUFF, # Payload: { "stat": "hp" or "pwr", "amount": int } - Core stat debuff
	STATUS_EFFECT, # Payload: { "stat": "*_stacks", "amount": int } - burn, armor, etc.
	MOVE, # Payload: { "from_slot": 1, "to_slot": 2 }
	PROJECTILE, # Visual only: { "source_uuid": str, "target_uuid": str, "vfx_id": str }
	APPLY_BURN,
	VFX_POPUP, # Visual only: { "target_uuid": str, "text": str, "color": Color }
	LOG_MESSAGE, # Legacy support for text logs
	LETHAL_SAVE, # Aegis Charm: unit saved from lethal damage, floats up gold then lands
	GUARDIAN_INTERCEPT, # Guardian Sentinel: leaps to ally's position to intercept lethal damage
	KAMIKAZE_ATTACK, # Death's Bargain: dying unit lunges to target, attacks, dies at target
	TRANSFORM, # Mimic: hop and vanish
	GOLD_GAIN, # Payload: { "amount": int }
	ITEM_TRANSFER, # Standard Bearer: item transfer on death
	SLOT_EFFECT_CHANGE, # Visual only: { "container_tag": StringName, "slot_index": int, "from_effect": StringName, "to_effect": StringName }
	TOKEN_GAIN,
	DRAW, # New for Async Draw Chains
	ITEM_DISCARD, # Replaced/discarded item arcs to Discard Pile button
	ITEM_EQUIP, # Equipped item appears on unit view
	MERGE # Merge action on battle board
}

var type: Type
var action_type: StringName = &""
var source_uuid: String = "" # Logic UUID or "SYSTEM" or "TRINKET_ID"
var target_uuids: Array[String] = []

# Unique event ID for simulation-presentation verification
static var _next_event_id: int = 0
var event_id: int = 0

# Causal linkage: ID of root event that triggered this reaction (-1 for root actions)
var cause_event_id: int = -1

# Ability/Trigger Context - enables descriptive logging
var ability_id: StringName = &"" # e.g., "basic_attack", "item_tier2b_bloodlust"
var trigger_type: StringName = &"" # e.g., "on_kill", "on_hurt", "on_turn_start", ""
var ability_holder_uuid: String = "" # UUID of unit/item that owns the ability

# Strong typed array for trinket animations to play with this event.
var trinket_activations: Array[CombatTrinketActivation] = []

# The Absolute Truth Payload.  Sparse typed fields replace untyped dictionary
# keys; see CombatPayload for the event-family contracts.
var visual_payload: CombatPayload = CombatPayload.new()

# Sub-phase keyframe events (enables rich choreography without simulation delays)
var windup_events: Array[CombatEvent]:
	get:
		return visual_payload.windup_events if is_instance_valid(visual_payload) else []
	set(val):
		if visual_payload == null:
			visual_payload = CombatPayload.new()
		visual_payload.windup_events = val

var pre_impact_events: Array[CombatEvent]:
	get:
		return visual_payload.pre_impact_events if is_instance_valid(visual_payload) else []
	set(val):
		if visual_payload == null:
			visual_payload = CombatPayload.new()
		visual_payload.pre_impact_events = val

var impact_events: Array[CombatEvent]:
	get:
		return visual_payload.impact_events if is_instance_valid(visual_payload) else []
	set(val):
		if visual_payload == null:
			visual_payload = CombatPayload.new()
		visual_payload.impact_events = val

# Legacy fields for backward compatibility during refactor (marked for removal)
var text: String = ""
var amount: int = 0
var stat: String = ""
var skip_bump: bool = false
var source_name: String = ""
var target_names: Array[String] = []
var apply_burn: bool = false

func _init(p_type: Type = Type.DAMAGE, p_context: Dictionary = {}) -> void:
	self.type = p_type
	
	# Assign unique event ID for simulation-presentation verification
	self.event_id = _next_event_id
	_next_event_id += 1
	
	# Standard fields
	self.source_uuid = String(p_context.get("source_uuid", ""))
	self.cause_event_id = int(p_context.get("cause_event_id", -1))
	
	# Handle targets
	self.target_uuids = []
	var raw_targets = p_context.get("target_uuids", [])
	if raw_targets is Array:
		for u in raw_targets:
			self.target_uuids.append(String(u))
	elif raw_targets is String:
		self.target_uuids.append(String(raw_targets))
	
	# Ability/Trigger Context - enables descriptive logging
	self.ability_id = StringName(p_context.get("ability_id", ""))
	self.trigger_type = StringName(p_context.get("trigger_type", ""))
	self.ability_holder_uuid = String(p_context.get("ability_holder_uuid", ""))
	self.action_type = StringName(p_context.get("action_type", ""))
		
	# Visual Payload (The new standard)
	var supplied_payload = p_context.get("visual_payload", null)
	if supplied_payload is CombatPayload:
		self.visual_payload = supplied_payload
		if self.action_type == &"" and self.visual_payload.action_type != &"":
			self.action_type = self.visual_payload.action_type
		elif self.action_type != &"" and self.visual_payload.action_type == &"":
			self.visual_payload.action_type = self.action_type
	
	# Legacy field population for compatibility
	self.text = String(p_context.get("text", ""))
	self.amount = int(p_context.get("amount", 0))
	self.stat = String(p_context.get("stat", ""))
	self.skip_bump = bool(p_context.get("skip_bump", false))
	self.source_name = String(p_context.get("source_name", ""))
	self.apply_burn = bool(p_context.get("apply_burn", false))
	
	# Populate target names for legacy log
	self.target_names = []
	var raw_target_names = p_context.get("target_names", [])
	if raw_target_names is Array:
		for n in raw_target_names:
			self.target_names.append(String(n))
	elif raw_target_names is String:
		self.target_names.append(String(raw_target_names))

## Get the event type as a string for logging
func get_type_name() -> String:
	return Type.keys()[type]

## Log this event to console with [SIM] prefix for verification
func log_sim() -> void:
	var targets_str = ", ".join(target_uuids) if not target_uuids.is_empty() else "none"

## Static method to reset event counter (call at battle start)
static func reset_event_counter() -> void:
	_next_event_id = 0

## Deep clone this event, bypassing Godot's duplicate(true) limitation on non-exported fields.
func deep_clone() -> CombatEvent:
	var copy = CombatEvent.new(self.type)
	copy.event_id = self.event_id
	copy.cause_event_id = self.cause_event_id
	copy.source_uuid = self.source_uuid
	copy.action_type = self.action_type
	copy.target_uuids = self.target_uuids.duplicate()
	copy.ability_id = self.ability_id
	copy.trigger_type = self.trigger_type
	copy.ability_holder_uuid = self.ability_holder_uuid
	for activation in trinket_activations:
		copy.trinket_activations.append(activation.deep_clone())
	copy.text = self.text
	copy.amount = self.amount
	copy.stat = self.stat
	copy.skip_bump = self.skip_bump
	copy.source_name = self.source_name
	copy.target_names = self.target_names.duplicate()
	copy.apply_burn = self.apply_burn
	
	copy.visual_payload = visual_payload.deep_clone()
	return copy

## Determines whether next_ev can be merged with this event into a unified multi-stat event.
func can_merge_with(next_ev: CombatEvent) -> bool:
	if next_ev == null:
		return false
	if not (type in [Type.BUFF, Type.DEBUFF, Type.HEAL, Type.STATUS_EFFECT] and next_ev.type in [Type.BUFF, Type.DEBUFF, Type.HEAL, Type.STATUS_EFFECT]):
		return false
	
	# Match Rule: Events must originate from the SAME source_uuid. If both are passive (empty source_uuid), ability_id must match.
	var is_same_source: bool = (next_ev.source_uuid == source_uuid and not source_uuid.is_empty())
	var is_both_passive: bool = (source_uuid.is_empty() and next_ev.source_uuid.is_empty() and next_ev.ability_id == ability_id)
	if not (is_same_source or is_both_passive):
		return false
	
	# Matching targets
	if target_uuids.size() != next_ev.target_uuids.size():
		return false
	for target_uuid in target_uuids:
		if not next_ev.target_uuids.has(target_uuid):
			return false
	return true

## Merges next_ev's payload into this event.
func merge_with(next_ev: CombatEvent) -> void:
	if visual_payload == null:
		visual_payload = CombatPayload.new()
	if next_ev.visual_payload == null:
		return
	
	visual_payload.merge_with(next_ev.visual_payload, target_uuids, next_ev.target_uuids)
	
	# Sync event-level stat and action type
	if visual_payload.stat == "both":
		stat = "both"
		type = Type.BUFF
		action_type = &"BUFF"
	if not next_ev.trinket_activations.is_empty():
		for activation in next_ev.trinket_activations:
			trinket_activations.append(activation)

