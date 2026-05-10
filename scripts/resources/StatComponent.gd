class_name StatComponent
extends GachaBallComponent

@export var modifiers: Dictionary = {}
@export var mirrors_legacy_base_modifier: bool = false


func get_component_type() -> StringName:
	return &"stat"


func to_save_dict() -> Dictionary:
	var data := _get_base_save_dict()
	data["modifiers"] = modifiers.duplicate(true)
	data["mirrors_legacy_base_modifier"] = mirrors_legacy_base_modifier
	return data


func load_component_save_dict(data: Dictionary) -> void:
	modifiers = data.get("modifiers", {}).duplicate(true)
	mirrors_legacy_base_modifier = bool(data.get("mirrors_legacy_base_modifier", false))
