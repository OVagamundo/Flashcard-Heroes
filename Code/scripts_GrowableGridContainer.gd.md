<!-- Original: scripts/GrowableGridContainer.gd -->

```gdscript
class_name GrowableGridContainer extends DataContainer

## Backing array for UUID storage
var _data: Array[String] = []

## List of available (empty) slot indices for efficient slot reuse
var _free_list: Array[int] = []

## Amount to expand by when container is full
var _growth_amount: int = 16

## Initialize with an initial size (default 16 per TDD Initial Size Rule)
func _init(initial_size: int = 16):
	_data.resize(initial_size)
	for i in range(initial_size):
		_data[i] = ""
		_free_list.append(i)

## Returns the UUID at the specified index
func get_uuid(index: int) -> String:
	if not is_valid_index(index):
		return ""
	return _data[index]

## Sets the UUID at the specified index
func set_uuid(index: int, uuid: String) -> void:
	if not is_valid_index(index):
		push_error("GrowableGridContainer: Invalid index %d" % index)
		return
	
	var was_empty = _data[index] == ""
	_data[index] = uuid
	
	# Update free list based on whether slot is now occupied or freed
	if was_empty and uuid != "":
		_free_list.erase(index)
	elif not was_empty and uuid == "":
		_free_list.append(index)

## Returns the first available slot index, or -1 if full
func find_first_empty_slot() -> int:
	if _free_list.is_empty():
		_expand_container()
	if _free_list.is_empty():
		return -1
	# Return the lowest available index to honor "first available slot" semantics
	var min_index: int = _free_list[0]
	for idx in _free_list:
		if idx < min_index:
			min_index = idx
	return min_index

## Checks if an index is within bounds
func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _data.size()

## Returns the current capacity of the container
func get_size() -> int:
	return _data.size()

## Returns true if the container has no items
func is_empty() -> bool:
	return _free_list.size() == _data.size()

## Returns an array of all non-empty UUIDs in the container
func get_all_non_empty_uuids() -> Array[String]:
	var result: Array[String] = []
	for i in range(_data.size()):
		if _data[i] != "":
			result.append(_data[i])
	return result

## Returns an array of all UUIDs in the container (including empty ones)
func get_all_uuids() -> Array[String]:
	return _data.duplicate()

## Expands the container by _growth_amount slots
func _expand_container() -> void:
	var old_size = _data.size()
	var new_size = old_size + _growth_amount
	
	_data.resize(new_size)
	for i in range(old_size, new_size):
		_data[i] = ""
		_free_list.append(i)

```