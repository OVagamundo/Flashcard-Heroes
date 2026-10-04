# res://scripts/engine/actions/ui/CloseInventoryAction.gd
class_name CloseInventoryAction
extends GameAction

var kind: String = "RUN"

func _init(p_kind: String = "") -> void:
	super._init(&"CloseInventoryAction")
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
		return WindowManager.is_any_inventory_window_open()
	return WindowManager.is_run_inventory_window_open() or WindowManager.is_any_inventory_window_open()

func execute() -> void:
	if is_instance_valid(WindowManager):
		WindowManager.close_all_inspection_windows()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["kind"] = kind
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	kind = String(data.get("kind", "RUN"))
