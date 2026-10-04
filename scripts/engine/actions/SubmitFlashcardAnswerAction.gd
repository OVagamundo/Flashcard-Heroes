# res://scripts/engine/actions/SubmitFlashcardAnswerAction.gd
class_name SubmitFlashcardAnswerAction
extends GameAction

var question_id: StringName = &""
var selected_answer_id: StringName = &""
var think_time: float = 0.0

func _init(p_question_id: StringName = &"", p_selected_answer_id: StringName = &"", p_think_time: float = 0.0) -> void:
	super._init(&"SubmitFlashcardAnswerAction")
	question_id = p_question_id
	selected_answer_id = p_selected_answer_id
	think_time = p_think_time

func validate() -> bool:
	if question_id.is_empty() or selected_answer_id.is_empty():
		return false
	if not is_instance_valid(FlashcardManager) or not FlashcardManager.is_session_active or not FlashcardManager.is_sprint_active:
		return false
	if FlashcardManager.session_timer <= 0.0:
		return false
	var current_question: Dictionary = FlashcardManager.current_question
	if StringName(current_question.get("question_id", "")) != question_id:
		return false
	var choices: Array = current_question.get("choices", [])
	if not choices.has(selected_answer_id):
		return false
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and minigame.has_method("get_current_question_id"):
		if minigame.get_current_question_id() != question_id:
			return false
	return think_time >= 0.0

func execute() -> void:
	var result: Dictionary = FlashcardManager.submit_minigame_answer(question_id, selected_answer_id, think_time)
	if result.is_empty():
		push_error("[SubmitFlashcardAnswerAction] Flashcard session rejected an accepted answer.")
		finish_visuals()
		return
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and not ActionQueue.is_headless_mode() and minigame.has_method("execute_choice_selected"):
		minigame.execute_choice_selected(question_id, selected_answer_id, result)

func yields_for_visuals() -> bool:
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	return is_instance_valid(minigame) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["question_id"] = String(question_id)
	d["selected_answer_id"] = String(selected_answer_id)
	d["think_time"] = think_time
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	question_id = StringName(data.get("question_id", ""))
	selected_answer_id = StringName(data.get("selected_answer_id", ""))
	think_time = float(data.get("think_time", 0.0))
