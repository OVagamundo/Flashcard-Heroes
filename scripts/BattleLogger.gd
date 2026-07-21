# res://scripts/BattleLogger.gd
extends Node

## A centralized battle logging system that outputs natural language descriptions
## of combat events for debugging and in-game display.

signal log_entry_added(entry: Dictionary)
signal log_cleared()

## Log entry structure:
## {
##   "turn": int,
##   "event_index": int,
##   "type": String,  # "attack", "damage", "heal", "buff", "death", "summon", "ability", "extra_action", "turn_start", "turn_end"
##   "message": String,  # Natural language message
##   "details": String,  # Technical details for debugging
##   "indent_level": int,  # For nested events (e.g., ability triggers)
##   "color": String,  # BBCode color for the message type
## }

var _log_entries: Array[Dictionary] = []
var _current_turn: int = 0
var _event_index: int = 0
var _max_entries: int = 500

# Color codes for different event types
const COLORS = {
	"attack": "white",
	"damage": "red",
	"heal": "green",
	"buff": "cyan",
	"death": "orange",
	"summon": "yellow",
	"ability": "purple",
	"extra_action": "gold",
	"turn": "gray",
	"system": "silver"
}

func _ready() -> void:
	# Connect to relevant signals for automatic logging
	SignalBus.battle_phase_changed.connect(_on_battle_phase_changed)
	# Connect to combat events from BattleAnimator
	SignalBus.log_animation_event.connect(_on_animation_event)

func clear_log() -> void:
	_log_entries.clear()
	_current_turn = 0
	_event_index = 0
	log_cleared.emit()

func get_all_entries() -> Array[Dictionary]:
	return _log_entries

func get_recent_entries(count: int = 5) -> Array[Dictionary]:
	var start_idx = max(0, _log_entries.size() - count)
	var result: Array[Dictionary] = []
	for i in range(start_idx, _log_entries.size()):
		result.append(_log_entries[i])
	return result

# ========================================
# PUBLIC LOGGING API
# ========================================

func log_turn_start(turn_number: int) -> void:
	_current_turn = turn_number
	_event_index = 0
	_add_entry("turn", "═══ TURN %d ═══" % turn_number, "", 0, "turn")

func log_turn_end(turn_number: int) -> void:
	_add_entry("turn", "─── End of Turn %d ───" % turn_number, "", 0, "turn")

func log_attack(attacker_name: String, target_name: String, damage: int, old_hp: int, new_hp: int, ability_id: String = "", trigger_type: String = "") -> void:
	var context_str = _format_ability_context(ability_id, trigger_type)
	var message = "[b]%s[/b] attacks [b]%s[/b] for [color=red]%d damage[/color]%s" % [attacker_name, target_name, damage, context_str]
	var details = "(HP: %d→%d)" % [old_hp, new_hp]
	_add_entry("attack", message, details, 0, "attack")

func log_damage(source_name: String, target_name: String, damage: int, old_hp: int, new_hp: int, damage_type: String = "damage") -> void:
	var message = "[b]%s[/b] deals [color=red]%d %s[/color] to [b]%s[/b]" % [source_name, damage, damage_type, target_name]
	var details = "(HP: %d→%d)" % [old_hp, new_hp]
	_add_entry("damage", message, details, 0, "damage")

func log_cascade_damage(_source_name: String, target_name: String, damage: int, old_hp: int, new_hp: int) -> void:
	var message = "Shockwave deals [color=red]%d damage[/color] to [b]%s[/b]" % [damage, target_name]
	var details = "(HP: %d→%d)" % [old_hp, new_hp]
	_add_entry("damage", message, details, 1, "damage")

func log_heal(source_name: String, target_name: String, amount: int, old_hp: int, new_hp: int, ability_id: String = "", trigger_type: String = "") -> void:
	var context_str = _format_ability_context(ability_id, trigger_type)
	var message = "[b]%s[/b] heals [b]%s[/b] for [color=green]%d HP[/color]%s" % [source_name, target_name, amount, context_str]
	var details = "(HP: %d→%d)" % [old_hp, new_hp]
	_add_entry("heal", message, details, 0, "heal")

