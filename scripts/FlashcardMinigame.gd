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
const BUTTON_FONT = preload("res://assets/fonts/static/NotoSansJP-Black.ttf")
const WESTERN_FONT = preload("res://assets/fonts/static/NotoSansJP-Black.ttf")
const PANEL_TEXTURE = preload("res://assets/Realistic/ui/textures/panel_v4.png")
const BUTTON_NORMAL_TEXTURE = preload("res://assets/Realistic/ui/textures/button_v4_normal.png")
const BUTTON_HOVER_TEXTURE = preload("res://assets/Realistic/ui/textures/button_v4_hover.png")
const BUTTON_PRESSED_TEXTURE = preload("res://assets/Realistic/ui/textures/button_v4_pressed.png")

@onready var main_panel: PanelContainer = %MainPanel
@onready var question_label: Label = %QuestionLabel
@onready var choices_grid: GridContainer = %ChoicesGrid
@onready var timer_label: Label = %TimerLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var score_label: Label = %ScoreLabel
@onready var title_label: Label = %TitleLabel
@onready var card_intro_container: VBoxContainer = %CardIntroContainer
@onready var intro_question_label: Label = %IntroQuestionLabel
@onready var intro_answer_label: Label = %IntroAnswerLabel
@onready var intro_explanation_label: Label = %IntroExplanationLabel
@onready var got_it_button: Button = %GotItButton
@onready var skip_button: Button = %SkipButton
@onready var priority_cards_label: Label = %PriorityCardsLabel
@onready var priority_cards_container: HBoxContainer = %PriorityCardsContainer

var _run_state: RunState = null
var _active_deck: Array[StringName] = []
var _correct_answers: int = 0
var _current_streak: int = 0
var _total_answers: int = 0
var _session_timer: float = 3.0
var _is_introducing_new_card: bool = false
var _new_card_id: StringName = &""
var _displayed_card_id: StringName = &"" # Currently displayed in intro popup (may differ from _new_card_id)
var _current_question_id: StringName = &""
var _current_choices: Array[StringName] = []
var _current_mastery_color: Color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
var _panel_style: StyleBox = null

# Token counter references for live update
var _token_group: Control = null
var _token_group_original_parent: Node = null
var _token_group_original_index: int = -1
var _tokens_pending: int = 0 # Tokens that are mid-animation

# Input lock to prevent race conditions with rapid clicking
var _input_locked: bool = false
var _aura_vfx: Control = null

func _ready() -> void:
	# Connect to the FlashcardManager's minigame_finished signal
	FlashcardManager.minigame_finished.connect(_on_flashcard_completed)
	got_it_button.pressed.connect(_on_got_it_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	
	# Connect to locale changes
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	
	# Setup panel style for dynamic mastery colors
	_setup_panel_style()
	_setup_timer_bar()
	
	# Setup question label font styling
	_setup_question_label_style()
	
	# Find and exempt token counter from dimming
	_setup_token_counter_exemption()
	
	# Instantiate Aura VFX
	var aura_scene = preload("res://scenes/vfx/MinigameAuraVFX.tscn")
	if aura_scene:
		_aura_vfx = aura_scene.instantiate()
		if is_instance_valid(main_panel):
			main_panel.add_child(_aura_vfx)
			_aura_vfx.show_behind_parent = true
			
			# It's a Control now, so just make it fill the main panel
			_aura_vfx.set_anchors_preset(Control.PRESET_FULL_RECT)
		else:
			add_child(_aura_vfx)

func _setup_token_counter_exemption() -> void:
	"""Find the TokenGroup in Main and reparent it to stay above the dimming layer"""
	# Find Main node via GameManager's registered main node
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node):
		return
	
	# Find TokenGroup using unique name
	_token_group = main_node.get_node_or_null("%TokenGroup")
	if not is_instance_valid(_token_group):
		return
	
	# Store original parent info for restoration
	_token_group_original_parent = _token_group.get_parent()
	_token_group_original_index = _token_group.get_index()
	
	# Reparent to ModalLayer so it appears above the BackgroundBlocker but at same level as minigame
	var modal_layer = main_node.get_node_or_null("%ModalLayer")
	if is_instance_valid(modal_layer):
		# Use call_deferred to avoid tree modification conflicts
		_reparent_token_group_deferred.call_deferred(_token_group, modal_layer)

