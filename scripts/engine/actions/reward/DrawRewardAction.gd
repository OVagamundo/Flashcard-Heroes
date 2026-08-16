extends GameAction
class_name DrawRewardAction

var tier: int
var cost: int

func _init(p_tier: int, p_cost: int) -> void:
	tier = p_tier
	cost = p_cost

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	pass

func _trigger_animations() -> void:
	var reward_scene = GameManager.get_tree().get_first_node_in_group("reward_scene")
	
	var cb = func():
		_perform_mutation()
		finish_visuals()
		
	var machine = null
	if tier == 1: machine = reward_scene.get_node_or_null("%Tier1Machine")
	elif tier == 2: machine = reward_scene.get_node_or_null("%Tier2Machine")
	elif tier == 3: machine = reward_scene.get_node_or_null("%Tier3Machine")
	
	_run_draw_anim(reward_scene, machine, cb)

func _run_draw_anim(reward_scene: Node, machine: Control, cb: Callable) -> void:
	if reward_scene.has_method("_execute_draw_tier_visuals"):
		await reward_scene._execute_draw_tier_visuals(tier, cost, machine)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "DrawRewardAction",
		"tier": tier,
		"cost": cost
	}
