# res://scripts/FlashcardMinigame.gd
extends Control

## Flashcard minigame UI that implements the TDD specification
## TDD Section 9.2: Fast-paced, 3-second sprint with 9 answer choices

signal minigame_complete(results: Dictionary) # Internal signal for the window itself

@onready var question_label: Label = %QuestionLabel
@onready var choices_grid: GridContainer = %ChoicesGrid
@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var card_intro_container: VBoxContainer = %CardIntroContainer
@onready var intro_question_label: Label = %IntroQuestionLabel
@onready var intro_answer_label: Label = %IntroAnswerLabel
@onready var intro_explanation_label: Label = %IntroExplanationLabel
@onready var got_it_button: Button = %GotItButton

var _run_state: RunState = null
var _active_deck: Array[StringName] = []
var _correct_answers: int = 0
var _total_answers: int = 0
var _session_timer: float = 3.0
var _is_introducing_new_card: bool = false
var _new_card_id: StringName = &""
var _current_question_id: StringName = &""
var _current_choices: Array[StringName] = []

func _ready():
	# Connect to the FlashcardManager's minigame_finished signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	got_it_button.pressed.connect(_on_got_it_pressed)

func populate(context: Dictionary):
	"""Called by WindowManager when the modal window is opened"""
	_run_state = context.get("run_state")
	_active_deck = context.get("active_deck", [])
	
	if not is_instance_valid(_run_state):
		return
	
	# Check if we need to introduce a new card
	_check_for_new_card()
	
	if _is_introducing_new_card:
		_show_card_introduction()
	else:
		_start_minigame_session()

func _check_for_new_card():
	"""Check if a new card should be introduced to the active deck"""
	# TDD: Card Introduction - one new card is drawn in order from the Main Deck
	# For now, we'll implement a simple version - introduce a new card every 3 sessions
	# In a full implementation, this would track which cards have been introduced
	
	# Add a new card to the active deck
	var all_cards = _run_state.flashcard_progress.keys()
	for card_id in all_cards:
		if not _active_deck.has(card_id):
			_new_card_id = card_id
			_active_deck.append(card_id)
			_is_introducing_new_card = true
			return
	
	_is_introducing_new_card = false

func _show_card_introduction():
	"""Show the new card introduction screen"""
	card_intro_container.show()
	choices_grid.hide()
	question_label.hide()
	timer_label.hide()
	score_label.hide()
	
	var card_data = Database.get_flashcard_definition(_new_card_id)
	if not card_data.is_empty():
		intro_question_label.text = card_data.get("question", "Error: No question")
		intro_answer_label.text = "Answer: %s" % card_data.get("answer", "Error")
		intro_explanation_label.text = "Explanation: %s" % card_data.get("explanation", "No explanation available")

func _on_got_it_pressed():
	"""Called when player clicks 'Got It!' on card introduction"""
	card_intro_container.hide()
	_start_minigame_session()

func _start_minigame_session():
	"""Start the 3-second sprint mini-game"""
	card_intro_container.hide()
	
	# TDD: 5-second session timer for the entire session
	_session_timer = 5.0
	_is_introducing_new_card = false
	_correct_answers = 0
	_total_answers = 0
	
	# Show the game UI
	question_label.show()
	choices_grid.show()
	timer_label.show()
	score_label.show()
	
	# Start the timer
	_update_timer_display()
	_show_next_question()

func _process(delta):
	"""Update the session timer"""
	if not _is_introducing_new_card and _session_timer > 0:
		_session_timer -= delta
		_update_timer_display()
		
		if _session_timer <= 0:
			_end_minigame()

func _update_timer_display():
	"""Update the timer display"""
	timer_label.text = "%.1f" % max(0, _session_timer)
	score_label.text = "Score: %d" % _correct_answers

func _show_next_question():
	"""Show the next question with 9 answer choices"""
	if _session_timer <= 0:
		return
	
	var current_question = FlashcardManager.get_next_question()
	if current_question.is_empty():
		_end_minigame()
		return
	
	# Get the question data from Database
	var question_card_id = current_question.get("question_id", "")
	var card_data = Database.get_flashcard_definition(question_card_id)
	if card_data.is_empty():
		_end_minigame()
		return
	
	question_label.text = card_data.get("question", "Error: No question")
	_current_question_id = question_card_id
	_current_choices = current_question.get("choices", [])
	
	# Clear previous choices
	for child in choices_grid.get_children():
		child.queue_free()
	
	# Create 9 choice buttons in a 3x3 grid
	for i in range(min(9, _current_choices.size())):
		var choice_id = _current_choices[i]
		var choice_data = Database.get_flashcard_definition(choice_id)
		if not choice_data.is_empty():
			var button = Button.new()
			button.text = choice_data.get("answer", "Error")
			button.custom_minimum_size = Vector2(250, 80)
			button.add_theme_font_size_override("font_size", 60)
			button.pressed.connect(_on_choice_selected.bind(choice_id))
			choices_grid.add_child(button)

func _on_choice_selected(selected_answer_id: StringName):
	"""Handle when a player selects an answer"""
	var was_correct = selected_answer_id == _current_question_id
	_total_answers += 1
	
	if was_correct:
		_correct_answers += 1
		# TDD: Correct answer flashes green
		_flash_button_correct(selected_answer_id)
	else:
		# TDD: Incorrect answer flashes red
		_flash_button_incorrect(selected_answer_id)
	
	# Submit answer to FlashcardManager
	FlashcardManager.submit_answer(_current_question_id, was_correct)
	
	# TDD: Next question appears instantly
	_show_next_question()

func _flash_button_correct(correct_answer_id: StringName):
	"""Flash the correct answer button green"""
	for i in range(choices_grid.get_child_count()):
		var button = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.text == Database.get_flashcard_definition(correct_answer_id).get("answer", ""):
			button.modulate = Color.LIGHT_GREEN
			break

func _flash_button_incorrect(incorrect_answer_id: StringName):
	"""Flash the incorrect answer button red"""
	for i in range(choices_grid.get_child_count()):
		var button = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.text == Database.get_flashcard_definition(incorrect_answer_id).get("answer", ""):
			button.modulate = Color.RED
			break

func _end_minigame():
	"""End the mini-game when timer expires"""
	var results = {
		"correct_answers": _correct_answers,
		"total_answers": _total_answers,
		"incorrect_answers": _total_answers - _correct_answers
	}
	
	# Call FlashcardManager's completion method
	FlashcardManager._on_minigame_complete(_correct_answers, _total_answers - _correct_answers)
	
	# Emit our internal signal
	minigame_complete.emit(results)

func _on_flashcard_completed(results: Dictionary):
	"""Called when FlashcardManager emits minigame_finished"""
	# This is handled by the calling system (BattleManager or RestSite)
	pass

func _exit_tree():
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
