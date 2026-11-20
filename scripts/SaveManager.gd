# res://scripts/SaveManager.gd
extends Node

## Manages saving and loading of run progress.
## Saves occur when entering the path choice scene.
## Saves are cleared on game over or victory.

const SAVE_PATH := "user://run_save.dat"
const LOADOUT_SEED_PATH := "user://loadout_seed.dat"

var _loadout_seed: int = -1


## Saves the current run state to disk.
## Returns true on success, false on failure.
func save_run(run_state: RunState) -> bool:
	if not is_instance_valid(run_state):
		push_error("[SaveManager] Cannot save: Invalid run_state")
		return false
	
	var data: Dictionary = run_state.to_save_dict()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open save file for writing: %s" % SAVE_PATH)
		return false
	
	file.store_var(data)
	file.close()
	return true


## Loads a saved run state from disk.
## Returns a populated RunState on success, null on failure or if no save exists.
func load_run() -> RunState:
	var data: Dictionary = _read_run_data()
	if data.is_empty():
		return null
	var run_state := RunState.new()
	run_state.from_save_dict(data)
	return run_state
	
func _read_run_data() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open save file for reading: %s" % SAVE_PATH)
		return {}
	
	var data: Variant = file.get_var()
	file.close()
	
	if not data is Dictionary:
		push_error("[SaveManager] Save file contains invalid data")
		return {}
	return data
	
## One seed backs every hero's Loadout preview until a live run ends.
func get_loadout_seed() -> int:
	if _loadout_seed != -1:
		return _loadout_seed
	if FileAccess.file_exists(LOADOUT_SEED_PATH):
		var saved_seed: FileAccess = FileAccess.open(LOADOUT_SEED_PATH, FileAccess.READ)
		if saved_seed != null and saved_seed.get_length() == 8:
			_loadout_seed = saved_seed.get_64()
			if _loadout_seed != -1:
				return _loadout_seed
		push_error("[SaveManager] Invalid Loadout seed file")

	# Preserve the seed for a run saved before the Loadout preview was added.
	_loadout_seed = int(_read_run_data().get("run_seed", -1))
	if _loadout_seed == -1:
		_loadout_seed = RNGManager.generate_master_seed()
	var file: FileAccess = FileAccess.open(LOADOUT_SEED_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to save the Loadout seed: %s" % LOADOUT_SEED_PATH)
	else:
		file.store_64(_loadout_seed)
	return _loadout_seed


## Returns true if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Clears the finished run and releases the Loadout roll for the next run.
func clear_save() -> void:
	if has_save():
		var err := DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_error("[SaveManager] Failed to clear save file: %d" % err)
			return
	if FileAccess.file_exists(LOADOUT_SEED_PATH):
		var err: Error = DirAccess.remove_absolute(LOADOUT_SEED_PATH)
		if err != OK:
			push_error("[SaveManager] Failed to clear the Loadout seed: %d" % err)
			return
	_loadout_seed = -1
