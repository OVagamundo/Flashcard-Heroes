# res://scripts/engine/actions/SkipFlashcardAction.gd
class_name SkipFlashcardAction
extends GameAction

var question_id: StringName = &""
var think_time: float = 0.0

func _init(p_question_id: StringName = &"", p_think_time: float = 0.0) -> void:
	super._init(&"SkipFlashcardAction")
	question_id = p_question_id
	think_time = p_think_time

func validate() -> bool:
	if question_id.is_empty() or not is_instance_valid(FlashcardManager):
		return false
	if not FlashcardManager.is_session_active or not FlashcardManager.is_sprint_active or FlashcardManager.session_timer <= 0.0:
		return false
	if StringName(FlashcardManager.current_question.get("question_id", "")) != question_id:
		return false
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and minigame.has_method("get_current_question_id"):
		if minigame.get_current_question_id() != question_id:
			return false
	return think_time >= 0.0

func execute() -> void:
	var result: Dictionary = FlashcardManager.skip_minigame_question(question_id, think_time)
	if result.is_empty():
		push_error("[SkipFlashcardAction] Flashcard session rejected an accepted skip.")
		finish_visuals()
		return
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and not ActionQueue.is_headless_mode() and minigame.has_method("execute_skip"):
		minigame.execute_skip(question_id, result)

func yields_for_visuals() -> bool:
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	return is_instance_valid(minigame) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["question_id"] = String(question_id)
	d["think_time"] = think_time
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	question_id = StringName(data.get("question_id", ""))
	think_time = float(data.get("think_time", 0.0))
