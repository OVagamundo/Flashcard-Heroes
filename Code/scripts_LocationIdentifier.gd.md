<!-- Original: scripts/LocationIdentifier.gd -->

```gdscript
class_name LocationIdentifier
extends Resource

## A data resource for identifying a slot in a container.

@export var container: StringName = &""
@export var index: int = -1

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
	return container == other.container and index == other.index

```