# res://scripts/engine/actions/ui/OpenInventoryAction.gd
class_name OpenInventoryAction
extends GameAction

var kind: String = "RUN" # "RUN" or "BATTLE"

func _init(p_kind: String = "") -> void:
	super._init(&"OpenInventoryAction")
	if not p_kind.is_empty():
		kind = p_kind
	elif is_instance_valid(GameManager) and GameManager.is_in_battle:
		kind = "BATTLE"
	else:
		kind = "RUN"

func validate() -> bool:
	if not is_instance_valid(WindowManager):
		return false
	if kind == "BATTLE":
		if not is_instance_valid(GameManager) or not GameManager.is_in_battle:
			return false
		var gir = Engine.get_main_loop().root.find_child("GlobalInteractionRouter", true, false)
		if is_instance_valid(gir) and gir.get("_is_combat_phase"):
			return false
		if WindowManager.is_any_inventory_window_open():
			return false
	else:
		if WindowManager.is_run_inventory_window_open():
			return false
	return true

func execute() -> void:
	if is_instance_valid(WindowManager):
		WindowManager.open_inventory_window()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["kind"] = kind
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	kind = String(data.get("kind", "RUN"))
