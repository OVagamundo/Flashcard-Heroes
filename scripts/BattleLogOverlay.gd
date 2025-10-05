# scripts/BattleLogOverlay.gd
class_name BattleLogOverlay
extends CanvasLayer

@onready var log_text: RichTextLabel = %LogText

func _ready() -> void:
	# The overlay is hidden by default and only shown for debugging.
	self.visible = false
	SignalBus.log_animation_event.connect(_on_animation_event_logged)

func _unhandled_input(event: InputEvent) -> void:
	# A toggle to show/hide the overlay during testing.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		self.visible = not self.visible

func _on_animation_event_logged(event: CombatEvent) -> void:
	var message = _translate_event_to_string(event)
	if not message.is_empty():
		_add_log_entry(message)

func _add_log_entry(message: String) -> void:
	log_text.append_text(message + "\n")

func _translate_event_to_string(event: CombatEvent) -> String:
	var source_name = _resolve_source_name(event)
	var target_names = _resolve_target_names(event)
	var target_list_str = _join_names(target_names)
	var primary_target = target_names[0] if target_names.size() > 0 else "[b]Unknown Target[/b]"

	match event.type:
		CombatEvent.Type.DAMAGE:
			if target_names.is_empty():
				return ""
			var damage = abs(event.amount)
			return "%s attacks %s, dealing [color=red]%d damage[/color]." % [source_name, primary_target, damage]

		CombatEvent.Type.HEAL:
			if target_names.is_empty():
				return ""
			var healing = event.amount
			return "%s heals %s for [color=green]%d HP[/color]." % [source_name, target_list_str, healing]

		CombatEvent.Type.STAT_BUFF:
			if target_names.is_empty():
				return ""
			var buff_amount = event.amount
			var stat_name = event.stat.to_upper()
			return "%s buffs %s for [color=cyan]+%d %s[/color]." % [source_name, target_list_str, buff_amount, stat_name]

		CombatEvent.Type.DEATH:
			if target_names.is_empty():
				return ""
			return "%s has been defeated!" % primary_target
	
	return "" # Ignore other event types for this log.

func _resolve_source_name(event: CombatEvent) -> String:
	var cached: String = String(event.source_name).strip_edges()
	if cached != "":
		return "[b]%s[/b]" % cached
	if event.source_uuid == "":
		return "[b]System[/b]"
	var inst = GameManager.get_instance_by_uuid(event.source_uuid)
	if is_instance_valid(inst):
		var definition = inst.get_definition()
		var display_name := _get_definition_display_name(definition)
		if display_name != "":
			return "[b]%s[/b]" % display_name
	return "[b]System[/b]"

func _resolve_target_names(event: CombatEvent) -> Array[String]:
	var resolved: Array[String] = []
	var cached_names: Array[String] = event.target_names
	for i in range(max(event.target_uuids.size(), cached_names.size())):
		var cached := ""
		if i < cached_names.size():
			cached = String(cached_names[i]).strip_edges()
		var label := cached
		if label == "":
			var uuid := ""
			if i < event.target_uuids.size():
				uuid = event.target_uuids[i]
			if uuid != "":
				var inst = GameManager.get_instance_by_uuid(uuid)
				if is_instance_valid(inst):
					label = _get_definition_display_name(inst.get_definition())
				elif label == "":
					label = uuid
		if label == "":
			label = "Unknown Target"
		resolved.append("[b]%s[/b]" % label)
	return resolved

func _join_names(names: Array[String]) -> String:
	if names.is_empty():
		return "[b]Unknown Target[/b]"
	if names.size() == 1:
		return names[0]
	var result := names[0]
	for i in range(1, names.size()):
		if i == names.size() - 1:
			result += " and " + names[i]
		else:
			result += ", " + names[i]
	return result

func _get_definition_display_name(definition: Resource) -> String:
	if not is_instance_valid(definition):
		return ""
	if "display_name_key" in definition:
		return tr(definition.display_name_key)
	if "name_key" in definition:
		return tr(definition.name_key)
	if "name" in definition:
		return tr(definition.name)
	if "id" in definition:
		return String(definition.id)
	return ""
