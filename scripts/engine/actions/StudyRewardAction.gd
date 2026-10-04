# res://scripts/engine/actions/StudyRewardAction.gd
class_name StudyRewardAction
extends GameAction

func _init() -> void:
	super._init(&"StudyRewardAction")

func validate() -> bool:
	return is_instance_valid(GameManager.run_state) and GameManager._reward_room_active and not GameManager._reward_study_used and not FlashcardManager.is_session_active

func execute() -> void:
	GameManager._reward_study_used = true
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	if is_instance_valid(reward_view) and reward_view.has_method("_execute_study"):
		reward_view._execute_study()
	FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
