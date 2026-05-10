class_name GachaBallComponent
extends Resource

@export var id: StringName
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var category: StringName
@export var source_type: StringName
@export var source_id: String = ""
@export var priority: int = 0
@export var allow_stacking: bool = false
@export var is_persistent: bool = true
@export var is_battle_only: bool = false
@export var metadata: Dictionary = {}


func get_component_type() -> StringName:
	return &"base"


func to_save_dict() -> Dictionary:
	return _get_base_save_dict()


func _get_base_save_dict() -> Dictionary:
	return {
		"type": String(get_component_type()),
		"id": String(id),
		"display_name_key": display_name_key,
		"description_key": description_key,
		"category": String(category),
		"source_type": String(source_type),
		"source_id": source_id,
		"priority": priority,
		"allow_stacking": allow_stacking,
		"is_persistent": is_persistent,
		"is_battle_only": is_battle_only,
		"metadata": metadata.duplicate(true),
	}


func load_base_save_dict(data: Dictionary) -> void:
	id = StringName(data.get("id", ""))
	display_name_key = data.get("display_name_key", "")
	description_key = data.get("description_key", "")
	category = StringName(data.get("category", ""))
	source_type = StringName(data.get("source_type", ""))
	source_id = data.get("source_id", "")
	priority = int(data.get("priority", 0))
	allow_stacking = bool(data.get("allow_stacking", false))
	is_persistent = bool(data.get("is_persistent", true))
	is_battle_only = bool(data.get("is_battle_only", false))
	metadata = data.get("metadata", {}).duplicate(true)


static func from_save_dict(data: Dictionary) -> GachaBallComponent:
	var component_type := StringName(data.get("type", "base"))
	var component: GachaBallComponent
	match component_type:
		&"stat":
			component = StatComponent.new()
		&"ability":
			component = AbilityComponent.new()
		&"tag":
			component = TagComponent.new()
		&"visual":
			component = VisualComponent.new()
		_:
			component = GachaBallComponent.new()
	component.load_base_save_dict(data)
	if component.has_method("load_component_save_dict"):
		component.call("load_component_save_dict", data)
	return component
