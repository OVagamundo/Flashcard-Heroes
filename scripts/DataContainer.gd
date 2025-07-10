class_name DataContainer
extends Object

## The abstract base class for all data collections (inventories, lineups, etc.).
## Defines the public interface for interacting with any container, hiding
## the underlying implementation (Array, Dictionary, etc.).

func get_uuid(_index: int) -> String:
	push_error("get_uuid() must be implemented by a subclass.")
	return ""

func set_uuid(_index: int, _uuid: String) -> void:
	push_error("set_uuid() must be implemented by a subclass.")

func find_first_empty_slot() -> int:
	push_error("find_first_empty_slot() must be implemented by a subclass.")
	return -1

func get_all_uuids() -> Array[String]:
	push_error("get_all_uuids() must be implemented by a subclass.")
	return []

func get_all_non_empty_uuids() -> Array[String]:
	var all_uuids = get_all_uuids()
	return all_uuids.filter(func(uuid): return not uuid.is_empty())
