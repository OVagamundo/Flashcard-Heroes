extends GameAction
class_name SelectPathAction

var node_def: PathNodeDefinition

func _init(p_node_def: PathNodeDefinition) -> void:
	node_def = p_node_def

func is_valid() -> bool:
	return node_def != null

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	SignalBus.emit_signal("node_selected", node_def)

func _trigger_animations() -> void:
	var cb = func():
		_perform_mutation()
		finish_visuals()
		
	var tree = GameManager.get_tree()
	if tree != null:
		var timer = tree.create_timer(0.12, false) # SELECTION_TRANSITION_DELAY
		timer.timeout.connect(cb)
	else:
		cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	var def_dict = {}
	if node_def != null:
		def_dict = {
			"node_type": node_def.node_type,
			"subtype": node_def.subtype,
			"difficulty": node_def.difficulty,
			"boss_level": node_def.boss_level,
			"display_name_key": node_def.display_name_key,
			"base_weight": node_def.base_weight
		}
	return {
		"action_type": "SelectPathAction",
		"node_def": def_dict
	}
