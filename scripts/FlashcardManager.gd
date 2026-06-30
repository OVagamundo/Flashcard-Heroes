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
		
		# Dampen weight of mastered cards so they are drawn much less frequently
		if progress.mastery_level == 5:
			weight *= 0.02 # 98% reduction for Blue Level 5 fully mastered cards
		elif progress.mastery_level == 4:
			weight *= 0.15 # 85% reduction for Level 4 cards
		elif progress.mastery_level == 3:
			weight *= 0.40 # 60% reduction for Level 3 cards
		
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
		push_error("[FlashcardManager] active_deck is empty! Cannot start minigame.")
		return
	
	# Validate that all cards in the deck exist
	for card_id in active_deck:
		if not Database.flashcard_definitions.has(card_id):
			push_error("[FlashcardManager] Card definition missing for: " + str(card_id))
			return
	
	# NEW: Expand deck at START of minigame session
	# This ensures +1 card is introduced every time the player studies.
	run_state.check_deck_expansion()
	
	self._run_state_ref = run_state
	self._active_deck_ids = run_state.active_deck_ids.duplicate()
	
	# Open the flashcard minigame modal window (preserve existing windows like inventory)
	_minigame_instance = WindowManager.open_modal_window(&"FlashcardMinigame", {
		"run_state": run_state,
		"active_deck": self._active_deck_ids
	}, true)

func get_next_question() -> Dictionary:
	"""Gets the next question using SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
		push_error("[FlashcardManager] _run_state_ref is invalid!")
		return {}
	
	if _active_deck_ids.size() < 6:
		push_error("[FlashcardManager] Not enough cards in active deck! Size is: " + str(_active_deck_ids.size()))
		return {} # Not enough cards for a question and 5 distractors
	
	var question_card_id = _select_card_via_srs()
	if question_card_id.is_empty():
		push_error("[FlashcardManager] _select_card_via_srs returned empty!")
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
	# Store results before cleanup
	var results: Dictionary = {"correct_answers": correct, "incorrect_answers": incorrect}
	
	# Deck expansion now happens at the START of the minigame session
	# to ensure a new card is introduced immediately.
	
	# CRITICAL: Close the window - FlashcardManager owns the minigame lifecycle
	# This ensures the window closes regardless of what encounter started it
	if is_instance_valid(_minigame_instance):
		_minigame_instance.queue_free()
	
	# Clear references
	_minigame_instance = null
	_run_state_ref = null
	_active_deck_ids.clear()
	
	# Emit signal after cleanup to prevent any callbacks from accessing freed objects
	emit_signal("minigame_finished", results)

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
