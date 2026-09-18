# res://scripts/engine/actions/PauseRunAction.gd
class_name PauseRunAction
extends GameAction

var is_paused: bool = true

func _init(p_is_paused: bool = true) -> void:
	super._init(&"PauseRunAction")
	is_paused = p_is_paused

func is_meta_action() -> bool:
	return true

func validate() -> bool:
	return true

func execute() -> void:
	if is_paused:
		ActionQueue.pause_timer()
	else:
		ActionQueue.start_timer()

	var tree = Engine.get_main_loop() as SceneTree
	var bv = tree.get_first_node_in_group("battle_view") if is_instance_valid(tree) else null
	if not is_instance_valid(bv) and is_instance_valid(tree) and is_instance_valid(tree.root):
		bv = tree.root.find_child("Battle", true, false)

	if is_instance_valid(bv) and not ActionQueue.is_headless_mode() and bv.has_method("execute_pause"):
		if is_paused:
			bv.execute_pause()
		else:
			bv.execute_speed(AnimationConstants.speed_factor)
	else:
		var animator = Engine.get_main_loop().root.get_node_or_null("/root/BattleAnimator")
		if is_instance_valid(animator):
			if is_paused and animator.has_method("pause_combat"):
				animator.pause_combat()
			elif not is_paused and animator.has_method("play_continuous"):
				animator.play_continuous(AnimationConstants.speed_factor)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["is_paused"] = is_paused
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	is_paused = bool(data.get("is_paused", true))
