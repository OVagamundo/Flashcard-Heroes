extends GameAction
class_name StudyRewardAction

func _init() -> void:
	pass

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	pass

func _trigger_animations() -> void:
	var reward_scene = GameManager.get_tree().get_first_node_in_group("reward_scene")
	if reward_scene != null:
		if reward_scene.has_node("%StudyButton"):
			reward_scene.get_node("%StudyButton").disabled = true
		reward_scene._has_studied = true
		
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
	
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "StudyRewardAction"
	}