func _reparent_token_group_deferred(token_group: Control, new_parent: Node) -> void:
	"""Deferred helper to safely reparent token group"""
	if not is_instance_valid(token_group) or not is_instance_valid(new_parent):
		return
	if token_group.get_parent() == new_parent:
		return # Already in target parent
	
	var global_pos = token_group.global_position
	token_group.reparent(new_parent)
	token_group.global_position = global_pos

func _restore_token_counter() -> void:
	"""Restore TokenGroup to its original parent"""
	if not is_instance_valid(_token_group) or not is_instance_valid(_token_group_original_parent):
		return
	
	# Only restore if currently not in original parent
	if _token_group.get_parent() == _token_group_original_parent:
		return # Already in original parent, nothing to do
	
	# Use call_deferred to avoid tree modification conflicts during _exit_tree
	_restore_token_group_deferred.call_deferred()

func _restore_token_group_deferred() -> void:
	"""Deferred helper to safely restore token group to original parent"""
	if not is_instance_valid(_token_group) or not is_instance_valid(_token_group_original_parent):
		return
	if _token_group.get_parent() == _token_group_original_parent:
		return # Already restored
	
	var global_pos = _token_group.global_position
	_token_group.reparent(_token_group_original_parent)
	
	# Safely move to original index
	if _token_group_original_index >= 0 and _token_group_original_index < _token_group_original_parent.get_child_count():
		_token_group_original_parent.move_child(_token_group, _token_group_original_index)
	
	_token_group.global_position = global_pos

func _setup_timer_bar() -> void:
	"""Configure the timer bar style"""
	if not is_instance_valid(timer_bar):
		return
		
	# Create custom stylebox for fill
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.8, 0.2) # Base Green
	style_fill.corner_radius_top_left = 4
	style_fill.corner_radius_top_right = 4
	style_fill.corner_radius_bottom_left = 4
	style_fill.corner_radius_bottom_right = 4
	timer_bar.add_theme_stylebox_override("fill", style_fill)
	
	# Create custom stylebox for background
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = COLOR_COOL_BLACK.lightened(0.1)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	timer_bar.add_theme_stylebox_override("background", style_bg)

func _setup_question_label_style() -> void:
	"""Configure the question label with NotoSansJP font and proper styling"""
	question_label.add_theme_font_override("font", JAPANESE_FONT)
	question_label.add_theme_font_size_override("font_size", 120)
	question_label.add_theme_color_override("font_color", COLOR_COOL_BLACK)
	question_label.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
	question_label.add_theme_constant_override("outline_size", 8)
	
	# Also style the intro labels
	intro_question_label.add_theme_font_override("font", JAPANESE_FONT)
	intro_question_label.add_theme_font_size_override("font_size", 64) # Reduced to prevent wrapping
	intro_question_label.add_theme_color_override("font_color", COLOR_COOL_BLACK)
	intro_question_label.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
	intro_question_label.add_theme_constant_override("outline_size", 8)
	
	intro_answer_label.add_theme_font_override("font", JAPANESE_FONT)
	intro_answer_label.add_theme_font_size_override("font_size", 64) # Match question font size
	intro_answer_label.add_theme_color_override("font_color", Color.WHITE)
	intro_answer_label.add_theme_color_override("font_outline_color", COLOR_COOL_BLACK)
	intro_answer_label.add_theme_constant_override("outline_size", 8)
	
	var intro_arrow = %IntroArrow
	intro_arrow.add_theme_font_override("font", JAPANESE_FONT)
	intro_arrow.add_theme_font_size_override("font_size", 64)
	intro_arrow.add_theme_color_override("font_color", COLOR_COOL_BLACK)
	intro_arrow.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
	intro_arrow.add_theme_constant_override("outline_size", 4)

func populate(context: Dictionary) -> void:
	"""Called by WindowManager when the modal window is opened"""
	# AUDIO HOOK: Minigame popup opening sound
	Audio.play_sfx("ui_window_open")
	
	_run_state = context.get("run_state")
	# Coerce active_deck into Array[StringName]
	var raw_deck: Variant = context.get("active_deck", null)
	_active_deck.clear()
	if raw_deck is Array:
		for v in raw_deck:
			_active_deck.append(StringName(v))
	
	if not is_instance_valid(_run_state):
		return
	
	_update_localized_text()
	
	# Check if we need to introduce a new card
	_check_for_new_card()
	
	if _is_introducing_new_card:
		_show_card_introduction()
	else:
		_start_minigame_session()

