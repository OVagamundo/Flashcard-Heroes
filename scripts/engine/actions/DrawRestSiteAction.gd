# res://scripts/engine/actions/DrawRestSiteAction.gd
class_name DrawRestSiteAction
extends GameAction

var tier: int = 1

func _init(p_tier: int = 1) -> void:
	super._init(&"DrawRestSiteAction")
	tier = p_tier

func validate() -> bool:
	if tier < 1 or tier > 3:
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	return GameManager.run_state.get_room_tokens() >= tier

func execute() -> void:
	var event_log: Dictionary = GameManager.simulate_rest_site_draw(tier)
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rest_site) and not ActionQueue.is_headless_mode():
		if rest_site.has_method("play_transaction_log"):
			rest_site.play_transaction_log(event_log)
		elif rest_site.has_method("execute_draw_tier_visuals"):
			rest_site.execute_draw_tier_visuals(tier, event_log.get("prize_data", {}))

func yields_for_visuals() -> bool:
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	return is_instance_valid(rest_site) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tier"] = tier
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tier = int(data.get("tier", 1))
