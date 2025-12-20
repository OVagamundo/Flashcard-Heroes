# res://scripts/FlashcardMinigame.gd
extends Control

## Flashcard minigame UI that implements the TDD specification
## TDD Section 9.2: Fast-paced, 3-second sprint with 9 answer choices

signal minigame_complete(results: Dictionary) # Internal signal for the window itself

## Animation duration constants (per CodeImprovementOpportunities.md §4.2)
const FLASH_DURATION: float = 0.15
const FLASH_FADE_DURATION: float = 0.1

## Project color palette (from VisualDesignDocument)
const COLOR_WARM_WHITE := Color(0.98, 0.96, 0.92)
const COLOR_COOL_BLACK := Color(0.15, 0.17, 0.22)
const COLOR_FLASH_CORRECT := Color.WHITE
const COLOR_FLASH_INCORRECT := Color(0.9, 0.2, 0.2)

# Load fonts
const JAPANESE_FONT = preload("res://assets/fonts/static/NotoSansJP-Black.ttf")
const BUTTON_FONT = preload("res://assets/fonts/DotGothic16/DotGothic16-Regular.ttf")

@onready var main_panel: Panel = %MainPanel
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
var _current_mastery_color: Color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
var _panel_style: StyleBoxFlat = null

func _ready() -> void:
	# Connect to the FlashcardManager's minigame_finished signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	got_it_button.pressed.connect(_on_got_it_pressed)
	
	# Setup panel style for dynamic mastery colors
	_setup_panel_style()
	
	# Setup question label font styling
	_setup_question_label_style()

func _setup_question_label_style() -> void:
	"""Configure the question label with NotoSansJP font and proper styling"""
	question_label.add_theme_font_override("font", JAPANESE_FONT)
	question_label.add_theme_font_size_override("font_size", 120)
	question_label.add_theme_color_override("font_color", COLOR_COOL_BLACK)
	question_label.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
	question_label.add_theme_constant_override("outline_size", 8)
	
	# Also style the intro question label
	intro_question_label.add_theme_font_override("font", JAPANESE_FONT)
	intro_question_label.add_theme_font_size_override("font_size", 72)
	intro_question_label.add_theme_color_override("font_color", COLOR_COOL_BLACK)
	intro_question_label.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
	intro_question_label.add_theme_constant_override("outline_size", 6)

func populate(context: Dictionary) -> void:
	"""Called by WindowManager when the modal window is opened"""
	_run_state = context.get("run_state")
	# Coerce active_deck into Array[StringName]
	var raw_deck: Variant = context.get("active_deck", null)
	_active_deck.clear()
	if raw_deck is Array:
		for v in raw_deck:
			_active_deck.append(StringName(v))
	
	if not is_instance_valid(_run_state):
		return
	
	# Check if we need to introduce a new card
	_check_for_new_card()
	
	if _is_introducing_new_card:
		_show_card_introduction()
	else:
		_start_minigame_session()

func _check_for_new_card() -> void:
	"""Check if a new card should be introduced to the active deck"""
	# TDD: Card Introduction - one new card is introduced per minigame session
	# until all cards from the Main Deck have been introduced
	
	if not is_instance_valid(_run_state):
		_is_introducing_new_card = false
		return
	
	# Find a card that's not yet in the active deck
	var all_cards = _run_state.flashcard_progress.keys()
	for card_id in all_cards:
		if not _run_state.active_deck_ids.has(card_id):
			_new_card_id = card_id
			# Permanently add to RunState's active deck (persists across sessions)
			_run_state.active_deck_ids.append(card_id)
			# Also add to our local copy for this session
			_active_deck.append(card_id)
			_is_introducing_new_card = true
			return
	
	# No new cards to introduce - all cards are already in the active deck
	_is_introducing_new_card = false

func _show_card_introduction() -> void:
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
	
	# Set panel to mastery level 1 color for new cards
	_update_panel_color(FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN])

