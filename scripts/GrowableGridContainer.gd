class_name GrowableGridContainer
extends DataContainer

## A DataContainer for growable collections like inventories.
## It is backed by an Array and contains its own internal growth logic.

var _data: Array[String] = []
var _growth_amount: int = 4

func _init(initial_size: int, growth_amount: int = 4):
	_data.resize(initial_size)
	_data.fill("") # Use empty string for null/empty
	_growth_amount = growth_amount

func get_uuid(index: int) -> String:
	if index >= 0 and index < _data.size():
		return _data[index]
	return ""

func set_uuid(index: int, uuid: String) -> void:
	if index >= 0 and index < _data.size():
		_data[index] = uuid

func find_first_empty_slot() -> int:
	var index = _data.find("")
	if index == -1:
		# Grow the container if no empty slot is found.
		var old_size = _data.size()
		_data.resize(old_size + _growth_amount)
		_data.fill("")
		return old_size # The first new empty slot
	return index

func find_uuid(uuid: String) -> int:
	if uuid.is_empty(): return -1
	return _data.find(uuid)

func get_all_uuids() -> Array[String]:
	return _data.duplicate()

func clear() -> void:
	_data.fill("")
