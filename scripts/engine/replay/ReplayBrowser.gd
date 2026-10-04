extends Control

@onready var _recordings_list: VBoxContainer = %RecordingsList
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	ReplayController.playback_error.connect(_on_playback_error)
	%CloseButton.pressed.connect(_on_close_pressed)
	_populate_recordings()

func _exit_tree() -> void:
	if ReplayController.playback_error.is_connected(_on_playback_error):
		ReplayController.playback_error.disconnect(_on_playback_error)

func _populate_recordings() -> void:
	for child in _recordings_list.get_children():
		child.queue_free()
	var recordings: Array[Dictionary] = GameplayRecorder.get_replay_files()
	if recordings.is_empty():
		_status_label.text = "No recordings yet. New runs are recorded automatically."
		return
	_status_label.text = "%d recordings" % recordings.size()
	for recording in recordings:
		var error := String(recording.get("error", ""))
		if not error.is_empty():
			var invalid_button := Button.new()
			invalid_button.custom_minimum_size.y = 58.0
			invalid_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			invalid_button.text = "Unreadable replay | %s" % String(recording.get("run_id", ""))
			invalid_button.tooltip_text = error
			invalid_button.disabled = true
			_recordings_list.add_child(invalid_button)
			continue
		var hero_id := String(recording.get("hero_def_id", "Unknown hero"))
		var seed := int(recording.get("run_seed", 0))
		var count := int(recording.get("event_count", 0))
		var run_id := String(recording.get("run_id", ""))
		var button := Button.new()
		button.custom_minimum_size.y = 58.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s  |  Seed %d  |  %d events  |  %s" % [hero_id, seed, count, run_id]
		button.pressed.connect(_on_recording_selected.bind(String(recording.get("path", ""))))
		_recordings_list.add_child(button)

func _on_recording_selected(path: String) -> void:
	if path.is_empty():
		return
	_status_label.text = "Loading replay…"
	for child in _recordings_list.get_children():
		if child is BaseButton:
			child.disabled = true
	ReplayController.play_file(path)

func _on_close_pressed() -> void:
	queue_free()

func _on_playback_error(message: String) -> void:
	_status_label.text = message
	for child in _recordings_list.get_children():
		if child is BaseButton:
			child.disabled = false
