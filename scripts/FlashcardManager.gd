# res://scripts/FlashcardManager.gd
extends Node

## Singleton responsible for the mini-game's lifecycle.
## Implements the TDD V7.0 specification for flashcard system.
## TDD Section 9.2: FlashcardManager.gd

signal minigame_finished(results: Dictionary)

## SRS Algorithm weights
const SRS_MASTERY_WEIGHT_POWER: float = 2.0
const SRS_RECENCY_WEIGHT: float = 1.0
const SRS_RANDOM_FACTOR: float = 0.1

var _run_state_ref: RunState = null
var _active_deck_ids: Array[StringName] = []
var _last_shown_card_id: StringName = &""
var _minigame_instance: Control = null

## TDD Section 9.3: The Weighted SRS Algorithm
func _select_card_via_srs() -> StringName:
	"""Selects a card using the weighted SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
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
		
		# TDD Section 9.3: Priority 1 = mastery (lower = higher weight), Priority 2 = recency, Tie-breaker = random
		var mastery_component: float = pow(6 - progress.mastery_level, SRS_MASTERY_WEIGHT_POWER)
		var time_component: float = float(_run_state_ref.day - progress.last_review_day) * SRS_RECENCY_WEIGHT
		var random_component: float = randf() * SRS_RANDOM_FACTOR
		var weight: float = mastery_component + time_component + random_component
		
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
	
	if not is_instance_valid(run_state):
		return
	
	if active_deck.is_empty():
		return
	
	# Validate that all cards in the deck exist
	for card_id in active_deck:
		if not Database.flashcard_definitions.has(card_id):
			return
	
	self._run_state_ref = run_state
	self._active_deck_ids = active_deck.duplicate()
	
	# Open the flashcard minigame modal window
	_minigame_instance = WindowManager.open_modal_window(&"FlashcardMinigame", {
		"run_state": run_state,
		"active_deck": active_deck
	})

func get_next_question() -> Dictionary:
	"""Gets the next question using SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
		return {}
	
	if _active_deck_ids.size() < 6:
		return {} # Not enough cards for a question and 5 distractors
	
	var question_card_id = _select_card_via_srs()
	if question_card_id.is_empty():
		return {}
	
	_last_shown_card_id = question_card_id
	
	var distractors = _active_deck_ids.duplicate()
	distractors.erase(question_card_id)
	distractors.shuffle()
	
	var choices: Array[StringName] = [question_card_id]
	choices.append_array(distractors.slice(0, 5))
	choices.shuffle()
	
	return {
		"question_id": question_card_id,
		"choices": choices
	}

func submit_answer(question_id: StringName, was_correct: bool) -> void:
	"""Records an answer and updates progress"""
	if not is_instance_valid(_run_state_ref):
		return
	
	if _run_state_ref.flashcard_progress.has(question_id):
		var progress: FlashcardProgress = _run_state_ref.flashcard_progress[question_id]
		progress.record_answer(was_correct, _run_state_ref.day)
		SignalBus.emit_signal("run_data_changed")

func _on_minigame_complete(correct: int, incorrect: int) -> void:
	"""Called when the minigame is completed - FlashcardManager owns window lifecycle"""
	print("[FlashcardManager] _on_minigame_complete called. Correct: ", correct)
	# Store results before cleanup
	var results: Dictionary = {"correct_answers": correct, "incorrect_answers": incorrect}
	
	# Check for deck expansion (new cards) if user mastered current ones
	if is_instance_valid(_run_state_ref):
		_run_state_ref.check_deck_expansion()
	
	# CRITICAL: Close the window - FlashcardManager owns the minigame lifecycle
	# This ensures the window closes regardless of what encounter started it
	if is_instance_valid(_minigame_instance):
		_minigame_instance.queue_free()
	
	# Clear references
	_minigame_instance = null
	_run_state_ref = null
	_active_deck_ids.clear()
	
	# Emit signal after cleanup to prevent any callbacks from accessing freed objects
	print("[FlashcardManager] Emitting minigame_finished signal with results: ", results)
	emit_signal("minigame_finished", results)
	print("[FlashcardManager] Signal emitted successfully")

## Get statistics about the current deck for debugging.
## @return Dictionary - Statistics about the deck
func get_deck_statistics() -> Dictionary:
	if not is_instance_valid(_run_state_ref):
		return {}
		
	var stats: Dictionary = {
		"total_cards": _active_deck_ids.size(),
		"mastery_levels": {},
		"average_mastery": 0.0,
		"cards_by_mastery": {}
	}
	
	var total_mastery = 0
	var cards_counted = 0
	
	for card_id in _active_deck_ids:
		if _run_state_ref.flashcard_progress.has(card_id):
			var progress = _run_state_ref.flashcard_progress[card_id]
			var mastery = progress.mastery_level
			
			stats.mastery_levels[card_id] = mastery
			total_mastery += mastery
			cards_counted += 1
			
			if not stats.cards_by_mastery.has(mastery):
				stats.cards_by_mastery[mastery] = []
			stats.cards_by_mastery[mastery].append(card_id)
		else:
			stats.mastery_levels[card_id] = 0
			if not stats.cards_by_mastery.has(0):
				stats.cards_by_mastery[0] = []
			stats.cards_by_mastery[0].append(card_id)
	
	if cards_counted > 0:
		stats.average_mastery = float(total_mastery) / float(cards_counted)
	
	return stats