func _check_for_new_card() -> void:
	"""Check if a new card should be introduced to the active deck"""
	
	if not is_instance_valid(_run_state):
		_is_introducing_new_card = false
		return
	
	# Check if there are any cards in active_deck_ids that haven't been formally introduced yet
	# cards_presented_count tracks how many cards have been shown via the intro popup
	# active_deck_ids.size() is how many cards are actually in the playable deck
	# 
	# Phase 1: Initial 10 cards are added to active_deck_ids at run start
	# Phase 2: check_deck_expansion() adds 1 card AFTER each minigame session
	# 
	# This function introduces the NEXT un-introduced card (if any)
	
	if _run_state.cards_presented_count < _run_state.active_deck_ids.size():
		# There's a card in active_deck_ids that hasn't been introduced yet
		_new_card_id = _run_state.active_deck_ids[_run_state.cards_presented_count]
		_run_state.cards_presented_count += 1
		_is_introducing_new_card = true
		return
	
	# No new cards to introduce - all active deck cards have been presented
	_is_introducing_new_card = false

func _show_card_introduction() -> void:
	"""Show the new card introduction screen"""
	card_intro_container.show()
	choices_grid.hide()
	question_label.hide()
	if is_instance_valid(timer_bar):
		timer_bar.hide()
	timer_label.hide()
	score_label.hide()
	skip_button.hide()
	
	# Initialize displayed card to the new card being introduced
	_displayed_card_id = _new_card_id
	_update_displayed_card_info(_displayed_card_id)
	
	# Populate the priority cards at the bottom
	_populate_priority_cards()
	
	_update_localized_text() # Refresh text after setting state
	
	# Show new card tutorial (deferred to ensure UI is ready)
	call_deferred("_show_new_card_tutorial")

func _update_displayed_card_info(card_id: StringName) -> void:
	"""Update the main display to show info for the given card"""
	var card_data = Database.get_flashcard_definition(card_id)
	if not card_data.is_empty():
		intro_question_label.text = card_data.get("question", "Error: No question")
		var answer_text = card_data.get("answer", "Error")
		intro_answer_label.text = answer_text if _is_japanese(answer_text) else answer_text.to_upper()
		var explanation = card_data.get("explanation", "")
		if explanation.is_empty():
			explanation = tr("ui.no_explanation")
		intro_explanation_label.text = explanation # Simplified as per feedback or clarity
		
		# Play native Japanese/Korean/Thai pronunciation out loud
		if card_id.begins_with("KANJI_") or card_id.begins_with("KOR_") or card_id.begins_with("THAI_"):
			Audio.play_sfx("pronunciation_" + card_id)
		else:
			var romaji = card_data.get("answer", "").to_lower()
			Audio.play_sfx("pronunciation_" + romaji)
	
	# Get mastery level for this card and update panel color
	var mastery_color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	if is_instance_valid(_run_state) and _run_state.flashcard_progress.has(card_id):
		var progress: FlashcardProgress = _run_state.flashcard_progress[card_id]
		mastery_color = progress.get_mastery_color()
	_update_panel_color(mastery_color)

func _get_priority_sorted_cards() -> Array[Dictionary]:
	"""Get the active deck cards sorted by SRS priority (without RNG factor)"""
	if not is_instance_valid(_run_state):
		return []
	
	var weighted_cards: Array[Dictionary] = []
	
	for i in range(_run_state.active_deck_ids.size()):
		var card_id: StringName = _run_state.active_deck_ids[i]
		var mastery_level: int = FlashcardProgress.MASTERY_MIN
		var last_review_day: int = 0
		
		if _run_state.flashcard_progress.has(card_id):
			var progress: FlashcardProgress = _run_state.flashcard_progress[card_id]
			mastery_level = progress.mastery_level
			last_review_day = progress.last_review_day
		
		# SRS priority calculation (without RNG)
		# Priority 1: Mastery Level (lower = higher priority)
		var mastery_component: float = pow(6 - mastery_level, FlashcardManager.SRS_MASTERY_WEIGHT_POWER)
		# Priority 2: Recency (longer since review = higher priority)
		var time_component: float = float(_run_state.day - last_review_day) * FlashcardManager.SRS_RECENCY_WEIGHT
		# Priority 3: Deck order (lower index = tiebreaker)
		var order_component: float = float(i) * 0.001 # Small factor to preserve deck order for ties
		
		var weight: float = mastery_component + time_component - order_component
		
		weighted_cards.append({
			"id": card_id,
			"weight": weight,
			"mastery_level": mastery_level
		})
	
	# Sort descending by weight (higher weight = higher priority)
	weighted_cards.sort_custom(func(a, b): return a.weight > b.weight)
	
	return weighted_cards

