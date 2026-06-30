# res://scripts/TutorialManager.gd
extends Node

## Manages the tutorial and tooltip system state.
## Tracks which tutorials have been completed, and whether
## tutorials/tooltips are enabled (controlled by Loadout checkbox).

const SAVE_PATH := "user://tutorial_settings.save"

## Whether tutorials and tooltips are enabled (controlled by Loadout checkbox)
var tutorials_enabled: bool = true

## Dictionary of completed tutorial IDs (StringName -> true)
var _completed_tutorials: Dictionary = {}


func _ready() -> void:
	load_settings()
	SignalBus.tutorial_requested.connect(_on_tutorial_requested)


# --- Public API ---

## Check if a specific tutorial has been completed
func is_completed(tutorial_id: StringName) -> bool:
	return _completed_tutorials.has(tutorial_id)


## Mark a tutorial as completed and save
func mark_completed(tutorial_id: StringName) -> void:
	_completed_tutorials[tutorial_id] = true
	save_settings()


## Show a tutorial popup if enabled and not yet completed
## @param tutorial_id: Unique identifier for this tutorial
## @param pages: Array of dictionaries with keys: text (String), anchor_path (optional String)
## @param anchor: Optional Control to point an arrow at
func show_tutorial(tutorial_id: StringName, pages: Array, anchor: Control = null) -> void:
	if not tutorials_enabled:
		return
	if is_completed(tutorial_id):
		return
	
	SignalBus.emit_signal("tutorial_requested", tutorial_id, pages, anchor)


## Show a tutorial popup and WAIT until it's dismissed
## Use this when calling from combat animations or other sequences that should pause
## @returns: Signal that completes when tutorial is dismissed (or immediately if not shown)
func show_blocking_tutorial(tutorial_id: StringName, pages: Array) -> void:
	if not tutorials_enabled:
		return
	if is_completed(tutorial_id):
		return
	
	SignalBus.emit_signal("blocking_tutorial_requested", tutorial_id, pages)
	
	# Wait for this specific tutorial to be dismissed
	await SignalBus.tutorial_dismissed


## Get tooltip text for an element if tutorials are enabled
## Returns empty string if disabled
func get_tooltip(element_id: StringName) -> String:
	if not tutorials_enabled:
		return ""
	var key := "tooltip." + String(element_id)
	var translated := tr(key)
	# If translation returns the key itself, there's no tooltip defined
	if translated == key:
		return ""
	return translated


## Reset all tutorial progress (for testing)
func reset_all_tutorials() -> void:
	_completed_tutorials.clear()
	save_settings()


# --- Persistence ---

func save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[TutorialManager] Failed to open save file: " + SAVE_PATH)
		return
	
	var data := {
		"tutorials_enabled": tutorials_enabled,
		"completed_tutorials": _completed_tutorials.keys()
	}
	file.store_var(data)
	file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[TutorialManager] Failed to open save file for reading: " + SAVE_PATH)
		return
	
	var data: Variant = file.get_var()
	file.close()
	
	if data is Dictionary:
		tutorials_enabled = data.get("tutorials_enabled", true)
		var completed_list: Array = data.get("completed_tutorials", [])
		_completed_tutorials.clear()
		for id in completed_list:
			_completed_tutorials[StringName(id)] = true


# --- Signal Handlers ---

func _on_tutorial_requested(tutorial_id: StringName, pages: Array, anchor: Control) -> void:
	# Use open_tutorial_overlay instead of open_modal_window
	# This prevents tutorials from closing existing windows like FlashcardMinigame
	WindowManager.open_tutorial_overlay({
		"tutorial_id": tutorial_id,
		"pages": pages,
		"anchor": anchor
	})
