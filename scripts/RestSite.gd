# res://scripts/RestSite.gd
extends VBoxContainer

@onready var train_hp_button: Button = %TrainHPButton
@onready var train_pwr_button: Button = %TrainPWRButton
@onready var leave_button: Button = %LeaveButton

enum TrainingType { NONE, HP, PWR }
var _current_training: TrainingType = TrainingType.NONE
var _last_minigame_results: Dictionary = {}

func _ready() -> void:
	train_hp_button.pressed.connect(_on_train_pressed.bind(TrainingType.HP))
	train_pwr_button.pressed.connect(_on_train_pressed.bind(TrainingType.PWR))
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Connect to flashcard completion signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	SignalBus.results_acknowledged.connect(_on_results_acknowledged)

func _on_train_pressed(type: TrainingType) -> void:
	_current_training = type
	train_hp_button.disabled = true
	train_pwr_button.disabled = true
	
	# TDD Section 9.4: Rest Site "Train" Flow
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_flashcard_completed(results: Dictionary) -> void:
	# TDD Section 9.4: Rest Site "Train" Flow
	if _current_training == TrainingType.NONE:
		return
	
	_last_minigame_results = results
	
	var correct_answers: int = results.get("correct_answers", 0)
	var stat_gain = floori(correct_answers / 2.0)  # TDD: stat_gain = floor(results.correct_answers / 2.0)
	
	# Determine stat type for display
	var stat_type = "HP" if _current_training == TrainingType.HP else "PWR"
	
	# Display ResultsPopup
	var _popup = WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Training Complete!", "Your Hero gained +%d %s." % [stat_gain, stat_type], "Continue"]
	})

func _on_results_acknowledged() -> void:
	"""Called when player acknowledges the training results"""
	if _current_training == TrainingType.NONE: return
	
	var correct_answers: int = _last_minigame_results.get("correct_answers", 0)
	var stat_gain = floori(correct_answers / 2.0)
	
	if stat_gain > 0 and is_instance_valid(GameManager.run_state):
		var hero_uuid = GameManager.run_state.hero_instance.ball_uuid
		if _current_training == TrainingType.HP:
			GameManager.run_state.modify_unit_stats(hero_uuid, stat_gain, 0)
		elif _current_training == TrainingType.PWR:
			GameManager.run_state.modify_unit_stats(hero_uuid, 0, stat_gain)
	
	_last_minigame_results.clear()
	_current_training = TrainingType.NONE
	train_hp_button.disabled = false
	train_pwr_button.disabled = false

func _on_leave_pressed() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _exit_tree() -> void:
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
	if SignalBus.is_connected("results_acknowledged", _on_results_acknowledged):
		SignalBus.results_acknowledged.disconnect(_on_results_acknowledged)