func _on_got_it_pressed() -> void:
	"""Called when player clicks 'Got It!' on card introduction"""
	card_intro_container.hide()
	_start_minigame_session()

func _start_minigame_session() -> void:
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

func _process(delta: float) -> void:
	"""Update the session timer"""
	if not _is_introducing_new_card and _session_timer > 0:
		_session_timer -= delta
		_update_timer_display()
		
		if _session_timer <= 0:
			_end_minigame()

func _update_timer_display() -> void:
	"""Update the timer display"""
	timer_label.text = "%.1f" % max(0, _session_timer)
	score_label.text = "Score: %d" % _correct_answers

func _show_next_question() -> void:
	"""Show the next question with 9 answer choices (used for initial load)"""
	if _session_timer <= 0:
		return
	
	var current_question: Dictionary = FlashcardManager.get_next_question()
	_show_next_question_with_data(current_question, true) # true = set panel color

func _show_next_question_with_data(current_question: Dictionary, set_panel_color: bool = false) -> void:
	"""Show the next question using pre-fetched question data"""
	if _session_timer <= 0:
		return
	
	if current_question.is_empty():
		_end_minigame()
		return
	
	# Get the question data from Database
	var question_card_id: StringName = current_question.get("question_id", &"")
	var card_data: Dictionary = Database.get_flashcard_definition(question_card_id)
	if card_data.is_empty():
		_end_minigame()
		return
	
	question_label.text = card_data.get("question", "Error: No question")
	_current_question_id = question_card_id
	# Coerce choices into Array[StringName]
	var raw_choices: Variant = current_question.get("choices", null)
	_current_choices.clear()
	if raw_choices is Array:
		for v in raw_choices:
			_current_choices.append(StringName(v))
	
	# Only set panel color on initial load; subsequent questions use flash transition
	if set_panel_color:
		_update_panel_to_mastery_color(question_card_id)
	
	# Clear previous choices
	for child in choices_grid.get_children():
		child.queue_free()
	
	# Create 9 choice buttons in a 3x3 grid
	for i in range(mini(9, _current_choices.size())):
		var choice_id: StringName = _current_choices[i]
		var choice_data: Dictionary = Database.get_flashcard_definition(choice_id)
		if not choice_data.is_empty():
			var button := Button.new()
			button.text = choice_data.get("answer", "Error")
			button.custom_minimum_size = Vector2(280, 100)
			# Use NotoSansJP font with cool black text and warm white outline
			button.add_theme_font_override("font", JAPANESE_FONT)
			button.add_theme_font_size_override("font_size", 64)
			button.add_theme_color_override("font_color", COLOR_COOL_BLACK)
			button.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
			button.add_theme_constant_override("outline_size", 6)
			button.pressed.connect(_on_choice_selected.bind(choice_id))
			choices_grid.add_child(button)

func _update_panel_to_mastery_color(card_id: StringName) -> void:
	"""Update the panel color based on the card's current mastery level"""
	if not is_instance_valid(_run_state):
		return
	
	if _run_state.flashcard_progress.has(card_id):
		var progress: FlashcardProgress = _run_state.flashcard_progress[card_id]
		_current_mastery_color = progress.get_mastery_color()
	else:
		_current_mastery_color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	
	_update_panel_color(_current_mastery_color)

func _setup_panel_style() -> void:
	"""Create a StyleBoxFlat for the panel to allow dynamic color changes"""
	if not is_instance_valid(main_panel):
		return
	
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	_panel_style.corner_radius_top_left = 8
	_panel_style.corner_radius_top_right = 8
	_panel_style.corner_radius_bottom_left = 8
	_panel_style.corner_radius_bottom_right = 8
	main_panel.add_theme_stylebox_override("panel", _panel_style)

func _update_panel_color(color: Color) -> void:
	"""Set the panel's background color"""
	if is_instance_valid(_panel_style):
		_panel_style.bg_color = color