func _update_localized_text() -> void:
	if not is_inside_tree(): return
	
	if _is_introducing_new_card:
		title_label.text = tr("ui.review_title")
		title_label.show()
	else:
		title_label.text = ""
		title_label.hide()
	
	skip_button.text = tr("ui.skip")
	got_it_button.text = tr("ui.ready")
	priority_cards_label.text = tr("ui.priority_cards")
	
	# Refresh current card content if active
	if not _current_question_id.is_empty():
		var card_data: Dictionary = Database.get_flashcard_definition(_current_question_id)
		if not card_data.is_empty():
			question_label.text = card_data.get("question", "Error: No question")
			
	# Refresh choice buttons
	if _current_choices.size() > 0:
		for i in range(mini(choices_grid.get_child_count(), _current_choices.size())):
			var button = choices_grid.get_child(i)
			var choice_id = _current_choices[i]
			var choice_data = Database.get_flashcard_definition(choice_id)
			if not choice_data.is_empty():
				button.text = choice_data.get("answer", "Error")
				
	# Refresh introduction labels if currently introducing a card
	if _is_introducing_new_card and not _current_question_id.is_empty():
		var card_data: Dictionary = Database.get_flashcard_definition(_current_question_id)
		if not card_data.is_empty():
			var answer_text = card_data.get("answer", "Error")
			intro_answer_label.text = answer_text if _is_japanese(answer_text) else answer_text.to_upper()
			intro_explanation_label.text = card_data.get("explanation", "")
	
	if _is_introducing_new_card:
		intro_question_label.text = tr("ui.intro_new_card") # Default if not updated by card info
		# Re-trigger card info update to refresh localized answer/explanation if needed
		if not _displayed_card_id.is_empty():
			_update_displayed_card_info(_displayed_card_id)

func _populate_priority_cards() -> void:
	"""Create buttons for the top 10 priority cards"""
	# Clear existing buttons
	for child in priority_cards_container.get_children():
		child.queue_free()
	
	var priority_cards = _get_priority_sorted_cards()
	var count = mini(6, priority_cards.size())
	
	for i in range(count):
		var card_info = priority_cards[i]
		var card_id: StringName = card_info.id
		var mastery_level: int = card_info.mastery_level
		
		var card_data = Database.get_flashcard_definition(card_id)
		if card_data.is_empty():
			continue
		
		var button := Button.new()
		button.text = card_data.get("question", "?")
		button.custom_minimum_size = Vector2(100, 80) # Larger buttons as requested
		
		# Style with theme button textures and mastery color modulation
		var mastery_color = FlashcardProgress.MASTERY_COLORS[clampi(mastery_level, FlashcardProgress.MASTERY_MIN, FlashcardProgress.MASTERY_MAX)]
		
		var normal_style = StyleBoxTexture.new()
		normal_style.texture = BUTTON_NORMAL_TEXTURE
		normal_style.modulate_color = mastery_color
		normal_style.texture_margin_left = 20
		normal_style.texture_margin_right = 20
		normal_style.texture_margin_top = 20
		normal_style.texture_margin_bottom = 20
		
		var hover_style = StyleBoxTexture.new()
		hover_style.texture = BUTTON_HOVER_TEXTURE
		hover_style.modulate_color = mastery_color.lightened(0.2)
		hover_style.texture_margin_left = 20
		hover_style.texture_margin_right = 20
		hover_style.texture_margin_top = 20
		hover_style.texture_margin_bottom = 20
		
		var pressed_style = StyleBoxTexture.new()
		pressed_style.texture = BUTTON_PRESSED_TEXTURE
		pressed_style.modulate_color = mastery_color.darkened(0.2)
		pressed_style.texture_margin_left = 20
		pressed_style.texture_margin_right = 20
		pressed_style.texture_margin_top = 20
		pressed_style.texture_margin_bottom = 20
		
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		# Font styling
		button.add_theme_font_override("font", JAPANESE_FONT)
		button.add_theme_font_size_override("font_size", 36) # Larger font
		button.add_theme_color_override("font_color", COLOR_COOL_BLACK)
		button.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
		button.add_theme_constant_override("outline_size", 3)
		
		# Highlight the currently displayed card
		if card_id == _displayed_card_id:
			normal_style.modulate_color = mastery_color.lightened(0.4)
			# Add a border-like effect using content margins or similar if needed, 
			# but modulation is usually enough with the texture
		
		button.pressed.connect(_on_priority_card_clicked.bind(card_id))
		priority_cards_container.add_child(button)

