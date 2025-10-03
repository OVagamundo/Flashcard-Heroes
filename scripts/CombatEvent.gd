# scripts/CombatEvent.gd
class_name CombatEvent
extends Resource

enum Type {
	LOG_MESSAGE,    # A message for the battle log
	DAMAGE,         # A unit takes damage (for UI stat updates)
	HEAL,           # A unit is healed (for UI stat updates)
	DEATH,          # A unit died; play death animation before removal
	INVENTORY_SYNC, # A full UI refresh is needed for death removals
	STAT_BUFF,      # Legacy name for non-HP stat increase
	STRENGTHEN      # Preferred name for non-HP stat increase (e.g., PWR buff)
}

var type: Type
var text: String = ""
var source_uuid: String = ""
var target_uuids: Array[String] = []
var amount: int = 0
var stat: String = ""

func _init(p_type: Type, p_context: Dictionary = {}) -> void:
	self.type = p_type
	self.text = p_context.get("text", "")
	self.source_uuid = p_context.get("source_uuid", "")
	# Coerce to typed Array[String]
	self.target_uuids = []
	var raw_targets: Variant = p_context.get("target_uuids", [])
	if raw_targets is Array:
		for u in raw_targets:
			self.target_uuids.append(String(u))
	elif raw_targets is String:
		self.target_uuids.append(String(raw_targets))
	# Optional numeric/stat context
	self.amount = int(p_context.get("amount", 0))
	self.stat = String(p_context.get("stat", ""))
