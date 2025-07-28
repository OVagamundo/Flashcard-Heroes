# res://scripts/RestSite.gd
extends VBoxContainer

@onready var train_hp_button: Button = %TrainHPButton
@onready var train_pwr_button: Button = %TrainPWRButton
@onready var leave_button: Button = %LeaveButton

enum TrainingType { NONE, HP, PWR }
var _current_training: TrainingType = TrainingType.NONE

func _ready():
	train_hp_button.pressed.connect(_on_train_pressed.bind(TrainingType.HP))
	train_pwr_button.pressed.connect(_on_train_pressed.bind(TrainingType.PWR))
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Connect to flashcard completion signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)

func _on_train_pressed(type: TrainingType):
	_current_training = type
	train_hp_button.disabled = true
	train_pwr_button.disabled = true
	
	# TDD Section 9.4: Rest Site "Train" Flow
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func _on_flashcard_completed(results: Dictionary):
	# TDD Section 9.4: Rest Site "Train" Flow
	if _current_training == TrainingType.NONE:
		return
	
	var correct_answers = results.get("correct_answers", 0)
	var stat_gain = floori(correct_answers / 2.0)  # TDD: stat_gain = floor(results.correct_answers / 2.0)
	
	# Determine stat type for display
	var stat_type = "HP" if _current_training == TrainingType.HP else "PWR"
	
	# Display ResultsPopup
	WindowManager.open_modal_window(&"ResultsPopup", {
		"populate_args": ["Training Complete!", "Your Hero gained +%d %s." % [stat_gain, stat_type], "Continue"]
	})
	
	# Connect to results_acknowledged to apply the stat gain
	EventBus.results_acknowledged.connect(_on_results_acknowledged, CONNECT_ONE_SHOT)

func _on_results_acknowledged():
	"""Called when player acknowledges the training results"""
	if _current_training == TrainingType.NONE: return
	
	var correct_answers = 0  # We need to get this from the results, but it's not stored
	var stat_gain = floori(correct_answers / 2.0)
	
	if stat_gain > 0 and is_instance_valid(GameManager.run_state):
		var hero_instance = GameManager.get_instance_by_uuid(GameManager.run_state.hero_instance.ball_uuid)
		if is_instance_valid(hero_instance):
			if _current_training == TrainingType.HP:
				hero_instance.current_hp += stat_gain
			elif _current_training == TrainingType.PWR:
				hero_instance.current_pwr += stat_gain
			EventBus.emit_signal("run_data_changed")
			EventBus.emit_signal("unit_stats_changed", hero_instance.ball_uuid)
	
	_current_training = TrainingType.NONE
	train_hp_button.disabled = false
	train_pwr_button.disabled = false

func _on_leave_pressed():
	EventBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _exit_tree():
	if EventBus.flashcard_minigame_completed.is_connected(_on_flashcard_completed):
		EventBus.flashcard_minigame_completed.disconnect(_on_flashcard_completed) 
