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
	return not question_id.is_empty() and not selected_answer_id.is_empty()

func execute() -> void:
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and not ActionQueue.is_headless_mode() and minigame.has_method("execute_choice_selected"):
		minigame.execute_choice_selected(selected_answer_id)
	else:
		var sim_think_time = think_time if think_time > 0.0 else 1.0
		if is_instance_valid(ActionQueue):
			ActionQueue.advance_simulation_time(sim_think_time)
		if is_instance_valid(FlashcardManager):
			FlashcardManager.submit_minigame_answer(question_id, selected_answer_id, sim_think_time)

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
