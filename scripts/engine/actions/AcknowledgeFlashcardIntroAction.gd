# res://scripts/engine/actions/AcknowledgeFlashcardIntroAction.gd
class_name AcknowledgeFlashcardIntroAction
extends GameAction

func _init() -> void:
	super._init(&"AcknowledgeFlashcardIntroAction")

func validate() -> bool:
	return true

func execute() -> void:
	if is_instance_valid(FlashcardManager):
		FlashcardManager.acknowledge_intro()
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and not ActionQueue.is_headless_mode() and minigame.has_method("execute_acknowledge_intro"):
		minigame.execute_acknowledge_intro()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