func _on_priority_card_clicked(card_id: StringName) -> void:
	"""Handle click on a priority card button - switch which card is displayed"""
	_displayed_card_id = card_id
	_update_displayed_card_info(card_id)
	# Refresh the priority cards to update the highlight
	_populate_priority_cards()


func _show_new_card_tutorial() -> void:
	"""Show new card tutorial overlay"""
	TutorialManager.show_tutorial(&"new_card_intro", [
		{
			"text": "tutorial.new_card_intro",
			"anchor_side": "top_left"
		}
	], %MainPanel)

func _on_got_it_pressed() -> void:
	"""Called when player clicks 'Got It!' on card introduction"""
	card_intro_container.hide()
	_start_minigame_session()

func _start_minigame_session() -> void:
	"""Start the 3-second sprint mini-game"""
	# AUDIO HOOK: High-intensity minigame BGM (played at -7.0 dB so voice clips are clear but music is audible)
	Audio.play_music(SoundRegistry.BGM_MINIGAME, 0.1, -7.0)
	
	card_intro_container.hide()
	
	# 7-second base timer
	_session_timer = 7.0
	if GameManager.is_in_battle and GameManager.has_trinket(&"trinket_time_sprint_charm"):
		_session_timer += 2.0
		var animator = get_node_or_null("/root/BattleAnimator")
		if is_instance_valid(animator) and animator.has_method("hop_trinket_by_definition_id"):
			animator.call_deferred("hop_trinket_by_definition_id", &"trinket_time_sprint_charm", false)
	if is_instance_valid(timer_bar):
		timer_bar.max_value = _session_timer
		timer_bar.value = _session_timer
		
	_is_introducing_new_card = false
	_correct_answers = 0
	_current_streak = 0
	_total_answers = 0
	_tokens_pending = 0
	_update_aura_vfx()
	
	_update_localized_text() # Refresh UI state to hide title
	
	# Show the game UI
	question_label.show()
	choices_grid.show()
	timer_bar.show() # Parents the label, so showing bar shows label too
	timer_label.show()
	score_label.show()
	skip_button.show()
	
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
	if is_instance_valid(timer_bar):
		timer_bar.value = _session_timer
	score_label.text = tr("ui.score") % _correct_answers

func _show_next_question() -> void:
	"""Show the next question with 9 answer choices (used for initial load)"""
	if _session_timer <= 0:
		return
	
	var current_question: Dictionary = FlashcardManager.get_next_question()
	_show_next_question_with_data(current_question, true) # true = set panel color

func _show_next_question_with_data(current_question: Dictionary, set_panel_color: bool = false) -> void:
	"""Show the next question using pre-fetched question data"""
	if _session_timer <= 0:
		_end_minigame()
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
	
	# Create 6 choice buttons in a 2x3 grid
	for i in range(mini(6, _current_choices.size())):
		var choice_id: StringName = _current_choices[i]
		var choice_data: Dictionary = Database.get_flashcard_definition(choice_id)
		if not choice_data.is_empty():
			var button := Button.new()
			var answer_text: String = choice_data.get("answer", "Error")
			var is_jp: bool = _is_japanese(answer_text)
			
			button.text = answer_text if is_jp else answer_text.to_upper()
			button.set_meta(&"choice_id", choice_id)
			button.custom_minimum_size = Vector2(280, 100)
			
			# Apply conditional font and size
			if is_jp:
				button.add_theme_font_override("font", JAPANESE_FONT)
				button.add_theme_font_size_override("font_size", 48)
			else:
				button.add_theme_font_override("font", WESTERN_FONT)
				button.add_theme_font_size_override("font_size", 34) # Adjusted for Noto Sans Bold
			
			button.add_theme_color_override("font_color", COLOR_COOL_BLACK)
			button.add_theme_color_override("font_outline_color", COLOR_WARM_WHITE)
			button.add_theme_constant_override("outline_size", 6)
			
			# Enable autowrap for long translations
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.clip_text = false
			
			button.pressed.connect(_on_choice_selected.bind(choice_id))
			choices_grid.add_child(button)
			
	# Unlock input now that new buttons are ready
	_input_locked = false

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
	if not is_instance_valid(main_panel):
		return
	
	var style = StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	style.texture_margin_left = 20
	style.texture_margin_right = 20
	style.texture_margin_top = 20
	style.texture_margin_bottom = 20
	style.modulate_color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	
	_panel_style = style
	main_panel.add_theme_stylebox_override("panel", _panel_style)

