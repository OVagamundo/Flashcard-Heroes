# res://scripts/engine/actions/StudyRestSiteAction.gd
class_name StudyRestSiteAction
extends GameAction

func _init() -> void:
	super._init(&"StudyRestSiteAction")

func validate() -> bool:
	return is_instance_valid(GameManager.run_state) and GameManager._rest_site_active and not GameManager._rest_site_study_used and not FlashcardManager.is_session_active

func execute() -> void:
	GameManager._rest_site_study_used = true
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rest_site) and rest_site.has_method("_execute_study"):
		rest_site._execute_study()
	FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
