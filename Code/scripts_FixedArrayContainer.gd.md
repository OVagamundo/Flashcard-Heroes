<!-- Original: scripts/FixedArrayContainer.gd -->

```gdscript
class_name FixedArrayContainer
extends "res://scripts/DataContainer.gd"

## A DataContainer for fixed-size collections like lineups and benches.
## It is backed by a simple Array.

var _data: Array[String] = []

func _init(size: int):
	_data.resize(size)
	_data.fill("") # Use empty string for null/empty

func get_uuid(index: int) -> String:
	if index >= 0 and index < _data.size():
		return _data[index]
	return ""

func set_uuid(index: int, uuid: String) -> void:
	if index >= 0 and index < _data.size():
		_data[index] = uuid

func find_first_empty_slot() -> int:
	return _data.find("")

func get_all_uuids() -> Array[String]:
	return _data.duplicate()

```