# res://scripts/engine/actions/UpgradeRestSiteAction.gd
class_name UpgradeRestSiteAction
extends GameAction

var slot_index: int = -1

func _init(p_slot_index: int = -1) -> void:
	super._init(&"UpgradeRestSiteAction")
	slot_index = p_slot_index

func validate() -> bool:
	return slot_index >= 0

func execute() -> void:
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rest_site) and not ActionQueue.is_headless_mode() and rest_site.has_method("execute_upgrade_visuals"):
		rest_site.execute_upgrade_visuals(slot_index)
	else:
		GameManager.claim_rest_site_prize(slot_index)

func yields_for_visuals() -> bool:
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	return is_instance_valid(rest_site) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["slot_index"] = slot_index
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	slot_index = int(data.get("slot_index", -1))
