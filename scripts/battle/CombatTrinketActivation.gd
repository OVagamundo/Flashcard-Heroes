class_name CombatTrinketActivation
extends RefCounted

## Identifies one trinket activation to be shown alongside a CombatEvent.

var visual_uuid: String = ""
var definition_id: StringName = &""
var is_enemy: bool = false

func _init(p_definition_id: StringName = &"", p_is_enemy: bool = false, p_visual_uuid: String = "") -> void:
	definition_id = p_definition_id
	is_enemy = p_is_enemy
	visual_uuid = p_visual_uuid

func deep_clone() -> CombatTrinketActivation:
	return CombatTrinketActivation.new(definition_id, is_enemy, visual_uuid)
