# scripts/CombatEvent.gd
class_name CombatEvent
extends Resource

enum Type {
	DAMAGE,
	HEAL,
	DEATH,
	SUMMON, # Payload must contain snapshot of new unit
	BUFF, # Payload: { "stat": "pwr", "amount": 1, "is_debuff": false }
	MOVE, # Payload: { "from_slot": 1, "to_slot": 2 }
	PROJECTILE, # Visual only: { "source_uuid": str, "target_uuid": str, "vfx_id": str }
	VFX_POPUP, # Visual only: { "target_uuid": str, "text": str, "color": Color }
	LOG_MESSAGE # Legacy support for text logs
}

var type: Type
var source_uuid: String = "" # Logic UUID or "SYSTEM" or "TRINKET_ID"
var target_uuids: Array[String] = []

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
var apply_poison: bool = false

func _init(p_type: Type, p_context: Dictionary = {}) -> void:
	self.type = p_type
	
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
		
	# Visual Payload (The new standard)
	self.visual_payload = p_context.get("visual_payload", {})
	
	# Legacy field population for compatibility
	self.text = String(p_context.get("text", ""))
	self.amount = int(p_context.get("amount", 0))
	self.stat = String(p_context.get("stat", ""))
	self.skip_bump = bool(p_context.get("skip_bump", false))
	self.source_name = String(p_context.get("source_name", ""))
	self.apply_poison = bool(p_context.get("apply_poison", false))
	
	# Populate target names for legacy log
	self.target_names = []
	var raw_target_names = p_context.get("target_names", [])
	if raw_target_names is Array:
		for n in raw_target_names:
			self.target_names.append(String(n))
	elif raw_target_names is String:
		self.target_names.append(String(raw_target_names))