func _on_choice_selected(selected_answer_id: StringName) -> void:
	"""Handle when a player selects an answer"""
	var was_correct: bool = selected_answer_id == _current_question_id
	_total_answers += 1
	
	# Submit answer to FlashcardManager first (this updates mastery)
	FlashcardManager.submit_answer(_current_question_id, was_correct)
	
	if was_correct:
		_correct_answers += 1
		# Check for hero-specific timer passives
		if _has_hero_timer_bonus():
			# Timekeeper: +0.5s on correct
			_session_timer += 0.5
		elif _has_hero_timer_extend():
			# Generic hero: +1s on correct
			_session_timer += 1.0
		_flash_button_correct(selected_answer_id)
	else:
		# Check for generic hero penalty on wrong answer
		if _has_hero_timer_extend():
			# Generic hero: -0.5s on wrong
			_session_timer -= 0.5
		_flash_button_incorrect(selected_answer_id)
	
	# Get the next question BEFORE flashing so we know the target color
	var next_question: Dictionary = FlashcardManager.get_next_question()
	var next_mastery_color: Color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	
	if not next_question.is_empty():
		var next_card_id: StringName = next_question.get("question_id", &"")
		if is_instance_valid(_run_state) and _run_state.flashcard_progress.has(next_card_id):
			var progress: FlashcardProgress = _run_state.flashcard_progress[next_card_id]
			next_mastery_color = progress.get_mastery_color()
	
	# Flash feedback then transition to next question's color
	var flash_color: Color = COLOR_FLASH_CORRECT if was_correct else COLOR_FLASH_INCORRECT
	_flash_panel_and_transition(flash_color, next_mastery_color)
	
	# Show next question (will use the already-fetched question)
	_show_next_question_with_data(next_question)

func _flash_panel_and_transition(flash_color: Color, target_color: Color) -> void:
	"""Flash the panel with feedback color, then transition to target color"""
	if not is_instance_valid(_panel_style):
		return
	
	# Immediately set to flash color
	_panel_style.bg_color = flash_color
	
	# Tween to the target (next question's mastery) color
	var tween: Tween = create_tween()
	tween.tween_property(_panel_style, "bg_color", target_color, FLASH_FADE_DURATION).set_delay(FLASH_DURATION)


## Check if the current hero has the Timekeeper timer bonus passive (+0.5s on correct)
func _has_hero_timer_bonus() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	# Timekeeper hero has the timer bonus passive
	return def.id == &"hero_timekeeper"

## Check if the current hero has the generic hero timer extend passive (+1s correct, -0.5s wrong)
func _has_hero_timer_extend() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	# Generic hero has the timer extend passive
	return def.id == &"hero"


func _flash_button_correct(correct_answer_id: StringName) -> void:
	"""Flash the correct answer button green"""
	for i in range(choices_grid.get_child_count()):
		var button: Control = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.text == Database.get_flashcard_definition(correct_answer_id).get("answer", ""):
			button.modulate = Color.LIGHT_GREEN
			break

func _flash_button_incorrect(incorrect_answer_id: StringName) -> void:
	"""Flash the incorrect answer button red"""
	for i in range(choices_grid.get_child_count()):
		var button: Control = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.text == Database.get_flashcard_definition(incorrect_answer_id).get("answer", ""):
			button.modulate = Color.RED
			break

func _end_minigame() -> void:
	"""End the mini-game when timer expires"""
	var results: Dictionary = {
		"correct_answers": _correct_answers,
		"total_answers": _total_answers,
		"incorrect_answers": _total_answers - _correct_answers
	}
	
	# Call FlashcardManager's completion method
	FlashcardManager._on_minigame_complete(_correct_answers, _total_answers - _correct_answers)
	
	# Emit our internal signal
	minigame_complete.emit(results)

func _on_flashcard_completed(_results: Dictionary) -> void:
	"""Called when FlashcardManager emits minigame_finished"""
	# This is handled by the calling system (BattleManager or RestSite)
	pass

func _exit_tree() -> void:
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)
