extends GameAction
class_name StudyRestSiteAction

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
	# In headless mode, flashcards just simulate an instant win or skip.
	pass

func _trigger_animations() -> void:
	var rest_site = GameManager._active_main_node._current_content_node
	if rest_site.has_node("%StudyButton"):
		rest_site.get_node("%StudyButton").disabled = true
	rest_site._has_studied = true
		
	if is_instance_valid(GameManager.run_state):
		FlashcardManager.start_minigame(GameManager.run_state, GameManager.run_state.active_deck_ids)
	
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "StudyRestSiteAction"
	}
