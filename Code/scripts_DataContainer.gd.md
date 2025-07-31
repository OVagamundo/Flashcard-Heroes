<!-- Original: scripts/DataContainer.gd -->

```gdscript
class_name DataContainer extends RefCounted

## Abstract methods that must be implemented by concrete container classes

## Returns the UUID at the specified index
func get_uuid(index: int) -> String:
	push_error("DataContainer.get_uuid() must be overridden")
	return ""

## Sets the UUID at the specified index
func set_uuid(index: int, uuid: String) -> void:
	push_error("DataContainer.set_uuid() must be overridden")

## Returns the first available slot index, or -1 if full
func find_first_empty_slot() -> int:
	push_error("DataContainer.find_first_empty_slot() must be overridden")
	return -1

## Checks if an index is within bounds
func is_valid_index(index: int) -> bool:
	push_error("DataContainer.is_valid_index() must be overridden")
	return false

## Returns the current capacity of the container
func get_size() -> int:
	push_error("DataContainer.get_size() must be overridden")
	return 0

## Returns true if the container has no items
func is_empty() -> bool:
	push_error("DataContainer.is_empty() must be overridden")
	return true

## Returns an array of all non-empty UUIDs in the container
func get_all_non_empty_uuids() -> Array[String]:
	push_error("DataContainer.get_all_non_empty_uuids() must be overridden")
	return []

## Returns an array of all UUIDs in the container (including empty ones)
func get_all_uuids() -> Array[String]:
	push_error("DataContainer.get_all_uuids() must be overridden")
	return []

```