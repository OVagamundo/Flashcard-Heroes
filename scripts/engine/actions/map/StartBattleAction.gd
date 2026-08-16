extends GameAction
class_name StartBattleAction

var encounter_def: EncounterDefinition

func _init(p_encounter_def: EncounterDefinition) -> void:
	encounter_def = p_encounter_def

func is_valid() -> bool:
	return encounter_def != null

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	pass

func _trigger_animations() -> void:
	var main = GameManager._active_main_node
	if main == null:
		_perform_mutation()
		finish_visuals()
		return
		
	main.load_content(main.BATTLE_SCENE)
	main.sync_visual_machine_counts_with_model()
	
	_perform_mutation()
	main._start_battle_with_encounter(encounter_def)
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "StartBattleAction"
	}
