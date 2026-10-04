extends CanvasLayer

@onready var _action_indicator: Control = %ActionIndicatorMargin
@onready var _action_label: Label = %ActionLabel
@onready var _pause_popup: Control = %PausePopup
@onready var _title_label: Label = %TitleLabel
@onready var _info_label: Label = %InfoLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _exit_button: Button = %ExitButton

var _current_action_seq: int = 0
var _total_actions: int = 0
var _hero_id: String = ""
var _seed: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_on_resume_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

	ReplayController.playback_started.connect(_on_playback_started)
	ReplayController.playback_progress.connect(_on_playback_progress)
	ReplayController.playback_finished.connect(_on_playback_finished)
	ReplayController.playback_error.connect(_on_playback_error)
	ReplayController.playback_paused.connect(_on_playback_paused)
	ReplayController.playback_speed_changed.connect(_on_speed_changed)
	if ReplayController.has_signal("action_executing"):
		ReplayController.action_executing.connect(_on_action_executing)

	_action_indicator.visible = true
	_pause_popup.visible = false
	_update_action_display()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var handled := true
	match event.keycode:
		KEY_TAB:
			_action_indicator.visible = not _action_indicator.visible
		KEY_ESCAPE:
			_toggle_pause_menu()
		KEY_1, KEY_KP_1:
			ReplayController.set_playback_speed(1.0)
		KEY_2, KEY_KP_2:
			ReplayController.set_playback_speed(2.0)
		KEY_3, KEY_KP_3:
			ReplayController.set_playback_speed(3.0)
		KEY_4, KEY_KP_4:
			ReplayController.set_playback_speed(4.0)
		KEY_5, KEY_KP_5:
			ReplayController.set_playback_speed(5.0)
		KEY_6, KEY_KP_6:
			ReplayController.set_playback_speed(6.0)
		KEY_7, KEY_KP_7:
			ReplayController.set_playback_speed(7.0)
		KEY_8, KEY_KP_8:
			ReplayController.set_playback_speed(8.0)
		KEY_9, KEY_KP_9:
			ReplayController.set_playback_speed(9.0)
		KEY_0, KEY_KP_0:
			ReplayController.set_playback_speed(10.0)
		_:
			handled = false

	if handled:
		get_viewport().set_input_as_handled()

func _toggle_pause_menu() -> void:
	if _pause_popup.visible:
		if not _resume_button.visible:
			_on_exit_pressed()
			return
		_on_resume_pressed()
	else:
		_title_label.text = "Replay Paused"
		_resume_button.visible = true
		_pause_popup.visible = true
		ReplayController.set_playback_paused(true)
		_update_info_label()

func _on_resume_pressed() -> void:
	_pause_popup.visible = false
	ReplayController.set_playback_paused(false)

func _on_exit_pressed() -> void:
	_pause_popup.visible = false
	ReplayController.exit_replay()

func _on_action_executing(action_sequence: int, _action_type: String) -> void:
	_current_action_seq = action_sequence
	_update_action_display()

func _on_playback_progress(completed: int, total: int) -> void:
	_total_actions = total
	_update_action_display()
	_update_info_label()

func _update_action_display() -> void:
	if is_instance_valid(_action_label):
		_action_label.text = "Action #%d" % _current_action_seq

func _update_info_label() -> void:
	if is_instance_valid(_info_label):
		_info_label.text = "Hero: %s | Seed: %d\nAction %d / %d | %.0fx Speed" % [
			_hero_id,
			_seed,
			_current_action_seq,
			_total_actions,
			ReplayController.get_playback_speed()
		]

func _on_playback_started(header: Dictionary, action_count: int) -> void:
	_hero_id = String(header.get("hero_def_id", header.get("hero_id", "Hero")))
	_seed = int(header.get("run_seed", header.get("seed", 0)))
	_total_actions = action_count
	_current_action_seq = 0
	_update_action_display()
	_update_info_label()

func _on_playback_finished() -> void:
	_action_label.text = "Completed"
	_title_label.text = "Replay Complete"
	_resume_button.visible = false
	_pause_popup.visible = true
	_update_info_label()

func _on_playback_error(message: String) -> void:
	_action_label.text = "Error"
	_title_label.text = "Replay Error"
	_resume_button.visible = false
	_pause_popup.visible = true
	if is_instance_valid(_info_label):
		_info_label.text = message

func _on_playback_paused(is_paused: bool) -> void:
	if is_paused and not _pause_popup.visible:
		_title_label.text = "Replay Paused"
		_resume_button.visible = true
		_pause_popup.visible = true
		_update_info_label()
	elif not is_paused and _pause_popup.visible:
		_pause_popup.visible = false

func _on_speed_changed(_speed: float) -> void:
	_update_info_label()