func _update_panel_color(color: Color) -> void:
	"""Set the panel's background color by modulating the texture"""
	if _panel_style is StyleBoxTexture:
		_panel_style.modulate_color = color
	elif _panel_style is StyleBoxFlat:
		_panel_style.bg_color = color

func _on_choice_selected(selected_answer_id: StringName) -> void:
	"""Handle when a player selects an answer"""
	if _input_locked or _session_timer <= 0:
		return
		
	_input_locked = true
	var was_correct: bool = selected_answer_id == _current_question_id
	_total_answers += 1
	
	# Submit answer to FlashcardManager first (this updates mastery)
	FlashcardManager.submit_answer(_current_question_id, was_correct)
	
	# Play pronunciation of selected answer
	if selected_answer_id.begins_with("KANJI_") or selected_answer_id.begins_with("KOR_") or selected_answer_id.begins_with("THAI_"):
		Audio.play_sfx("pronunciation_" + selected_answer_id)
	else:
		var selected_data = Database.get_flashcard_definition(selected_answer_id)
		if not selected_data.is_empty():
			var romaji = selected_data.get("answer", "").to_lower()
			Audio.play_sfx("pronunciation_" + romaji)
	
	if was_correct:
		_correct_answers += 1
		_current_streak += 1
		_session_timer += 0.5
		_update_timer_display()
		_update_aura_vfx()
			
		_flash_button_correct(selected_answer_id, true)
		_flash_timer_bar_correct()
		
		# Update BGM tempo/pitch based on streak
		Audio.set_music_pitch(1.0 + minf(_current_streak, 10) * 0.02)
		
		# AUDIO HOOK: Correct (pitch ascending)
		var pitch = minf(1.0 + (_current_streak * 0.05), 1.5)
		Audio.play_sfx("minigame_correct", pitch)
	else:
		_current_streak = 0
		_update_aura_vfx()
		# NO timer reduction as per user request
		
		Audio.set_music_pitch(1.0)
			
		_flash_button_incorrect(selected_answer_id)
		_flash_timer_bar_incorrect()
		_flash_button_correct(_current_question_id, false) # Reveal correct answer, no token
		# AUDIO HOOK: Incorrect
		Audio.play_sfx("minigame_incorrect")
		
		# Play correct answer's pronunciation after a short delay so they hear both
		var correct_delay_tween = create_tween()
		correct_delay_tween.tween_interval(0.4)
		correct_delay_tween.tween_callback(func():
			if _current_question_id.begins_with("KANJI_") or _current_question_id.begins_with("KOR_") or _current_question_id.begins_with("THAI_"):
				Audio.play_sfx("pronunciation_" + _current_question_id)
			else:
				var correct_data = Database.get_flashcard_definition(_current_question_id)
				if not correct_data.is_empty():
					var correct_romaji = correct_data.get("answer", "").to_lower()
					Audio.play_sfx("pronunciation_" + correct_romaji)
		)
	
	# Delay showing the next question
	var next_question: Dictionary = FlashcardManager.get_next_question()
	var next_mastery_color: Color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	
	if not next_question.is_empty():
		var next_card_id: StringName = next_question.get("question_id", &"")
		if is_instance_valid(_run_state) and _run_state.flashcard_progress.has(next_card_id):
			var progress: FlashcardProgress = _run_state.flashcard_progress[next_card_id]
			next_mastery_color = progress.get_mastery_color()
	
	# Flash feedback then transition to next question's color
	var flash_color: Color = _get_streak_color() if was_correct else COLOR_FLASH_INCORRECT
	_flash_panel_and_transition(flash_color, next_mastery_color)
	
	var feedback_pause = 0.05 if was_correct else 1.0
	
	var delay_tween = create_tween()
	delay_tween.tween_interval(feedback_pause)
	delay_tween.tween_callback(func():
		if not is_instance_valid(self): return
		
		# Check timer again before proceeding
		if _session_timer <= 0:
			_end_minigame()
			return
			
		_show_next_question_with_data(next_question)
	)

func _flash_panel_and_transition(flash_color: Color, target_color: Color) -> void:
	"""Flash the panel with feedback color, then transition to target color"""
	if not is_instance_valid(_panel_style):
		return
	
	var prop = "modulate_color" if _panel_style is StyleBoxTexture else "bg_color"
	
	# Immediately set to flash color
	_panel_style.set(prop, flash_color)
	
	# Tween to the target (next question's mastery) color
	var tween: Tween = create_tween()
	tween.tween_property(_panel_style, prop, target_color, FLASH_FADE_DURATION).set_delay(FLASH_DURATION)

