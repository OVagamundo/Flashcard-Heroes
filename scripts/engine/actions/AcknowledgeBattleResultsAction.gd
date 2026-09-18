# res://scripts/engine/actions/AcknowledgeBattleResultsAction.gd
class_name AcknowledgeBattleResultsAction
extends GameAction

var is_victory: bool = true

func _init(p_is_victory: bool = true) -> void:
	super._init(&"AcknowledgeBattleResultsAction")
	is_victory = p_is_victory

func validate() -> bool:
	if is_victory and not is_instance_valid(GameManager.run_state):
		return false
	return true

func execute() -> void:
	var popup = Engine.get_main_loop().root.find_child("EndBattlePopup", true, false)
	if is_instance_valid(popup):
		popup.queue_free()
	elif is_instance_valid(WindowManager) and WindowManager.has_method("_close_top_modal"):
		WindowManager._close_top_modal()
	if is_victory:
		SignalBus.emit_signal("battle_victory_acknowledged")
	else:
		SaveManager.clear_save()
		SignalBus.emit_signal("title_scene_requested")

func yields_for_visuals() -> bool:
	if not is_victory:
		return false
	return not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["is_victory"] = is_victory
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	is_victory = bool(data.get("is_victory", true))
