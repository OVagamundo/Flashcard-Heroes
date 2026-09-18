class_name LocationIdentifier
extends Resource

## A data resource for identifying a slot in a container.

@export var container: StringName = &""
@export var index: int = -1
@export var unit_uuid: String = "" # UUID of the unit an item is equipped to.

## Creates a new LocationIdentifier with the given container and index.
func _init(p_container: StringName = &"", p_index: int = -1) -> void:
	container = p_container
	index = p_index

## Creates a new LocationIdentifier with the given container and index.
func set_values(p_container: StringName = &"", p_index: int = -1) -> void:
	container = p_container
	index = p_index

## Checks if this LocationIdentifier is equal to another.
func is_equal(other: LocationIdentifier) -> bool:
	if not is_instance_valid(other):
		return false
	return container == other.container and index == other.index and unit_uuid == other.unit_uuid

## Serializes this location into a pure dictionary.
func to_dict() -> Dictionary:
	return {
		"container": String(container),
		"index": index,
		"unit_uuid": unit_uuid
	}

## Populates this location from a dictionary.
func from_dict(data: Dictionary) -> void:
	container = StringName(data.get("container", ""))
	index = int(data.get("index", -1))
	unit_uuid = String(data.get("unit_uuid", ""))

## Static factory to instantiate a LocationIdentifier from a dictionary.
static func create_from_dict(data: Dictionary) -> LocationIdentifier:
	var loc := LocationIdentifier.new(StringName(data.get("container", "")), int(data.get("index", -1)))
	loc.unit_uuid = String(data.get("unit_uuid", ""))
	return loc

