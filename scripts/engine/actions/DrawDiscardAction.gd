# res://scripts/engine/actions/DrawDiscardAction.gd
class_name DrawDiscardAction
extends GameAction

func _init() -> void:
	super._init(&"DrawDiscardAction")

func validate() -> bool:
	var bm = GameManager.get_battle_manager()
	if not is_instance_valid(bm):
		return false
	if bm.has_method("can_draw_from_discard"):
		return bm.can_draw_from_discard()
	return true

func execute() -> void:
	var main_node = GameManager.get_main_node()
	if is_instance_valid(main_node) and not ActionQueue.is_headless_mode() and main_node.has_method("execute_draw_discard_visuals"):
		var button = main_node.get_discard_knob_button()
		main_node.execute_draw_discard_visuals(button)
	else:
		var bm = GameManager.get_battle_manager()
		if is_instance_valid(bm) and bm.has_method("_on_draw_from_discard_requested"):
			bm._on_draw_from_discard_requested()

func yields_for_visuals() -> bool:
	var main_node = GameManager.get_main_node()
	return is_instance_valid(main_node) and not ActionQueue.is_headless_mode()