func _flash_timer_bar_correct() -> void:
	"""Flash the timer bar white or streak color"""
	_flash_timer_bar(COLOR_FLASH_CORRECT if _current_streak < 5 else _get_streak_color())

func _flash_timer_bar_incorrect() -> void:
	"""Flash the timer bar red"""
	_flash_timer_bar(COLOR_FLASH_INCORRECT)

func _flash_timer_bar(color: Color) -> void:
	if not is_instance_valid(timer_bar):
		return
	
	var style: StyleBoxFlat = timer_bar.get_theme_stylebox("fill")
	if not is_instance_valid(style):
		return
		
	# Tween color: Flash Color -> Return to Base Green
	var base_color = Color(0.2, 0.8, 0.2)
	style.bg_color = color
	
	var tween = create_tween()
	tween.tween_property(style, "bg_color", base_color, FLASH_FADE_DURATION).set_delay(0.05)


## Check if the current hero has the Bounty Hunter timer bonus passive (+0.5s on correct)
## Check if the current hero is the Bounty Hunter (Regular Hero)
## Passive: +0.5s on correct, -0.2s on wrong
func _is_bounty_hunter() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	return def.id == &"hero_bounty_hunter"

## Check if the current hero is the Timekeeper
## Passive: +1.0s on correct, -0.5s on wrong
func _is_timekeeper() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	return def.id == &"hero_timekeeper"

## Check if the current hero is the Starter
## Passive: Minimum 3 tokens per minigame
func _is_starter_hero() -> bool:
	if not is_instance_valid(GameManager.run_state):
		return false
	var hero: GachaBallInstance = GameManager.run_state.hero_instance
	if not is_instance_valid(hero):
		return false
	var def: GachaBallDefinition = hero.get_definition()
	if not is_instance_valid(def):
		return false
	return def.id == &"hero_starter"


func _get_streak_color() -> Color:
	if _current_streak >= 9:
		# Rainbow-ish (magenta/pink) for highest tier
		return Color(1.0, 0.2, 0.8)
	elif _current_streak >= 7:
		return Color(1.0, 0.84, 0.0) # Gold
	elif _current_streak >= 5:
		return Color(0.6, 0.2, 1.0) # Purple/Blue
	elif _current_streak >= 3:
		return Color.CYAN
	else:
		return Color.LIGHT_GREEN

func _update_aura_vfx() -> void:
	if is_instance_valid(_aura_vfx):
		_aura_vfx.set_intensity(_current_streak, _get_streak_color())

func _flash_button_correct(correct_answer_id: StringName, spawn_token: bool = true) -> void:
	"""Flash the correct answer button green (or streak color) and optionally spawn token pop VFX"""
	var btn_color = _get_streak_color()
	
	for i in range(choices_grid.get_child_count()):
		var button: Control = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.get_meta(&"choice_id", &"") == correct_answer_id:
			button.modulate = btn_color
			
			if spawn_token:
				# Spawn Mario-style token pop from button center, flying to token counter
				_spawn_token_pop(button)
			break

func _on_skip_pressed() -> void:
	if _input_locked or _session_timer <= 0:
		return
	
	_input_locked = true
	
	# Skip counts as an incorrect answer for mastery (reduces it by 1)
	FlashcardManager.submit_answer(_current_question_id, false)
	
	# 1. Correct answer lit green for 0.5s
	# 2. Timer +0.5s increment
	# 3. NO token
	# 4. Stay for 0.5s while timer runs then move to next
	
	_flash_button_correct(_current_question_id, false)
	_session_timer += 0.5
	_update_timer_display()
	
	# Reveal correct button
	_flash_timer_bar_correct() 
	
	var next_question: Dictionary = FlashcardManager.get_next_question()
	var next_mastery_color: Color = FlashcardProgress.MASTERY_COLORS[FlashcardProgress.MASTERY_MIN]
	if not next_question.is_empty():
		var next_card_id: StringName = next_question.get("question_id", &"")
		if is_instance_valid(_run_state) and _run_state.flashcard_progress.has(next_card_id):
			var progress: FlashcardProgress = _run_state.flashcard_progress[next_card_id]
			next_mastery_color = progress.get_mastery_color()

	_flash_panel_and_transition(COLOR_FLASH_CORRECT, next_mastery_color)

	var delay_tween = create_tween()
	delay_tween.tween_interval(0.5)
	delay_tween.tween_callback(func():
		if not is_instance_valid(self): return
		if _session_timer <= 0:
			_end_minigame()
			return
		_show_next_question_with_data(next_question)
	)

