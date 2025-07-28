<!-- Original: scripts/FlashcardManager.gd -->

```gdscript
# res://scripts/FlashcardManager.gd
extends Node

## Singleton responsible for the mini-game's lifecycle.
## TDD Section 9.2: FlashcardManager.gd

signal minigame_finished(results: Dictionary)

var _run_state_ref: RunState = null
var _active_deck_ids: Array[StringName] = []
var _last_shown_card_id: StringName = &""
var _minigame_instance: Control = null

## TDD Section 9.3: The Weighted SRS Algorithm
func _select_card_via_srs() -> StringName:
	"""Selects a card using the weighted SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
		printerr("FlashcardManager: _run_state_ref is null in _select_card_via_srs")
		return _active_deck_ids.pick_random() if not _active_deck_ids.is_empty() else &""
	
	var candidates = _active_deck_ids.duplicate()
	if candidates.has(_last_shown_card_id):
		candidates.erase(_last_shown_card_id)
	
	if candidates.is_empty():
		return _active_deck_ids.pick_random() if not _active_deck_ids.is_empty() else &""
	
	var weighted_candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	
	for card_id in candidates:
		if not _run_state_ref.flashcard_progress.has(card_id):
			continue
		var progress: FlashcardProgress = _run_state_ref.flashcard_progress[card_id]
		
		# TDD Section 9.3: weight = pow(6 - mastery_level, 2) + (current_day - last_review_day)
		var mastery_component = pow(6 - progress.mastery_level, 2)
		var time_component = _run_state_ref.day - progress.last_review_day
		var weight = float(mastery_component + time_component)
		
		weighted_candidates.append({"id": card_id, "weight": weight})
		total_weight += weight
	
	# If no weighted candidates, fall back to random selection
	if weighted_candidates.is_empty():
		return candidates.pick_random() if not candidates.is_empty() else &""
	
	# Perform weighted random selection
	var rand_val = randf() * total_weight
	for candidate in weighted_candidates:
		rand_val -= candidate.weight
		if rand_val <= 0:
			return candidate.id
	
	return candidates.pick_random() # Fallback

## TDD Section 9.2: Public API
func start_minigame(run_state: RunState, active_deck: Array[StringName]) -> void:
	"""Starts a flashcard minigame with the specified run state and active deck"""
	if is_instance_valid(_minigame_instance):
		return # Game already in progress
	
	self._run_state_ref = run_state
	self._active_deck_ids = active_deck
	
	# Open the flashcard minigame modal window
	_minigame_instance = WindowManager.open_modal_window(&"FlashcardMinigame", {
		"run_state": run_state,
		"active_deck": active_deck
	})

func get_next_question() -> Dictionary:
	"""Gets the next question using SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
		printerr("FlashcardManager: _run_state_ref is null in get_next_question")
		return {}
	
	if _active_deck_ids.size() < 10:
		return {} # Not enough cards for a question and 9 distractors
	
	var question_card_id = _select_card_via_srs()
	if question_card_id.is_empty():
		printerr("FlashcardManager: Could not select a question card")
		return {}
	
	_last_shown_card_id = question_card_id
	
	var distractors = _active_deck_ids.duplicate()
	distractors.erase(question_card_id)
	distractors.shuffle()
	
	var choices: Array[StringName] = [question_card_id]
	choices.append_array(distractors.slice(0, 8))
	choices.shuffle()
	
	return {
		"question_id": question_card_id,
		"choices": choices
	}

func submit_answer(question_id: StringName, was_correct: bool) -> void:
	"""Records an answer and updates progress"""
	if not is_instance_valid(_run_state_ref):
		printerr("FlashcardManager: _run_state_ref is null in submit_answer")
		return
	
	if _run_state_ref.flashcard_progress.has(question_id):
		var progress: FlashcardProgress = _run_state_ref.flashcard_progress[question_id]
		progress.record_answer(was_correct, _run_state_ref.day)

func _on_minigame_complete(correct: int, incorrect: int) -> void:
	"""Called when the minigame is completed"""
	# Store results before cleanup
	var results = {"correct_answers": correct, "incorrect_answers": incorrect}
	
	# Clear references first
	_minigame_instance = null # Allow a new game to start
	_run_state_ref = null
	_active_deck_ids.clear()
	
	# Emit signal after cleanup to prevent any callbacks from accessing freed objects
	emit_signal("minigame_finished", results)

```