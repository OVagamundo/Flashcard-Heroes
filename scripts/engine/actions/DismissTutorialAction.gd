# res://scripts/engine/actions/DismissTutorialAction.gd
class_name DismissTutorialAction
extends GameAction

var tutorial_id: StringName = &""

func _init(p_tutorial_id: StringName = &"") -> void:
	super._init(&"DismissTutorialAction")
	tutorial_id = p_tutorial_id

func validate() -> bool:
	return true

func execute() -> void:
	var popup = Engine.get_main_loop().root.find_child("TutorialPopup", true, false)
	if is_instance_valid(popup) and popup.has_method("_close_popup"):
		popup._close_popup()

	if not tutorial_id.is_empty() and is_instance_valid(TutorialManager):
		TutorialManager.mark_completed(tutorial_id)
		SignalBus.emit_signal("tutorial_dismissed", tutorial_id)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tutorial_id"] = String(tutorial_id)
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tutorial_id = StringName(data.get("tutorial_id", ""))
