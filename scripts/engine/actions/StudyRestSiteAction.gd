# res://scripts/engine/actions/StudyRestSiteAction.gd
class_name StudyRestSiteAction
extends GameAction

func _init() -> void:
	super._init(&"StudyRestSiteAction")

func validate() -> bool:
	return true

func execute() -> void:
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rest_site) and rest_site.has_method("_execute_study"):
		rest_site._execute_study()
	elif is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
