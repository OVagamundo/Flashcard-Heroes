# res://scripts/FlashcardManager.gd
extends Node

## Singleton responsible for the mini-game's lifecycle.
## Implements the TDD V7.0 specification for flashcard system.
## TDD Section 9.2: FlashcardManager.gd

signal minigame_finished(results: Dictionary)
signal session_timer_updated(current_time: float, max_time: float)
signal session_question_changed(question_data: Dictionary)

## SRS Algorithm weights
const SRS_MASTERY_WEIGHT_POWER: float = 2.0
const SRS_RECENCY_WEIGHT: float = 1.0
const SRS_RANDOM_FACTOR: float = 0.1

var _run_state_ref: RunState = null
var _active_deck_ids: Array[StringName] = []
var _last_shown_card_id: StringName = &""
var _minigame_instance: Control = null

# Authoritative session state
var is_session_active: bool = false
var is_sprint_active: bool = false
var is_introducing_new_card: bool = false
var introduced_card_id: StringName = &""
var session_timer: float = 0.0
var session_duration: float = 7.0
var correct_answers: int = 0
var total_answers: int = 0
var current_streak: int = 0
var tokens_earned: int = 0
var current_question: Dictionary = {}

## TDD Section 9.3: The Weighted SRS Algorithm
func _select_card_via_srs() -> StringName:
	"""Selects a card using the weighted SRS algorithm"""
	if not is_instance_valid(_run_state_ref):
		return RNGManager.map_rng.pick_random(_active_deck_ids) if not _active_deck_ids.is_empty() else &""
	
	var candidates = _active_deck_ids.duplicate()
	if candidates.has(_last_shown_card_id):
		candidates.erase(_last_shown_card_id)
	
	if candidates.is_empty():
		return RNGManager.map_rng.pick_random(_active_deck_ids) if not _active_deck_ids.is_empty() else &""
	
	var weighted_candidates: Array[Dictionary] = []
	var total_weight: float = 0.0
	
	for card_id in candidates:
		if not _run_state_ref.flashcard_progress.has(card_id):
			continue
		var progress: FlashcardProgress = _run_state_ref.flashcard_progress[card_id]
		
		# TDD Section 9.3: Priority 1 = mastery (lower = higher weight), Priority 2 = recency, Tie-breaker = random
		var mastery_component: float = pow(6 - progress.mastery_level, SRS_MASTERY_WEIGHT_POWER)
		var time_component: float = float(_run_state_ref.day - progress.last_review_day) * SRS_RECENCY_WEIGHT
		var random_component: float = RNGManager.map_rng.randf() * SRS_RANDOM_FACTOR
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
		return RNGManager.map_rng.pick_random(candidates) if not candidates.is_empty() else &""
	
	# Perform weighted random selection
	var rand_val = RNGManager.map_rng.randf() * total_weight
	for candidate in weighted_candidates:
		rand_val -= candidate.weight
		if rand_val <= 0:
			return candidate.id
	
	return RNGManager.map_rng.pick_random(candidates) # Fallback

## TDD Section 9.2: Public API
func start_minigame(run_state: RunState, active_deck: Array[StringName]) -> void:
	"""Starts a flashcard minigame with the specified run state and active deck"""
	if is_session_active or is_instance_valid(_minigame_instance):
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
	
	# Configure authoritative session parameters
	session_duration = 7.0
	if GameManager.is_in_battle and GameManager.has_trinket(&"trinket_time_sprint_charm"):
		session_duration += 2.0
		var animator = get_node_or_null("/root/BattleAnimator")
		if is_instance_valid(animator) and animator.has_method("hop_trinket_by_definition_id"):
			animator.call_deferred("hop_trinket_by_definition_id", &"trinket_time_sprint_charm", false)
			
	session_timer = session_duration
	correct_answers = 0
	total_answers = 0
	current_streak = 0
	tokens_earned = 0
	is_session_active = true
	
	# Determine if introducing a new card
	if run_state.cards_presented_count < run_state.active_deck_ids.size():
		introduced_card_id = run_state.active_deck_ids[run_state.cards_presented_count]
		is_introducing_new_card = true
		is_sprint_active = false
	else:
		introduced_card_id = &""
		is_introducing_new_card = false
		is_sprint_active = true
		
	current_question = get_next_question()
	session_question_changed.emit(current_question)
	session_timer_updated.emit(session_timer, session_duration)
	
	# Open UI window only if not in headless mode
	if not ActionQueue.is_headless_mode():
		_minigame_instance = WindowManager.open_modal_window(&"FlashcardMinigame", {
			"run_state": run_state,
			"active_deck": self._active_deck_ids
		}, true)

func acknowledge_intro() -> void:
	"""Transitions from card introduction to active sprint"""
	if is_instance_valid(_run_state_ref) and is_introducing_new_card:
		_run_state_ref.cards_presented_count += 1
	is_introducing_new_card = false
	is_sprint_active = true

func advance_session_timer(seconds: float) -> void:
	"""Authoritatively steps the minigame session timer"""
	if not is_session_active or is_introducing_new_card:
		return
	session_timer = maxf(0.0, session_timer - seconds)
	session_timer_updated.emit(session_timer, session_duration)
	if session_timer <= 0.0:
		_on_minigame_complete(correct_answers, total_answers - correct_answers)