func log_buff(source_name: String, target_name: String, stat: String, amount: int, is_debuff: bool = false, ability_id: String = "", trigger_type: String = "") -> void:
	var sign_str = "-" if is_debuff else "+"
	var color = "red" if is_debuff else "cyan"
	var context_str = _format_ability_context(ability_id, trigger_type)
	var message = "[b]%s[/b] grants [b]%s[/b] [color=%s]%s%d %s[/color]%s" % [source_name, target_name, color, sign_str, abs(amount), stat.to_upper(), context_str]
	_add_entry("buff", message, "", 0, "buff")

func log_ability_trigger(source_name: String, ability_name: String, trigger_reason: String = "") -> void:
	var reason_str = " (%s)" % trigger_reason if trigger_reason != "" else ""
	var message = "[b]%s[/b] triggers [color=purple]\"%s\"[/color]%s" % [source_name, ability_name, reason_str]
	_add_entry("ability", message, "", 1, "ability")

func log_death(unit_name: String, killer_name: String = "") -> void:
	var message: String
	if killer_name != "":
		message = "[b]%s[/b] defeats [b][color=orange]%s[/color][/b]!" % [killer_name, unit_name]
	else:
		message = "[b][color=orange]%s[/color][/b] is defeated!" % unit_name
	_add_entry("death", message, "", 1, "death")

func log_summon(summoned_name: String, source_name: String) -> void:
	var message = "[b]%s[/b] summons [color=yellow][b]%s[/b][/color]!" % [source_name, summoned_name]
	_add_entry("summon", message, "", 1, "summon")

func log_extra_action(unit_name: String, ability_name: String) -> void:
	var message = "[color=gold]\"%s\"[/color] grants [b]%s[/b] an extra action!" % [ability_name, unit_name]
	_add_entry("extra_action", message, "", 1, "extra_action")

func log_burn_damage(target_name: String, damage: int, old_hp: int, new_hp: int, stacks: int) -> void:
	var message = "[b]%s[/b] takes [color=orange]%d burn damage[/color] (%d stacks)" % [target_name, damage, stacks]
	var details = "(HP: %d→%d)" % [old_hp, new_hp]
	_add_entry("damage", message, details, 0, "damage")

func log_system(message: String) -> void:
	_add_entry("system", "[color=silver]%s[/color]" % message, "", 0, "system")

# ========================================
# COMBAT EVENT TRANSLATION
# ========================================

func _on_animation_event(event: CombatEvent) -> void:
	# Translate CombatEvent to natural language log entry
	var source_name = _get_source_name(event)
	var target_names = _get_target_names(event)
	var primary_target = target_names[0] if target_names.size() > 0 else "Unknown"
	
	match event.type:
		CombatEvent.Type.DAMAGE:
			var payload = event.visual_payload
			# HP values are stored in arrays (targets_old_hp, targets_new_hp)
			var old_hp_arr = payload.targets_old_hp
			var new_hp_arr = payload.targets_new_hp
			var old_hp = int(old_hp_arr[0]) if old_hp_arr.size() > 0 else 0
			var new_hp = int(new_hp_arr[0]) if new_hp_arr.size() > 0 else 0
			var damage = abs(payload.amount)
			if damage == 0:
				damage = abs(old_hp - new_hp)
			log_attack(source_name, primary_target, damage, old_hp, new_hp, String(event.ability_id), String(event.trigger_type))
		
		CombatEvent.Type.HEAL:
			var payload = event.visual_payload
			# HP values are stored in arrays
			var old_hp_arr = payload.targets_old_hp
			var new_hp_arr = payload.targets_new_hp
			var old_hp = int(old_hp_arr[0]) if old_hp_arr.size() > 0 else 0
			var new_hp = int(new_hp_arr[0]) if new_hp_arr.size() > 0 else 0
			var amount = payload.amount
			if amount == 0:
				amount = abs(new_hp - old_hp)
			log_heal(source_name, primary_target, amount, old_hp, new_hp, String(event.ability_id), String(event.trigger_type))
		
		CombatEvent.Type.BUFF:
			var payload = event.visual_payload
			var stat = payload.stat if not payload.stat.is_empty() else "stat"
			var amount = payload.amount if payload.amount != 0 else event.amount
			var is_debuff = amount < 0
			log_buff(source_name, primary_target, stat, abs(amount), is_debuff, String(event.ability_id), String(event.trigger_type))
		
		CombatEvent.Type.DEATH:
			log_death(primary_target)
		
		CombatEvent.Type.SUMMON:
			var payload = event.visual_payload
			var new_snapshot = payload.new_unit_snapshot
			var summoned_name = "New Unit"
			if new_snapshot.has("display_name"):
				summoned_name = str(new_snapshot.get("display_name"))
			log_summon(summoned_name, source_name)
		
		CombatEvent.Type.LOG_MESSAGE:
			if event.text != "":
				log_system(event.text)
		
		CombatEvent.Type.TOKEN_GAIN:
			var payload = event.visual_payload
			var amount = payload.amount
			log_system("Gained %d tokens!" % amount)


