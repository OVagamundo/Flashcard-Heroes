class_name AbilityComponent
extends GachaBallComponent

@export var ability_definitions: Array[AbilityDefinition] = []
@export_enum("ADD", "REPLACE", "DISABLE") var mode: String = "ADD"
@export var target_ability_id: StringName = &""
@export var ability_ids: Array[StringName] = []


func get_component_type() -> StringName:
	return &"ability"


func to_save_dict() -> Dictionary:
	var data := _get_base_save_dict()
	data["mode"] = mode
	data["target_ability_id"] = String(target_ability_id)
	data["ability_ids"] = _serialize_ability_ids()
	return data


func load_component_save_dict(data: Dictionary) -> void:
	mode = data.get("mode", "ADD")
	target_ability_id = StringName(data.get("target_ability_id", ""))
	ability_ids.clear()
	for ability_id in data.get("ability_ids", []):
		ability_ids.append(StringName(str(ability_id)))
	_resolve_ability_definitions()


func add_ability_definition(ability_def: AbilityDefinition) -> void:
	if not is_instance_valid(ability_def):
		return
	ability_definitions.append(ability_def)
	if not ability_ids.has(ability_def.id):
		ability_ids.append(ability_def.id)


func _serialize_ability_ids() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for ability_id in ability_ids:
		if not seen.has(ability_id):
			result.append(String(ability_id))
			seen[ability_id] = true
	for ability_def in ability_definitions:
		if is_instance_valid(ability_def) and not seen.has(ability_def.id):
			result.append(String(ability_def.id))
			seen[ability_def.id] = true
	return result


func _resolve_ability_definitions() -> void:
	ability_definitions.clear()
	for ability_id in ability_ids:
		var ability_def := Database.get_ability_definition(ability_id)
		if is_instance_valid(ability_def):
			ability_definitions.append(ability_def)
