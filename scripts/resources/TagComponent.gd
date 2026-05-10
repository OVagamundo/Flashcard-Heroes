class_name TagComponent
extends GachaBallComponent

@export var tags_to_add: Array[StringName] = []
@export var tags_to_remove: Array[StringName] = []
@export var attributes: Dictionary = {}


func get_component_type() -> StringName:
	return &"tag"


func to_save_dict() -> Dictionary:
	var data := _get_base_save_dict()
	data["tags_to_add"] = _serialize_string_names(tags_to_add)
	data["tags_to_remove"] = _serialize_string_names(tags_to_remove)
	data["attributes"] = attributes.duplicate(true)
	return data


func load_component_save_dict(data: Dictionary) -> void:
	tags_to_add = _deserialize_string_names(data.get("tags_to_add", []))
	tags_to_remove = _deserialize_string_names(data.get("tags_to_remove", []))
	attributes = data.get("attributes", {}).duplicate(true)


func _serialize_string_names(values: Array[StringName]) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	return result


func _deserialize_string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(str(value)))
	return result