func _get_source_name(event: CombatEvent) -> String:
	# First check cached source_name
	if event.source_name != "":
		return event.source_name
	# Then try to resolve from UUID
	if event.source_uuid != "":
		return get_unit_name(event.source_uuid)
	# Check payload for source info
	var payload = event.visual_payload
	if not payload.source_uuid.is_empty():
		return get_unit_name(payload.source_uuid)
	return "System"

func _get_target_names(event: CombatEvent) -> Array[String]:
	var names: Array[String] = []
	# First check cached target_names
	if event.target_names.size() > 0:
		for n in event.target_names:
			names.append(n)
		return names
	# Then resolve from UUIDs
	for uuid in event.target_uuids:
		names.append(get_unit_name(uuid))
	if names.is_empty():
		names.append("Unknown")
	return names

# ========================================
# INTERNAL HELPERS
# ========================================

func _format_ability_context(ability_id: String, trigger_type: String) -> String:
	# Format ability_id and trigger_type into a human-readable context string
	if ability_id.is_empty() and trigger_type.is_empty():
		return ""
	
	var parts: Array[String] = []
	if not ability_id.is_empty():
		# Shorten common ability IDs for readability
		var short_id = ability_id
		if short_id.begins_with("unit_") or short_id.begins_with("item_") or short_id.begins_with("trinket_"):
			# Keep as-is for now, can add shortening later
			pass
		parts.append(short_id)
	if not trigger_type.is_empty():
		parts.append(String(trigger_type))
	
	if parts.is_empty():
		return ""
	return " [color=gray](%s)[/color]" % ", ".join(parts)

func _add_entry(type: String, message: String, details: String, indent_level: int, color_key: String) -> void:
	_event_index += 1
	
	var entry: Dictionary = {
		"turn": _current_turn,
		"event_index": _event_index,
		"type": type,
		"message": message,
		"details": details,
		"indent_level": indent_level,
		"color": COLORS.get(color_key, "white")
	}
	
	_log_entries.append(entry)
	
	# Trim old entries if we exceed max
	while _log_entries.size() > _max_entries:
		_log_entries.pop_front()
	
	log_entry_added.emit(entry)
	
	# Also print to console for debugging
	var indent_str = "  ".repeat(indent_level)
	if indent_level > 0:
		indent_str = "└─ "
	var console_msg = "[%d:%d] %s %s" % [_current_turn, _event_index, indent_str + _strip_bbcode(message), details]
	# print("[BattleLog] " + console_msg)

func _strip_bbcode(text: String) -> String:
	# Remove BBCode tags for console output
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)

func _on_battle_phase_changed(phase_name: String) -> void:
	if phase_name == "START_OF_TURN":
		_current_turn += 1
		log_turn_start(_current_turn)
	elif phase_name == "BATTLE_OVER":
		log_system("Battle ended")

# ========================================
# HELPER TO GET UNIT NAME FROM UUID
# ========================================

func get_unit_name(uuid: String) -> String:
	if uuid.is_empty():
		return "Unknown"
	
	# Try to get from GameManager
	var inst = GameManager.get_instance_by_uuid(uuid)
	if is_instance_valid(inst):
		var def = inst.get_definition()
		if is_instance_valid(def) and "display_name_key" in def:
			return tr(def.display_name_key)
		if is_instance_valid(def) and "id" in def:
			return String(def.id)
	
	return uuid.substr(0, 8) + "..."
func _init() -> void:
	# Clear the log file at the start of every session so we only get the latest output
	var file := FileAccess.open("res://log.txt", FileAccess.WRITE)
	if is_instance_valid(file):
		file.store_string("")
		file.close()
