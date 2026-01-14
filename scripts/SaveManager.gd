# res://scripts/SaveManager.gd
extends Node

## Manages saving and loading of run progress.
## Saves occur when entering the path choice scene.
## Saves are cleared on game over or victory.

const SAVE_PATH := "user://run_save.dat"


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
	print("[SaveManager] Run saved successfully (Day %d)" % run_state.day)
	return true


## Loads a saved run state from disk.
## Returns a populated RunState on success, null on failure or if no save exists.
func load_run() -> RunState:
	if not has_save():
		return null
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open save file for reading: %s" % SAVE_PATH)
		return null
	
	var data: Variant = file.get_var()
	file.close()
	
	if not data is Dictionary:
		push_error("[SaveManager] Save file contains invalid data")
		return null
	
	var run_state := RunState.new()
	run_state.from_save_dict(data)
	print("[SaveManager] Run loaded successfully (Day %d)" % run_state.day)
	return run_state


## Returns true if a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Deletes the save file if it exists.
func clear_save() -> void:
	if has_save():
		var err := DirAccess.remove_absolute(SAVE_PATH)
		if err == OK:
			print("[SaveManager] Save file cleared")
		else:
			push_error("[SaveManager] Failed to clear save file: %d" % err)