func submit_minigame_answer(question_id: StringName, selected_answer_id: StringName, think_time: float = 0.0) -> Dictionary:
	"""Processes an answer submission, advancing timer and awarding tokens"""
	if not is_session_active or session_timer <= 0.0:
		return {}

	if think_time > 0.0:
		advance_session_timer(think_time)
		if not is_session_active:
			return {}

	var was_correct: bool = (question_id == selected_answer_id)
	total_answers += 1
	
	var mastery_level: int = FlashcardProgress.MASTERY_MIN
	if is_instance_valid(_run_state_ref) and _run_state_ref.flashcard_progress.has(question_id):
		var prog = _run_state_ref.flashcard_progress[question_id]
		if is_instance_valid(prog):
			mastery_level = prog.mastery_level

	submit_answer(question_id, was_correct)
	
	var tokens_to_give: int = 0
	if was_correct:
		correct_answers += 1
		current_streak += 1
		session_timer += 0.5
		
		var has_charm: bool = GameManager.has_trinket(&"trinket_beginners_charm")
		tokens_to_give = 2 if (mastery_level <= FlashcardProgress.MASTERY_MIN and has_charm) else 1
		tokens_earned += tokens_to_give
		
		if GameManager.is_in_battle:
			var bm = GameManager.get_battle_manager()
			if is_instance_valid(bm) and bm.has_method("add_gacha_tokens"):
				bm.add_gacha_tokens(tokens_to_give, true)
			elif is_instance_valid(bm) and bm.has_method("add_gacha_token"):
				bm.add_gacha_token(tokens_to_give, true)
		elif is_instance_valid(_run_state_ref):
			_run_state_ref.add_room_tokens(tokens_to_give)
	else:
		current_streak = 0
		
	session_timer_updated.emit(session_timer, session_duration)
	current_question = get_next_question()
	session_question_changed.emit(current_question)
	
	return {
		"was_correct": was_correct,
		"tokens_to_give": tokens_to_give,
		"current_streak": current_streak,
		"correct_answers": correct_answers,
		"total_answers": total_answers,
		"next_question": current_question
	}

func skip_minigame_question(question_id: StringName, think_time: float = 0.0) -> Dictionary:
	"""Skips the current question, advancing timer and resetting streak"""
	if not is_session_active or session_timer <= 0.0:
		return {}

	if think_time > 0.0:
		advance_session_timer(think_time)
		if not is_session_active:
			return {}

	total_answers += 1
	submit_answer(question_id, false)
	current_streak = 0
	session_timer += 0.5
	session_timer_updated.emit(session_timer, session_duration)
	
	current_question = get_next_question()
	session_question_changed.emit(current_question)
	
	return {
		"was_correct": false,
		"tokens_to_give": 0,
		"current_streak": 0,
		"correct_answers": correct_answers,
		"total_answers": total_answers,
		"next_question": current_question
	}

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
	RNGManager.map_rng.shuffle(distractors)
	
	var choices: Array[StringName] = [question_card_id]
	choices.append_array(distractors.slice(0, 5))
	RNGManager.map_rng.shuffle(choices)
	
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

func _is_starter_hero(rs: RunState) -> bool:
	if not is_instance_valid(rs) or not is_instance_valid(rs.hero_instance):
		return false
	var def = rs.hero_instance.get_definition()
	return is_instance_valid(def) and def.id == &"hero_starter"

func _on_minigame_complete(correct: int, incorrect: int) -> void:
	"""Called when the minigame is completed - FlashcardManager owns window lifecycle"""
	if not is_session_active:
		return
		
	is_session_active = false
	is_sprint_active = false
	is_introducing_new_card = false
	
	# Starter hero minimum guarantee: guarantee at least 3 tokens
	if is_instance_valid(_run_state_ref) and _is_starter_hero(_run_state_ref) and correct < 3:
		var bonus = 3 - correct
		if GameManager.is_in_battle:
			var bm = GameManager.get_battle_manager()
			if is_instance_valid(bm) and bm.has_method("add_gacha_tokens"):
				bm.add_gacha_tokens(bonus, true)
			elif is_instance_valid(bm) and bm.has_method("add_gacha_token"):
				bm.add_gacha_token(bonus, true)
		else:
			_run_state_ref.add_room_tokens(bonus)
		correct = 3
		tokens_earned += bonus
	
	if GameManager.is_in_battle:
		var bm = GameManager.get_battle_manager()
		if is_instance_valid(bm) and bm.has_method("get_gacha_tokens"):
			SignalBus.emit_signal("gacha_tokens_changed", bm.get_gacha_tokens())
	
	var results: Dictionary = {
		"correct_answers": correct,
		"incorrect_answers": incorrect,
		"total_answers": correct + incorrect,
		"tokens_earned": tokens_earned
	}
	
	# Finish any active flashcard action if queue was waiting
	if is_instance_valid(ActionQueue) and ActionQueue.is_busy():
		var act = ActionQueue.get_active_action()
		if act is SubmitFlashcardAnswerAction or act is SkipFlashcardAction:
			ActionQueue.finish_action(act)
	
	# CRITICAL: Close the window - FlashcardManager owns the minigame lifecycle
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
