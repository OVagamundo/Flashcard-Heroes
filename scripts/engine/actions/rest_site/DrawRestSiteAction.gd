extends GameAction
class_name DrawRestSiteAction

var tier: int
var cost: int

func _init(p_tier: int, p_cost: int) -> void:
	tier = p_tier
	cost = p_cost

func is_valid() -> bool:
	# In headless mode, we have to trust the generator that tokens were sufficient, 
	# or we must store _tokens in RunState. Since it's currently on UI, we assume validity.
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	# Without a UI instance, this is tricky to model purely in headless without shifting `_tokens` to RunState.
	# For deterministic headless replay, we should ideally roll the value and append to the node state.
	# The rolling happens inside RestSite.gd currently.
	pass

func _trigger_animations() -> void:
	var rest_site = GameManager._active_main_node._current_content_node
	
	var cb = func():
		_perform_mutation()
		finish_visuals()
		
	var machine = null
	if tier == 1: machine = rest_site.tier1_machine
	elif tier == 2: machine = rest_site.tier2_machine
	elif tier == 3: machine = rest_site.tier3_machine
	
	_run_draw_anim(rest_site, machine, cb)

func _run_draw_anim(rest_site: Node, machine: Control, cb: Callable) -> void:
	if rest_site.has_method("_execute_draw_tier_visuals"):
		await rest_site._execute_draw_tier_visuals(tier, cost, machine)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "DrawRestSiteAction",
		"tier": tier,
		"cost": cost
	}
