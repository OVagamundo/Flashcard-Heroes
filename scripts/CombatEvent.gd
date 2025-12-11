# scripts/CombatEvent.gd
class_name CombatEvent
extends Resource

enum Type {
	DAMAGE,
	HEAL,
	DEATH,
	DAMAGE_BURN, # End of turn burn damage
	SUMMON, # Payload must contain snapshot of new unit
	BUFF, # Payload: { "stat": "pwr", "amount": 1, "is_debuff": false }
	MOVE, # Payload: { "from_slot": 1, "to_slot": 2 }
	PROJECTILE, # Visual only: { "source_uuid": str, "target_uuid": str, "vfx_id": str }
	APPLY_BURN,
	VFX_POPUP, # Visual only: { "target_uuid": str, "text": str, "color": Color }
	LOG_MESSAGE # Legacy support for text logs
}

var type: Type
var source_uuid: String = "" # Logic UUID or "SYSTEM" or "TRINKET_ID"
var target_uuids: Array[String] = []

# Unique event ID for simulation-presentation verification
static var _next_event_id: int = 0
var event_id: int = 0

# Ability/Trigger Context - enables descriptive logging
var ability_id: StringName = &"" # e.g., "basic_attack", "item_tier2b_bloodlust"
var trigger_type: StringName = &"" # e.g., "on_kill", "on_hurt", "on_turn_start", ""
var ability_holder_uuid: String = "" # UUID of unit/item that owns the ability

# The Absolute Truth Payload
# MANDATORY KEYS for DAMAGE/HEAL: { "new_hp": int, "amount": int, "is_crit": bool }
# MANDATORY KEYS for SUMMON: { "snapshot": Dictionary }
var visual_payload: Dictionary = {}

# Legacy fields for backward compatibility during refactor (marked for removal)
var text: String = ""
var amount: int = 0
var stat: String = ""
var skip_bump: bool = false
var source_name: String = ""
var target_names: Array[String] = []
var apply_burn: bool = false

func _init(p_type: Type, p_context: Dictionary = {}) -> void:
	self.type = p_type
	
	# Assign unique event ID for simulation-presentation verification
	self.event_id = _next_event_id
	_next_event_id += 1
	
	# Standard fields
	self.source_uuid = String(p_context.get("source_uuid", ""))
	
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
		
	# Visual Payload (The new standard)
	self.visual_payload = p_context.get("visual_payload", {})
	
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
	print("[SIM] Event#%d: %s | src=%s | targets=[%s]" % [event_id, get_type_name(), source_uuid.substr(0, 20), targets_str])

## Static method to reset event counter (call at battle start)
static func reset_event_counter() -> void:
	_next_event_id = 0
