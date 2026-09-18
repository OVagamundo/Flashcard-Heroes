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
	return not question_id.is_empty()

func execute() -> void:
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and not ActionQueue.is_headless_mode() and minigame.has_method("execute_skip"):
		minigame.execute_skip()
	else:
		var sim_think_time = think_time if think_time > 0.0 else 0.5
		if is_instance_valid(ActionQueue):
			ActionQueue.advance_simulation_time(sim_think_time)
		if is_instance_valid(FlashcardManager):
			FlashcardManager.skip_minigame_question(question_id, sim_think_time)

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
