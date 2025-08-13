class_name FixedArrayContainer extends DataContainer

## Backing array for UUID storage
var _data: Array[String] = []

## Fixed size of the container
var _size: int

## Initialize with a fixed size
func _init(initial_size: int) -> void:
	_size = initial_size
	_data.resize(initial_size)
	for i in range(initial_size):
		_data[i] = ""

## Returns the UUID at the specified index
func get_uuid(index: int) -> String:
	if not is_valid_index(index):
		return ""
	return _data[index]

## Sets the UUID at the specified index
func set_uuid(index: int, uuid: String) -> void:
	if not is_valid_index(index):
		push_error("FixedArrayContainer: Invalid index %d" % index)
		return
	_data[index] = uuid

## Returns the first available slot index, or -1 if full
func find_first_empty_slot() -> int:
	for i in range(_size):
		if _data[i] == "":
			return i
	return -1

## Checks if an index is within bounds
func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _size

## Returns the current capacity of the container
func get_size() -> int:
	return _size

## Returns true if the container has no items
func is_empty() -> bool:
	for uuid in _data:
		if uuid != "":
			return false
	return true

## Returns an array of all non-empty UUIDs in the container
func get_all_non_empty_uuids() -> Array[String]:
	var result: Array[String] = []
	for uuid in _data:
		if uuid != "":
			result.append(uuid)
	return result

## Returns an array of all UUIDs in the container (including empty ones)
func get_all_uuids() -> Array[String]:
	return _data.duplicate()
