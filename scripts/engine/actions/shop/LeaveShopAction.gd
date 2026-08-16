extends GameAction
class_name LeaveShopAction

func _init() -> void:
	pass

func is_valid() -> bool:
	return true

func execute() -> void:
	# Hide the drop zone overlay before leaving
	if not (Engine.is_editor_hint() or ActionQueue.is_headless_mode()):
		var main_node = GameManager._active_main_node
		if main_node.has_method("hide_confirm_drop_zone"):
			main_node.hide_confirm_drop_zone()
		
		# Close the shop view (handled natively by Main.gd scene clearing)
		# var shop_view = main_node._current_content_node

	SignalBus.emit_signal("path_choice_scene_requested")
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveShopAction"
	}
