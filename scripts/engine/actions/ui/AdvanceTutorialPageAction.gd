# res://scripts/engine/actions/ui/AdvanceTutorialPageAction.gd
class_name AdvanceTutorialPageAction
extends GameAction

var tutorial_id: String = ""
var target_page: int = 0

func _init(p_tutorial_id: String = "", p_target_page: int = 0) -> void:
	super._init(&"AdvanceTutorialPageAction")
	tutorial_id = p_tutorial_id
	target_page = p_target_page

func validate() -> bool:
	return not tutorial_id.is_empty()

func execute() -> void:
	var popup = Engine.get_main_loop().root.find_child("TutorialPopup", true, false)
	if is_instance_valid(popup):
		if popup.has_method("set_page"):
			popup.set_page(target_page)
		elif popup.has_method("_advance_page"):
			popup._advance_page()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tutorial_id"] = tutorial_id
	d["target_page"] = target_page
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tutorial_id = String(data.get("tutorial_id", ""))
	target_page = int(data.get("target_page", 0))