func _get_token_counter_target_position() -> Vector2:
	"""Get the global position of the token counter icon for animation target"""
	if not is_instance_valid(_token_group):
		# Fallback: return screen center top area
		return Vector2(get_viewport_rect().size.x / 2, 60)
	
	# Get center of the TokenGroup
	var token_rect = _token_group.get_global_rect()
	return Vector2(
		token_rect.position.x + token_rect.size.x / 2,
		token_rect.position.y + token_rect.size.y / 2
	)

func _spawn_token_pop(button: Control) -> void:
	"""Spawn a token pop VFX at the button's center that flies to token counter"""
	const TokenPopScene = preload("res://scenes/vfx/TokenPopVFX.tscn")
	
	var token_pop = TokenPopScene.instantiate()
	
	# Get button center in global coordinates
	var button_rect = button.get_global_rect()
	var spawn_pos = Vector2(
		button_rect.position.x + button_rect.size.x / 2,
		button_rect.position.y + button_rect.size.y / 2
	)
	
	# Get target position (token counter)
	var target_pos = _get_token_counter_target_position()
	
	# Track pending token
	_tokens_pending += 1
	
	# Connect to animation_finished to update counter when token lands
	token_pop.animation_finished.connect(_on_token_landed)
	
	# Add to scene and play with target
	add_child(token_pop)
	token_pop.global_position = spawn_pos
	token_pop.play(target_pos, _current_streak)

func _on_token_landed() -> void:
	"""Called when a token animation completes - update the counter live"""
	_tokens_pending -= 1
	
	# Find BattleManager to update tokens (battle context)
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.has_method("add_gacha_token"):
		bm.add_gacha_token(1)
	else:
		# Non-battle context (Rest Site, etc.): emit signal directly
		# Find current token count from whoever is listening
		# This increments the displayed count by 1
		SignalBus.emit_signal("flashcard_token_earned", 1)

func _flash_button_incorrect(incorrect_answer_id: StringName) -> void:
	"""Flash the incorrect answer button red"""
	for i in range(choices_grid.get_child_count()):
		var button: Control = choices_grid.get_child(i)
		if not is_instance_valid(button):
			continue
		if button.get_meta(&"choice_id", &"") == incorrect_answer_id:
			button.modulate = Color.RED
			break

func _end_minigame() -> void:
	"""End the mini-game when timer expires"""
	# AUDIO HOOK: Restore previous scene's BGM when minigame ends
	# Context-aware: restore Battle BGM if in combat, RestSite BGM otherwise
	if GameManager.is_in_battle:
		Audio.play_music(SoundRegistry.BGM_BATTLE)
	else:
		Audio.play_music(SoundRegistry.BGM_REST)
	
	# Starter hero: guarantee minimum 3 tokens
	if _is_starter_hero() and _correct_answers < 3:
		var bonus = 3 - _correct_answers
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm) and bm.has_method("add_gacha_token"):
			bm.add_gacha_token(bonus)
		else:
			SignalBus.emit_signal("flashcard_token_earned", bonus)
		_correct_answers = 3  # Update for results dict
	
	var results: Dictionary = {
		"correct_answers": _correct_answers,
		"total_answers": _total_answers,
		"incorrect_answers": _total_answers - _correct_answers,
		"tokens_already_awarded": _correct_answers - _tokens_pending # Tokens that completed animation
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
	# Restore token counter to original position before cleanup
	_restore_token_counter()
	
	if FlashcardManager.minigame_finished.is_connected(_on_flashcard_completed):
		FlashcardManager.minigame_finished.disconnect(_on_flashcard_completed)

## Helper to detect Japanese characters for font selection
func _is_japanese(text: String) -> bool:
	for c in text:
		var code = c.unicode_at(0)
		# Hiragana: 0x3040-0x309F
		# Katakana: 0x30A0-0x30FF
		# CJK Unified Ideographs (Kanji): 0x4E00-0x9FFF
		if (code >= 0x3040 and code <= 0x309F) or \
		   (code >= 0x30A0 and code <= 0x30FF) or \
		   (code >= 0x4E00 and code <= 0x9FFF):
			return true
	return false

func get_window_to_animate() -> Control:
	return main_panel
