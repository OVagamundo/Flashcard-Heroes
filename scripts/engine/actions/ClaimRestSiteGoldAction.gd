# res://scripts/engine/actions/ClaimRestSiteGoldAction.gd
class_name ClaimRestSiteGoldAction
extends GameAction

## Dispatched when claiming a gold prize from a Rest Site lineup (SiteType.GOLD).
## Distinct from UpgradeRestSiteAction which modifies hero base stats (SiteType.STATS).

var prize_index: int = 0

func _init(p_prize_index: int = 0) -> void:
	super._init(&"ClaimRestSiteGoldAction")
	prize_index = p_prize_index

func validate() -> bool:
	return prize_index >= 0

func execute() -> void:
	var rs = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rs) and not ActionQueue.is_headless_mode() and rs.has_method("execute_upgrade_visuals"):
		rs.execute_upgrade_visuals(prize_index)
	else:
		# Direct data mutation in headless or decoupled mode
		GameManager.claim_rest_site_prize(prize_index)

func yields_for_visuals() -> bool:
	var rs = Engine.get_main_loop().root.find_child("RestSite", true, false)
	return is_instance_valid(rs) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["prize_index"] = prize_index
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	prize_index = int(data.get("prize_index", 0))
