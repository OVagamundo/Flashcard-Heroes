# res://scripts/engine/actions/SetCombatSpeedAction.gd
class_name SetCombatSpeedAction
extends GameAction

var speed: float = 1.0

func _init(p_speed: float = 1.0) -> void:
	super._init(&"SetCombatSpeedAction")
	speed = p_speed

func is_meta_action() -> bool:
	return true

func validate() -> bool:
	return speed > 0.0

func execute() -> void:
	AnimationConstants.speed_factor = speed
	if not ActionQueue.is_timer_running():
		ActionQueue.start_timer()

	var tree = Engine.get_main_loop() as SceneTree
	var bv = tree.get_first_node_in_group("battle_view") if is_instance_valid(tree) else null
	if not is_instance_valid(bv) and is_instance_valid(tree) and is_instance_valid(tree.root):
		bv = tree.root.find_child("Battle", true, false)

	if is_instance_valid(bv) and not ActionQueue.is_headless_mode() and bv.has_method("execute_speed"):
		bv.execute_speed(speed)
	else:
		var animator = Engine.get_main_loop().root.get_node_or_null("/root/BattleAnimator")
		if is_instance_valid(animator) and animator.has_method("play_continuous"):
			animator.play_continuous(speed)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["speed"] = speed
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	speed = float(data.get("speed", 1.0))
